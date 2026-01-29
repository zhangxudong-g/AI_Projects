import re
import json
from typing import Dict, List, Optional
from dataclasses import dataclass


@dataclass
class OllamaModelInfo:
    """Ollama模型信息"""
    name: str
    parameter_size: str
    size: str
    status: str
    pid: Optional[str] = None

    def to_dict(self):
        """转换为字典格式以便JSON序列化"""
        return asdict(self)


@dataclass
class GPUMemoryInfo:
    """GPU显存信息"""
    used: int  # MB
    total: int  # MB
    unit: str = "MiB"

    def to_dict(self):
        """转换为字典格式以便JSON序列化"""
        return asdict(self)


@dataclass
class GPUInfo:
    """GPU信息"""
    index: int
    name: str
    utilization: int  # 百分比
    memory_info: GPUMemoryInfo
    temperature: int  # 摄氏度
    processes: List[Dict]  # 包含PID、进程名称、显存使用等

    def to_dict(self):
        """转换为字典格式以便JSON序列化"""
        return {
            'index': self.index,
            'name': self.name,
            'utilization': self.utilization,
            'memory_info': self.memory_info.to_dict() if hasattr(self.memory_info, 'to_dict') else self.memory_info.__dict__,
            'temperature': self.temperature,
            'processes': self.processes
        }


from dataclasses import dataclass, asdict
import json

@dataclass
class DiskInfo:
    """磁盘信息"""
    filesystem: str
    size: str
    used: str
    available: str
    percent: int  # 百分比
    mount_point: str

    def to_dict(self):
        """转换为字典格式以便JSON序列化"""
        return asdict(self)


@dataclass
class NetworkInfo:
    """网络信息"""
    interface: str
    receive_bytes: int
    transmit_bytes: int
    receive_packets: int
    transmit_packets: int

    def to_dict(self):
        """转换为字典格式以便JSON序列化"""
        return asdict(self)


@dataclass
class ProcessInfo:
    """进程信息"""
    pid: str
    user: str
    cpu_percent: float
    memory_percent: float
    command: str

    def to_dict(self):
        """转换为字典格式以便JSON序列化"""
        return asdict(self)


@dataclass
class CustomCommandResult:
    """自定义命令执行结果"""
    command: str
    output: str
    success: bool
    execution_time: float  # 执行时间（秒）
    error_message: Optional[str] = None

    def to_dict(self):
        """转换为字典格式以便JSON序列化"""
        return asdict(self)


@dataclass
class HardwareTempInfo:
    """硬件温度信息"""
    sensor_name: str
    temperature: float  # 温度值（摄氏度）
    unit: str = "°C"
    device: Optional[str] = None  # 设备标识

    def to_dict(self):
        """转换为字典格式以便JSON序列化"""
        return asdict(self)


@dataclass
class SystemResourceInfo:
    """系统资源信息"""
    cpu_percent: float
    memory_used: float  # GB
    memory_total: float  # GB
    disk_info: Optional[List[DiskInfo]] = None
    network_info: Optional[List[NetworkInfo]] = None
    process_info: Optional[List[ProcessInfo]] = None
    hardware_temp_info: Optional[List[HardwareTempInfo]] = None
    custom_command_results: Optional[List[CustomCommandResult]] = None
    load_average: Optional[List[float]] = None

    def to_dict(self):
        """转换为字典格式以便JSON序列化"""
        result = {
            'cpu_percent': self.cpu_percent,
            'memory_used': self.memory_used,
            'memory_total': self.memory_total,
            'disk_info': [disk.to_dict() for disk in self.disk_info] if self.disk_info else [],
            'network_info': [net.to_dict() for net in self.network_info] if self.network_info else [],
            'process_info': [proc.to_dict() for proc in self.process_info] if self.process_info else [],
            'hardware_temp_info': [temp.to_dict() for temp in self.hardware_temp_info] if self.hardware_temp_info else [],
            'custom_command_results': [cmd.to_dict() for cmd in self.custom_command_results] if self.custom_command_results else [],
            'load_average': self.load_average
        }
        return result


