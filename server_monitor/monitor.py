import asyncio
from typing import Dict, List
from ssh_client import SSHClient
from parsers import (
    parse_ollama_ps, parse_nvidia_smi, parse_top, parse_free, parse_df, parse_network_stats, parse_processes, parse_hardware_temps,
    OllamaModelInfo, GPUInfo, SystemResourceInfo, DiskInfo, NetworkInfo, ProcessInfo, CustomCommandResult, HardwareTempInfo
)
from db import store_server_metrics
from alerts import alert_manager
from cache import cache_manager
from plugins import plugin_manager
import logging
import time

logger = logging.getLogger(__name__)


class MonitorCollector:
    def __init__(self, ssh_client: SSHClient, db_session):
        self.ssh_client = ssh_client
        self.db_session = db_session
        self.last_collection_time = 0
        self.collection_interval = 1  # 秒
    
    async def collect_ollama_models(self) -> List[OllamaModelInfo]:
        """收集Ollama模型信息"""
        success, stdout, stderr = await self.ssh_client.execute_command('ollama ps')
        
        print(f"ollama: {stdout}")
        if not success:
            logger.error(f"Failed to get Ollama models on {self.ssh_client.server_config.name}: {stderr}")
            return []
        return parse_ollama_ps(stdout)
    
    async def collect_gpu_info(self) -> List[GPUInfo]:
        """收集GPU信息"""
        # 使用nvidia-smi获取GPU信息
        success, stdout, stderr = await self.ssh_client.execute_command(
            'nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu '
            '--format=csv,noheader,nounits'
        )

        if not success:
            logger.error(f"Failed to get GPU info on {self.ssh_client.server_config.name}: {stderr}")
            return []

        # 为了获取更详细的信息，我们还需要获取进程信息
        proc_success, proc_stdout, proc_stderr = await self.ssh_client.execute_command(
            'nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits'
        )

        if not proc_success:
            logger.warning(f"Could not get GPU processes on {self.ssh_client.server_config.name}: {proc_stderr}")
            proc_stdout = ""

        # 解析GPU基本信息
        gpus = []
        basic_lines = stdout.strip().split('\n') if stdout.strip() else []

        # 解析GPU进程信息
        process_lines = proc_stdout.strip().split('\n') if proc_stdout.strip() else []
        processes_by_gpu = {}

        for line in process_lines:
            parts = [p.strip() for p in line.split(',')]
            if len(parts) >= 3:  # pid, process_name, used_memory
                try:
                    # 从进程信息中提取GPU索引（通常在进程信息中会包含GPU索引）
                    # 如果没有直接的GPU索引，我们需要通过其他方式关联
                    pid = parts[0]
                    process_name = parts[1]
                    memory_used = int(parts[2])

                    # 由于nvidia-smi输出格式，我们可能需要另一种方式来获取GPU索引
                    # 这里我们暂时将所有进程分配给第一个GPU，后续可改进
                    gpu_index = 0  # 默认分配给第一个GPU

                    if gpu_index not in processes_by_gpu:
                        processes_by_gpu[gpu_index] = []

                    processes_by_gpu[gpu_index].append({
                        'pid': pid,
                        'process_name': process_name,
                        'memory_used': memory_used
                    })
                except ValueError as e:
                    logger.error(f"Error parsing GPU process line: {line}, error: {e}")

        for line in basic_lines:
            parts = [p.strip() for p in line.split(',')]
            if len(parts) >= 6:  # index, name, util, mem_used, mem_total, temp
                try:
                    index = int(parts[0])
                    name = parts[1]
                    util = int(parts[2])
                    mem_used = int(parts[3])
                    mem_total = int(parts[4])
                    temp = int(parts[5])

                    from parsers import GPUMemoryInfo
                    memory_info = GPUMemoryInfo(used=mem_used, total=mem_total)

                    # 获取对应GPU的进程信息
                    processes = processes_by_gpu.get(index, [])

                    gpu_info = GPUInfo(
                        index=index,
                        name=name,
                        utilization=util,
                        memory_info=memory_info,
                        temperature=temp,
                        processes=processes
                    )
                    gpus.append(gpu_info)
                except ValueError as e:
                    logger.error(f"Error parsing GPU info line: {line}, error: {e}")

        return gpus
    
    async def collect_disk_usage(self) -> List[DiskInfo]:
        """收集磁盘使用情况"""
        success, stdout, stderr = await self.ssh_client.execute_command('df -h')

        if not success:
            logger.error(f"Failed to get disk usage on {self.ssh_client.server_config.name}: {stderr}")
            return []

        return parse_df(stdout)

    async def collect_network_stats(self) -> List[NetworkInfo]:
        """收集网络统计信息"""
        success, stdout, stderr = await self.ssh_client.execute_command('cat /proc/net/dev')

        if not success:
            logger.error(f"Failed to get network stats on {self.ssh_client.server_config.name}: {stderr}")
            return []

        return parse_network_stats(stdout)

    async def collect_processes(self) -> List[ProcessInfo]:
        """收集系统进程信息"""
        success, stdout, stderr = await self.ssh_client.execute_command('ps aux --sort=-%cpu | head -20')

        if not success:
            logger.error(f"Failed to get process info on {self.ssh_client.server_config.name}: {stderr}")
            return []

        return parse_processes(stdout)

    async def collect_hardware_temps(self) -> List[HardwareTempInfo]:
        """收集硬件温度信息"""
        # 尝试使用不同的命令来获取温度信息
        # 首先尝试使用 'sensors' 命令
        success, stdout, stderr = await self.ssh_client.execute_command('sensors')

        if not success or not stdout.strip():
            # 如果 sensors 命令不可用，尝试读取 thermal zone 文件
            success, stdout, stderr = await self.ssh_client.execute_command(
                'for file in /sys/class/thermal/thermal_zone*/temp; do echo "$(basename $(dirname $file)): $(cat $file)"; done'
            )

        if not success:
            logger.error(f"Failed to get hardware temp info on {self.ssh_client.server_config.name}: {stderr}")
            return []

        return parse_hardware_temps(stdout)

    async def collect_custom_command(self, command: str) -> CustomCommandResult:
        """执行自定义命令并返回结果"""
        import time
        start_time = time.time()

        success, stdout, stderr = await self.ssh_client.execute_command(command)

        execution_time = time.time() - start_time

        return CustomCommandResult(
            command=command,
            output=stdout,
            success=success,
            execution_time=execution_time,
            error_message=stderr if not success else None
        )

    async def collect_system_resources(self) -> SystemResourceInfo:
        """收集系统资源信息（CPU、内存、磁盘、网络、进程、温度、自定义命令）"""
        # 首先尝试使用top命令获取CPU和内存信息
        success, stdout, stderr = await self.ssh_client.execute_command('top -bn1 | head -n 5')

        if success and stdout:
            try:
                # 获取内存信息
                sys_info = parse_top(stdout)

                # 获取磁盘信息
                disk_info = await self.collect_disk_usage()
                sys_info.disk_info = disk_info

                # 获取网络信息
                network_info = await self.collect_network_stats()
                sys_info.network_info = network_info

                # 获取进程信息
                process_info = await self.collect_processes()
                sys_info.process_info = process_info

                # 获取硬件温度信息
                temp_info = await self.collect_hardware_temps()
                sys_info.hardware_temp_info = temp_info

                # 获取自定义命令结果
                custom_command_results = await self._execute_custom_commands()
                sys_info.custom_command_results = custom_command_results

                return sys_info
            except Exception as e:
                logger.warning(f"Error parsing top output: {e}")

        # 如果top命令失败，尝试使用free命令获取内存信息
        success, stdout, stderr = await self.ssh_client.execute_command('free -g')

        if success and stdout:
            try:
                sys_info = parse_free(stdout)

                # 获取磁盘信息
                disk_info = await self.collect_disk_usage()
                sys_info.disk_info = disk_info

                # 获取网络信息
                network_info = await self.collect_network_stats()
                sys_info.network_info = network_info

                # 获取进程信息
                process_info = await self.collect_processes()
                sys_info.process_info = process_info

                # 获取硬件温度信息
                temp_info = await self.collect_hardware_temps()
                sys_info.hardware_temp_info = temp_info

                # 获取自定义命令结果
                custom_command_results = await self._execute_custom_commands()
                sys_info.custom_command_results = custom_command_results

                return sys_info
            except Exception as e:
                logger.warning(f"Error parsing free output: {e}")

        # 如果都失败，尝试获取所有信息
        disk_info = await self.collect_disk_usage()
        network_info = await self.collect_network_stats()
        process_info = await self.collect_processes()
        temp_info = await self.collect_hardware_temps()
        custom_command_results = await self._execute_custom_commands()

        # 如果连这些信息也获取不到，则返回空信息
        return SystemResourceInfo(0.0, 0.0, 0.0,
                                 disk_info=disk_info,
                                 network_info=network_info,
                                 process_info=process_info,
                                 hardware_temp_info=temp_info,
                                 custom_command_results=custom_command_results)

    async def _execute_custom_commands(self) -> List[CustomCommandResult]:
        """执行配置的自定义命令"""
        from config import config
        custom_commands = config.monitoring.custom_commands

        results = []
        for cmd_config in custom_commands:
            if cmd_config.enabled:
                result = await self.collect_custom_command(cmd_config.command)
                results.append(result)

        return results
    
    def _serialize_gpu_info(self, gpu):
        """序列化GPU信息以便JSON传输"""
        return {
            'index': gpu.index,
            'name': gpu.name,
            'utilization': gpu.utilization,
            'memory_info': gpu.memory_info.__dict__ if hasattr(gpu.memory_info, '__dict__') else {
                'used': gpu.memory_info.used,
                'total': gpu.memory_info.total,
                'unit': getattr(gpu.memory_info, 'unit', 'MiB')
            },
            'temperature': gpu.temperature,
            'processes': gpu.processes
        }

    def _make_serializable(self, obj):
        """递归地将对象转换为可序列化的格式"""
        if hasattr(obj, 'to_dict'):  # 如果对象有to_dict方法
            return self._make_serializable(obj.to_dict())
        elif isinstance(obj, dict):
            return {key: self._make_serializable(value) for key, value in obj.items()}
        elif isinstance(obj, list):
            return [self._make_serializable(item) for item in obj]
        elif hasattr(obj, '__dict__'):  # 如果是其他对象
            return self._make_serializable(obj.__dict__)
        else:
            return obj

    async def _execute_aggregated_commands(self):
        """执行聚合的命令以减少SSH连接次数"""
        # 定义要执行的命令列表
        commands = [
            'nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits',
            'nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits',
            'ollama ps',
            'top -bn1 | head -n 5',
            'free -g',
            'df -h',
            'cat /proc/net/dev',
            'ps aux --sort=-%cpu | head -20',
            'sensors'
        ]

        # 批量执行命令
        command_outputs = await self.ssh_client.execute_commands_batch(commands)

        # 映射回原命令名称
        results = {
            'nvidia_smi_basic': "",
            'nvidia_smi_proc': "",
            'ollama_ps': "",
            'top': "",
            'free': "",
            'df': "",
            'net_dev': "",
            'processes': "",
            'hardware_temps': ""
        }

        # 根据命令内容映射结果
        for cmd, (success, stdout, stderr) in command_outputs.items():
            if success:
                if 'nvidia-smi --query-gpu' in cmd:
                    results['nvidia_smi_basic'] = stdout
                elif 'nvidia-smi --query-compute-apps' in cmd:
                    results['nvidia_smi_proc'] = stdout
                elif 'ollama ps' in cmd:
                    results['ollama_ps'] = stdout
                elif 'top -bn1' in cmd:
                    results['top'] = stdout
                elif 'free -g' in cmd:
                    results['free'] = stdout
                elif 'df -h' in cmd:
                    results['df'] = stdout
                elif 'cat /proc/net/dev' in cmd:
                    results['net_dev'] = stdout
                elif 'ps aux' in cmd:
                    results['processes'] = stdout
                elif 'sensors' in cmd:
                    results['hardware_temps'] = stdout
            else:
                logger.warning(f"Command '{cmd}' failed: {stderr}")

        return results

    async def collect_all(self) -> Dict:
        """收集所有监控信息 - 使用聚合命令以减少SSH连接"""
        try:
            # 执行聚合命令
            command_results = await self._execute_aggregated_commands()

            # 并行解析各种数据
            tasks = [
                self._parse_ollama_models(command_results.get('ollama_ps', '')),
                self._parse_gpu_info(
                    command_results.get('nvidia_smi_basic', ''),
                    command_results.get('nvidia_smi_proc', '')
                ),
                self._parse_system_resources(
                    command_results.get('top', ''),
                    command_results.get('free', ''),
                    command_results.get('df', ''),
                    command_results.get('net_dev', ''),
                    command_results.get('processes', ''),
                    command_results.get('hardware_temps', '')
                )
            ]

            ollama_models, gpu_info, system_resources = await asyncio.gather(*tasks, return_exceptions=True)

            # 处理可能的异常
            if isinstance(ollama_models, Exception):
                logger.error(f"Error parsing Ollama models: {ollama_models}")
                ollama_models = []

            if isinstance(gpu_info, Exception):
                logger.error(f"Error parsing GPU info: {gpu_info}")
                gpu_info = []

            if isinstance(system_resources, Exception):
                logger.error(f"Error parsing system resources: {system_resources}")
                system_resources = SystemResourceInfo(0.0, 0.0, 0.0)

            # 获取自定义命令结果
            custom_command_results = await self._execute_custom_commands()
            system_resources.custom_command_results = custom_command_results

            result = {
                'server_name': self.ssh_client.server_config.name,
                'timestamp': asyncio.get_event_loop().time(),
                'ollama_models': [model.to_dict() if hasattr(model, 'to_dict') else model.__dict__ for model in ollama_models] if ollama_models else [],
                'gpu_info': [self._serialize_gpu_info(gpu) for gpu in gpu_info] if gpu_info else [],
                'system_resources': system_resources.to_dict() if hasattr(system_resources, 'to_dict') else system_resources.__dict__ if hasattr(system_resources, '__dict__') else {}
            }

            # 收集插件提供的额外指标
            try:
                additional_metrics = await plugin_manager.collect_additional_metrics()
                result['additional_metrics'] = additional_metrics
            except Exception as plugin_error:
                logger.error(f"Error collecting additional metrics from plugins: {plugin_error}")

            # 使用插件处理数据
            try:
                result = plugin_manager.process_data_with_plugins(result)
            except Exception as plugin_error:
                logger.error(f"Error processing data with plugins: {plugin_error}")

            # 将监控数据存储到数据库
            try:
                session = self.db_session()
                # 确保数据可以被JSON序列化
                serializable_result = self._make_serializable(result)
                store_server_metrics(session, self.ssh_client.server_config.name, serializable_result)
                session.close()
            except Exception as db_error:
                logger.error(f"Error storing metrics to database: {db_error}")

            # 评估指标并触发告警
            try:
                # 确保数据可以被JSON序列化
                serializable_result = self._make_serializable(result)
                alert_manager.evaluate_metrics(self.ssh_client.server_config.name, serializable_result)
            except Exception as alert_error:
                logger.error(f"Error evaluating metrics for alerts: {alert_error}")

            # 通过插件发送通知
            try:
                if 'active_alerts' in result and result['active_alerts']:
                    await plugin_manager.send_notifications(serializable_result)
            except Exception as notification_error:
                logger.error(f"Error sending notifications via plugins: {notification_error}")

            return serializable_result
        except Exception as e:
            logger.error(f"Error collecting all metrics: {e}")
            return {
                'server_name': self.ssh_client.server_config.name,
                'error': str(e)
            }

    async def _parse_ollama_models(self, ollama_output: str):
        """解析Ollama模型输出"""
        return parse_ollama_ps(ollama_output)

    async def _parse_gpu_info(self, basic_gpu_output: str, proc_gpu_output: str):
        """解析GPU信息输出"""
        # 解析GPU基本信息
        gpus = []
        basic_lines = basic_gpu_output.strip().split('\n') if basic_gpu_output.strip() else []

        # 解析GPU进程信息
        process_lines = proc_gpu_output.strip().split('\n') if proc_gpu_output.strip() else []
        processes_by_gpu = {}

        for line in process_lines:
            parts = [p.strip() for p in line.split(',')]
            if len(parts) >= 3:  # pid, process_name, used_memory
                try:
                    pid = parts[0]
                    process_name = parts[1]
                    memory_used = int(parts[2])

                    # 由于nvidia-smi输出格式，我们可能需要另一种方式来获取GPU索引
                    # 这里我们暂时将所有进程分配给第一个GPU，后续可改进
                    gpu_index = 0  # 默认分配给第一个GPU

                    if gpu_index not in processes_by_gpu:
                        processes_by_gpu[gpu_index] = []

                    processes_by_gpu[gpu_index].append({
                        'pid': pid,
                        'process_name': process_name,
                        'memory_used': memory_used
                    })
                except ValueError as e:
                    logger.error(f"Error parsing GPU process line: {line}, error: {e}")

        for line in basic_lines:
            parts = [p.strip() for p in line.split(',')]
            if len(parts) >= 6:  # index, name, util, mem_used, mem_total, temp
                try:
                    index = int(parts[0])
                    name = parts[1]
                    util = int(parts[2])
                    mem_used = int(parts[3])
                    mem_total = int(parts[4])
                    temp = int(parts[5])

                    from parsers import GPUMemoryInfo
                    memory_info = GPUMemoryInfo(used=mem_used, total=mem_total)

                    # 获取对应GPU的进程信息
                    processes = processes_by_gpu.get(index, [])

                    gpu_info = GPUInfo(
                        index=index,
                        name=name,
                        utilization=util,
                        memory_info=memory_info,
                        temperature=temp,
                        processes=processes
                    )
                    gpus.append(gpu_info)
                except ValueError as e:
                    logger.error(f"Error parsing GPU info line: {line}, error: {e}")

        return gpus

    async def _parse_system_resources(self, top_output: str, free_output: str, df_output: str = "", net_dev_output: str = "", process_output: str = "", hardware_temps_output: str = ""):
        """解析系统资源输出"""
        # 首先尝试使用top命令的结果
        if top_output:
            try:
                sys_info = parse_top(top_output)
            except Exception as e:
                logger.warning(f"Error parsing top output: {e}")
                sys_info = SystemResourceInfo(0.0, 0.0, 0.0)
        # 如果top命令失败，尝试使用free命令的结果
        elif free_output:
            try:
                sys_info = parse_free(free_output)
            except Exception as e:
                logger.warning(f"Error parsing free output: {e}")
                sys_info = SystemResourceInfo(0.0, 0.0, 0.0)
        else:
            # 如果都失败，返回空信息
            sys_info = SystemResourceInfo(0.0, 0.0, 0.0)

        # 解析磁盘信息
        if df_output:
            try:
                disk_info = parse_df(df_output)
                sys_info.disk_info = disk_info
            except Exception as e:
                logger.warning(f"Error parsing df output: {e}")

        # 解析网络信息
        if net_dev_output:
            try:
                network_info = parse_network_stats(net_dev_output)
                sys_info.network_info = network_info
            except Exception as e:
                logger.warning(f"Error parsing network stats output: {e}")

        # 解析进程信息
        if process_output:
            try:
                process_info = parse_processes(process_output)
                sys_info.process_info = process_info
            except Exception as e:
                logger.warning(f"Error parsing process output: {e}")

        # 解析硬件温度信息
        if hardware_temps_output:
            try:
                temp_info = parse_hardware_temps(hardware_temps_output)
                sys_info.hardware_temp_info = temp_info
            except Exception as e:
                logger.warning(f"Error parsing hardware temps output: {e}")

        # 自定义命令结果需要在运行时获取，不能通过解析预执行的输出
        # 因此这里不处理自定义命令结果
        # 自定义命令结果会在collect_system_resources中单独获取

        return sys_info


