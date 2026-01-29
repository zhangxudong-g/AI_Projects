import asyncio
import asyncssh
from typing import Dict, Optional, Tuple
from config import ServerConfig
import logging
import time
from collections import deque

logger = logging.getLogger(__name__)


class SSHClient:
    def __init__(self, server_config: ServerConfig):
        self.server_config = server_config
        self.connection = None
        self.last_used = time.time()
        self.command_count = 0  # 统计命令执行次数
        self.reconnect_threshold = 100  # 每执行100个命令后重连，避免长时间连接问题

    async def connect(self):
        """建立SSH连接"""
        try:
            # 准备连接参数
            conn_args = {
                'host': self.server_config.host,
                'port': self.server_config.port,
                'username': self.server_config.username,
            }

            # 根据认证方式选择参数
            if self.server_config.ssh_key_path:
                conn_args['client_keys'] = [self.server_config.ssh_key_path]
            elif self.server_config.password:
                conn_args['password'] = self.server_config.password
            else:
                raise ValueError("Either ssh_key_path or password must be provided")

            # 建立连接
            self.connection = await asyncssh.connect(**conn_args)
            self.last_used = time.time()
            self.command_count = 0
            logger.info(f"Connected to {self.server_config.name} ({self.server_config.host})")
            return True

        except Exception as e:
            logger.error(f"Failed to connect to {self.server_config.name}: {str(e)}")
            return False

    async def disconnect(self):
        """断开SSH连接"""
        if self.connection:
            self.connection.close()
            await self.connection.wait_closed()
            logger.info(f"Disconnected from {self.server_config.name}")

    async def ensure_connection(self):
        """确保连接有效，如果无效则重新连接"""
        if not self.connection:
            logger.info(f"Connection to {self.server_config.name} is not established, connecting...")
            return await self.connect()

        # 检查连接是否仍然有效
        try:
            # 尝试发送一个简单的命令来检查连接状态
            result = await self.connection.run('echo ping', check=False, timeout=5)
            if result.exit_status != 0:
                logger.warning(f"Connection to {self.server_config.name} appears to be broken, reconnecting...")
                await self.disconnect()
                return await self.connect()
        except Exception as e:
            logger.warning(f"Connection to {self.server_config.name} failed check, reconnecting: {str(e)}")
            await self.disconnect()
            return await self.connect()

        return True

    async def execute_command(self, command: str, use_sudo: bool = False) -> Tuple[bool, str, str]:
        """
        执行远程命令
        返回: (success, stdout, stderr)
        """
        # 确保连接有效
        if not await self.ensure_connection():
            logger.error("Unable to establish connection to execute command")
            return False, "", "Unable to establish connection"

        try:
            # 如果需要sudo且有sudo密码，则使用expect脚本或类似方法
            if use_sudo and self.server_config.sudo_password:
                # 构建带sudo密码的命令
                sudo_command = f'echo "{self.server_config.sudo_password}" | sudo -S {command}'
                result = await self.connection.run(sudo_command, check=False, timeout=30)
            elif use_sudo:
                # 如果需要sudo但没有密码，则直接执行sudo命令（假设已配置免密或用户已认证）
                result = await self.connection.run(f'sudo {command}', check=False, timeout=30)
            else:
                # 普通命令执行
                result = await self.connection.run(command, check=False, timeout=30)

            success = result.exit_status == 0
            stdout = result.stdout if result.stdout else ""
            stderr = result.stderr if result.stderr else ""

            # 更新使用统计
            self.last_used = time.time()
            self.command_count += 1

            # 如果命令执行次数达到阈值，考虑重连以避免长时间连接问题
            if self.command_count >= self.reconnect_threshold:
                logger.info(f"Command count threshold reached for {self.server_config.name}, preparing for reconnect after next command")
                # 标记下次使用时重连
                await self.disconnect()

            return success, stdout, stderr
        except Exception as e:
            logger.error(f"Error executing command '{command}' on {self.server_config.name}: {str(e)}")
            # 发生错误时断开连接，下次会自动重连
            await self.disconnect()
            return False, "", str(e)

    async def execute_commands_batch(self, commands: list, use_sudo: bool = False) -> Dict[str, Tuple[bool, str, str]]:
        """
        批量执行命令 - 通过单个会话优化
        """
        # 确保连接有效
        if not await self.ensure_connection():
            logger.error("Unable to establish connection to execute commands")
            return {cmd: (False, "", "Unable to establish connection") for cmd in commands}

        results = {}
        for cmd in commands:
            try:
                # 如果需要sudo且有sudo密码，则使用expect脚本或类似方法
                if use_sudo and self.server_config.sudo_password:
                    # 构建带sudo密码的命令
                    sudo_command = f'echo "{self.server_config.sudo_password}" | sudo -S {cmd}'
                    result = await self.connection.run(sudo_command, check=False, timeout=30)
                elif use_sudo:
                    # 如果需要sudo但没有密码，则直接执行sudo命令（假设已配置免密或用户已认证）
                    result = await self.connection.run(f'sudo {cmd}', check=False, timeout=30)
                else:
                    # 普通命令执行
                    result = await self.connection.run(cmd, check=False, timeout=30)

                success = result.exit_status == 0
                stdout = result.stdout if result.stdout else ""
                stderr = result.stderr if result.stderr else ""
                results[cmd] = (success, stdout, stderr)

                # 更新使用统计
                self.last_used = time.time()
                self.command_count += 1

                # 检查是否需要重连
                if self.command_count >= self.reconnect_threshold:
                    logger.info(f"Command count threshold reached for {self.server_config.name}, preparing for reconnect")
                    await self.disconnect()
                    break  # 退出循环，下次批量操作时会重连
            except Exception as e:
                logger.error(f"Error executing command '{cmd}' on {self.server_config.name}: {str(e)}")
                results[cmd] = (False, "", str(e))
                # 发生错误时断开连接，下次会自动重连
                await self.disconnect()
                break  # 退出循环，避免连续错误

        return results

    async def execute_interactive_command(self, command: str, use_sudo: bool = False):
        """
        执行交互式命令，返回一个异步生成器，逐步返回输出
        """
        # 确保连接有效
        if not await self.ensure_connection():
            logger.error("Unable to establish connection to execute command")
            yield False, "", "Unable to establish connection"
            return

        try:
            # 如果需要sudo且有sudo密码，则构建带sudo密码的命令
            if use_sudo and self.server_config.sudo_password:
                # 使用管道传递密码给sudo
                full_command = f'echo "{self.server_config.sudo_password}" | sudo -S bash -c "{command}"'
            elif use_sudo:
                # 如果没有配置sudo密码，尝试直接执行sudo（假设已配置免密或用户已认证）
                # 但这样会导致交互式密码提示，所以我们需要另一种方式
                # 先检查是否可以无密码执行sudo
                check_cmd = 'sudo -n true'
                check_process = await self.connection.create_process(check_cmd)
                check_process.stdin.write_eof()
                check_result = await check_process.wait()

                if check_result == 0:
                    # 可以无密码执行sudo
                    full_command = f'sudo bash -c "{command}"'
                else:
                    # 无法无密码执行sudo，返回错误信息
                    yield False, "", "Sudo requires password but none provided in config"
                    return
            else:
                full_command = f'bash -c "{command}"'

            # 创建进程
            process = await self.connection.create_process(full_command)

            # 发送命令并读取输出
            process.stdin.write_eof()

            # 读取所有stdout
            stdout_output = await process.stdout.read()
            # 读取所有stderr
            stderr_output = await process.stderr.read()

            # 等待进程结束并检查退出状态
            result = await process.wait()
            success = result == 0

            yield success, stdout_output, stderr_output

        except Exception as e:
            logger.error(f"Error executing interactive command '{command}' on {self.server_config.name}: {str(e)}")
            yield False, "", str(e)
            # 发生错误时断开连接，下次会自动重连
            await self.disconnect()