def parse_ollama_ps(output: str) -> List[OllamaModelInfo]:
    """
    解析 'ollama ps' 命令的输出
    示例输出格式：
    NAME                    ID              SIZE        PROCESSOR       STATUS
    llama2:7b              abc123def456    3.8 GB      gpu:0           running
    mistral:latest         def789ghi012    4.1 GB      cpu             running
    """
    models = []

    # 跳过标题行
    lines = output.strip().split('\n')[1:] if output.strip() else []

    for line in lines:
        if not line.strip():
            continue

        # 使用更灵活的方法来解析，使用固定列宽或多个空格分割
        # 由于字段之间可能有多个空格，我们使用正则表达式按多个空格分割
        parts = re.split(r'\s{2,}', line.strip())  # 按2个或更多空格分割

        if len(parts) >= 3:  # 至少需要NAME, SIZE, STATUS
            # 第一部分是NAME (可能包含冒号)
            name = parts[0].strip()

            # 最后一部分通常是STATUS
            status = parts[-1].strip() if parts else "unknown"

            # SIZE可能是倒数第二个或第三个部分
            size = "unknown"
            if len(parts) >= 3:
                # 尝试找到SIZE字段（通常包含数字和单位如GB）
                for i in range(len(parts)-1, 0, -1):
                    part = parts[i].strip()
                    if re.search(r'(\d+\.?\d*\s*[MGTP]?B|\d+%)', part, re.IGNORECASE):
                        size = part
                        break
                # 如果没找到合适的size，使用倒数第二个
                if size == "unknown" and len(parts) >= 2:
                    size = parts[-2].strip()

            # 从模型名中提取参数规模（例如从"llama2:7b"中提取"7b"）
            param_match = re.search(r':(\d+[mkbgtp])', name, re.IGNORECASE)
            param_size = param_match.group(1) if param_match else "unknown"

            model_info = OllamaModelInfo(
                name=name,
                parameter_size=param_size.upper(),
                size=size,
                status=status
            )
            models.append(model_info)

    return models


def parse_nvidia_smi(output: str) -> List[GPUInfo]:
    """
    解析 'nvidia-smi' 命令的输出
    """
    gpus = []
    
    # 查找GPU信息部分
    gpu_blocks = re.findall(
        r'(\d+)\s+(.+?)\s+(\d+)C\s+.*?(\d+)%\s+(\d+)MiB\s+/(\d+)MiB',
        output
    )
    
    for block in gpu_blocks:
        index = int(block[0])
        name = block[1].strip()
        temperature = int(block[2])
        utilization = int(block[3])
        memory_used = int(block[4])
        memory_total = int(block[5])
        
        memory_info = GPUMemoryInfo(
            used=memory_used,
            total=memory_total
        )
        
        # 查找GPU上的进程信息
        processes = []
        # 匹配进程信息的正则表达式
        proc_pattern = rf'GPU\s+{index}\s+(\d+)\s+(\w+)\s+(\d+)MiB'
        proc_matches = re.findall(proc_pattern, output)
        
        for proc_match in proc_matches:
            pid = proc_match[0]
            process_name = proc_match[1]
            mem_used = int(proc_match[2])
            
            processes.append({
                'pid': pid,
                'process_name': process_name,
                'memory_used': mem_used
            })
        
        gpu_info = GPUInfo(
            index=index,
            name=name,
            utilization=utilization,
            memory_info=memory_info,
            temperature=temperature,
            processes=processes
        )
        
        gpus.append(gpu_info)
    
    return gpus


def parse_top(output: str) -> SystemResourceInfo:
    """
    解析 'top' 或类似命令的输出来获取CPU和内存使用情况
    """
    cpu_percent = 0.0
    memory_used = 0.0
    memory_total = 0.0
    
    # 解析CPU使用率
    cpu_match = re.search(r'Cpu\(s\):\s*([\d.]+)%\s*us', output)
    if cpu_match:
        cpu_percent = float(cpu_match.group(1))
    else:
        # 尝试其他可能的CPU匹配模式
        cpu_match = re.search(r'%Cpu\(s\):\s*([\d.]+)%\s*us', output)
        if cpu_match:
            cpu_percent = float(cpu_match.group(1))
    
    # 解析内存使用情况
    mem_match = re.search(r'Mem:\s*([\d,]+)k total,\s*([\d,]+)k used', output)
    if mem_match:
        total_kb = int(mem_match.group(1).replace(',', ''))
        used_kb = int(mem_match.group(2).replace(',', ''))
        memory_total = total_kb / (1024 * 1024)  # 转换为GB
        memory_used = used_kb / (1024 * 1024)    # 转换为GB
    
    return SystemResourceInfo(
        cpu_percent=cpu_percent,
        memory_used=memory_used,
        memory_total=memory_total
    )


def parse_free(output: str) -> SystemResourceInfo:
    """
    解析 'free -m' 或 'free -g' 命令的输出来获取内存使用情况
    """
    lines = output.strip().split('\n')
    if len(lines) < 2:
        return SystemResourceInfo(0.0, 0.0, 0.0)

    # 获取内存行 (通常是第二行，即 "Mem:")
    mem_line = lines[1]
    parts = mem_line.split()

    if len(parts) >= 3:
        # 假设输出是 'free -g' 的格式（以GB为单位）
        memory_total = float(parts[1])
        memory_used = float(parts[2])
    else:
        # 如果不是预期格式，尝试 'free -m' 的格式并转换为GB
        mem_line = lines[1] if len(lines) > 1 else lines[0]
        parts = [part.replace(',', '') for part in mem_line.split()]

        if len(parts) >= 3:
            memory_total = float(parts[1]) / 1024  # 从MB转换为GB
            memory_used = float(parts[2]) / 1024   # 从MB转换为GB

    return SystemResourceInfo(
        cpu_percent=0.0,  # CPU信息无法从此命令获得
        memory_used=memory_used,
        memory_total=memory_total
    )