from db import create_database

class MultiServerMonitor:
    def __init__(self, ssh_pool):
        self.ssh_pool = ssh_pool
        self.collectors = {}

        # 初始化数据库
        self.engine, self.Session = create_database()

        # 初始化所有收集器
        for server_name, ssh_client in self.ssh_pool.connections.items():
            self.collectors[server_name] = MonitorCollector(ssh_client, self.Session)

    async def collect_from_server_cached(self, server_name: str) -> Dict:
        """从指定服务器收集监控数据 - 使用缓存"""
        # 尝试从缓存获取数据
        cached_data = cache_manager.get_server_metrics(server_name)
        if cached_data is not None:
            logger.debug(f"Cache hit for server: {server_name}")
            return cached_data

        collector = self.collectors.get(server_name)
        if not collector:
            return {'error': f'No collector found for server: {server_name}'}

        data = await collector.collect_all()

        # 将结果存入缓存
        cache_manager.set_server_metrics(server_name, data=data)

        return data

    async def collect_from_all_servers_cached(self) -> Dict:
        """从所有服务器收集监控数据 - 使用缓存"""
        # 尝试从缓存获取数据
        cached_data = cache_manager.get_server_metrics("all_servers")
        if cached_data is not None:
            logger.debug("Cache hit for all servers")
            return cached_data

        results = {}

        # 并行收集所有服务器的数据
        tasks = []
        server_names = []

        for server_name, collector in self.collectors.items():
            tasks.append(collector.collect_all())
            server_names.append(server_name)

        try:
            collected_data = await asyncio.gather(*tasks, return_exceptions=True)

            for i, data in enumerate(collected_data):
                server_name = server_names[i]
                if isinstance(data, Exception):
                    logger.error(f"Error collecting data from {server_name}: {data}")
                    results[server_name] = {'error': str(data)}
                else:
                    results[server_name] = data

        except Exception as e:
            logger.error(f"Error in multi-server collection: {e}")

        # 将结果存入缓存
        cache_manager.set_server_metrics("all_servers", data=results)

        return results
    
    async def collect_from_all_servers(self) -> Dict:
        """从所有服务器收集监控数据"""
        results = {}
        
        # 并行收集所有服务器的数据
        tasks = []
        server_names = []
        
        for server_name, collector in self.collectors.items():
            tasks.append(collector.collect_all())
            server_names.append(server_name)
        
        try:
            collected_data = await asyncio.gather(*tasks, return_exceptions=True)
            
            for i, data in enumerate(collected_data):
                server_name = server_names[i]
                if isinstance(data, Exception):
                    logger.error(f"Error collecting data from {server_name}: {data}")
                    results[server_name] = {'error': str(data)}
                else:
                    results[server_name] = data
        
        except Exception as e:
            logger.error(f"Error in multi-server collection: {e}")
        
        return results