class SSHConnectionPool:
    def __init__(self):
        self.connections: Dict[str, SSHClient] = {}
        self.max_idle_time = 300  # 最大空闲时间（秒），超过此时间将关闭连接
        self.cleanup_task = None

    async def initialize_connections(self, server_configs):
        """初始化所有服务器连接"""
        for server_config in server_configs:
            client = SSHClient(server_config)
            if await client.connect():
                self.connections[server_config.name] = client
            else:
                logger.warning(f"Failed to connect to {server_config.name}")

        # 启动定期清理任务
        self.cleanup_task = asyncio.create_task(self.periodic_cleanup())

    async def periodic_cleanup(self):
        """定期清理空闲连接"""
        while True:
            try:
                await asyncio.sleep(60)  # 每分钟检查一次
                await self.cleanup_idle_connections()
            except asyncio.CancelledError:
                logger.info("Connection pool cleanup task cancelled")
                break
            except Exception as e:
                logger.error(f"Error in connection pool cleanup: {e}")

    async def cleanup_idle_connections(self):
        """清理空闲连接"""
        current_time = time.time()
        idle_connections = []

        for name, client in self.connections.items():
            if current_time - client.last_used > self.max_idle_time:
                idle_connections.append(name)

        for name in idle_connections:
            client = self.connections[name]
            logger.info(f"Cleaning up idle connection to {name}")
            await client.disconnect()
            del self.connections[name]

    async def close_all_connections(self):
        """关闭所有连接"""
        if self.cleanup_task:
            self.cleanup_task.cancel()
            try:
                await self.cleanup_task
            except asyncio.CancelledError:
                pass

        for client in self.connections.values():
            await client.disconnect()
        self.connections.clear()

    def get_client(self, server_name: str) -> Optional[SSHClient]:
        """获取指定服务器的SSH客户端"""
        return self.connections.get(server_name)

    def get_all_clients(self):
        """获取所有SSH客户端"""
        return self.connections.values()


# 全局连接池实例
ssh_pool = SSHConnectionPool()