def parse_df(output: str) -> List[DiskInfo]:
    """
    解析 'df -h' 命令的输出来获取磁盘使用情况
    """
    disks = []

    # 分割输出行，跳过标题行
    lines = output.strip().split('\n')[1:] if output.strip() else []

    for line in lines:
        # 使用正则表达式匹配 df -h 输出的格式
        # 例如: /dev/sda1        20G   10G  9.0G  50% /
        match = re.match(r'^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)%\s+(.*)', line)
        if match:
            filesystem = match.group(1)
            size = match.group(2)
            used = match.group(3)
            available = match.group(4)
            percent = int(match.group(5))
            mount_point = match.group(6)

            disk_info = DiskInfo(
                filesystem=filesystem,
                size=size,
                used=used,
                available=available,
                percent=percent,
                mount_point=mount_point
            )
            disks.append(disk_info)

    return disks


def parse_network_stats(output: str) -> List[NetworkInfo]:
    """
    解析 '/proc/net/dev' 或 'iftop' 命令的输出来获取网络使用情况
    这里我们解析 /proc/net/dev 的输出格式
    """
    networks = []

    # 分割输出行，跳过标题行
    lines = output.strip().split('\n')[2:] if output.strip() else []  # 跳过标题行

    for line in lines:
        # 移除多余的空白字符
        line = line.strip()
        if not line:
            continue

        # 解析 /proc/net/dev 格式
        # 例如: eth0: 1234567    1234    0    0    0    0   123456    123 7654321    4321    0    0    0    0    0    0
        # 字段顺序: 接口名称, 接收字节数, 接收数据包数, ..., 发送字节数, 发送数据包数, ...
        parts = line.split(':')
        if len(parts) >= 2:
            interface = parts[0].strip()
            stats_part = parts[1].strip()
            stats = stats_part.split()

            if len(stats) >= 16:  # 确保有足够的字段
                try:
                    receive_bytes = int(stats[0])
                    receive_packets = int(stats[1])
                    transmit_bytes = int(stats[8])
                    transmit_packets = int(stats[9])

                    network_info = NetworkInfo(
                        interface=interface,
                        receive_bytes=receive_bytes,
                        transmit_bytes=transmit_bytes,
                        receive_packets=receive_packets,
                        transmit_packets=transmit_packets
                    )
                    networks.append(network_info)
                except ValueError:
                    # 如果转换数字失败，跳过这一行
                    continue

    return networks


def parse_processes(output: str) -> List[ProcessInfo]:
    """
    解析 'ps' 命令的输出来获取进程信息
    """
    processes = []

    # 分割输出行，跳过标题行
    lines = output.strip().split('\n')[1:] if output.strip() else []

    for line in lines:
        # 使用正则表达式匹配 ps aux 或类似命令的输出格式
        # 例如: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND
        match = re.match(r'^(\S+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(.*)', line)
        if match:
            user = match.group(1)
            pid = match.group(2)
            cpu_percent = float(match.group(3))
            memory_percent = float(match.group(4))
            command = match.group(5)

            process_info = ProcessInfo(
                pid=pid,
                user=user,
                cpu_percent=cpu_percent,
                memory_percent=memory_percent,
                command=command
            )
            processes.append(process_info)

    return processes


def parse_hardware_temps(output: str) -> List[HardwareTempInfo]:
    """
    解析 'sensors' 或 'cat /sys/class/thermal/thermal_zone*/temp' 命令的输出来获取硬件温度信息
    """
    temps = []

    # 分割输出行
    lines = output.strip().split('\n') if output.strip() else []

    for line in lines:
        # 解析 sensors 命令的输出格式，例如:
        # coretemp-isa-0000
        # Package id 0:  +45.0°C  (high = +80.0°C, crit = +100.0°C)
        # Core 0:        +43.0°C  (high = +80.0°C, crit = +100.0°C)
        # Core 1:        +42.0°C  (high = +80.0°C, crit = +100.0°C)

        # 或者解析 /sys/class/thermal/ 下的温度文件
        # 例如: 45000 (表示 45.0°C)

        # 匹配 sensors 输出格式
        sensor_match = re.match(r'^\s*(.+?):\s*\+([\d.]+)°C', line)
        if sensor_match:
            sensor_name = sensor_match.group(1).strip()
            temperature = float(sensor_match.group(2))

            temp_info = HardwareTempInfo(
                sensor_name=sensor_name,
                temperature=temperature,
                unit="°C"
            )
            temps.append(temp_info)

        # 匹配 /sys/class/thermal 输出格式 (纯数字，需要除以1000)
        temp_only_match = re.match(r'^\s*(\d+)\s*$', line)
        if temp_only_match:
            raw_temp = int(temp_only_match.group(1))
            # 通常 /sys/class/thermal/thermal_zone*/temp 的值是以毫摄氏度为单位的
            temperature = raw_temp / 1000.0

            temp_info = HardwareTempInfo(
                sensor_name="Thermal Zone",
                temperature=temperature,
                unit="°C"
            )
            temps.append(temp_info)

    return temps