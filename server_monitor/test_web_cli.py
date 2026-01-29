import asyncio
import sys
import os

# 添加项目路径
sys.path.insert(0, r'D:\AI_Projects\server_monitor')

from config import config
from ssh_client import ssh_pool
from main import connect, disconnect

async def test_cli_functionality():
    print("=== 测试Web CLI功能 ===")
    
    print("初始化SSH连接池...")
    await ssh_pool.initialize_connections(config.servers)
    
    print(f"找到 {len(config.servers)} 个服务器配置:")
    for i, server in enumerate(config.servers):
        print(f"  {i+1}. {server.name} ({server.host})")
    
    if len(config.servers) == 0:
        print("错误: 没有找到服务器配置")
        return
    
    # 选择第一个服务器进行测试
    test_server = config.servers[0]
    print(f"\n测试服务器: {test_server.name}")
    
    # 获取SSH客户端
    client = ssh_pool.get_client(test_server.name)
    if not client:
        print(f"错误: 无法获取 {test_server.name} 的SSH客户端")
        return
    
    print("测试基本命令执行...")
    try:
        # 测试基本命令
        success, stdout, stderr = await client.execute_command("echo 'Hello from CLI test'", use_sudo=False)
        print(f"命令执行结果 - 成功: {success}")
        if stdout:
            print(f"标准输出: {stdout.strip()}")
        if stderr:
            print(f"错误输出: {stderr.strip()}")
    except Exception as e:
        print(f"执行基本命令时出错: {e}")
    
    print("\n测试sudo命令执行...")
    try:
        # 测试sudo命令（如果配置了sudo密码）
        success, stdout, stderr = await client.execute_command("whoami", use_sudo=True)
        print(f"sudo命令执行结果 - 成功: {success}")
        if stdout:
            print(f"标准输出: {stdout.strip()}")
        if stderr:
            print(f"错误输出: {stderr.strip()}")
    except Exception as e:
        print(f"执行sudo命令时出错: {e}")
    
    print("\n测试交互式命令执行...")
    try:
        # 测试交互式命令
        print("执行 'ls -la' 命令:")
        async for success, stdout, stderr in client.execute_interactive_command("ls -la", use_sudo=False):
            if stdout:
                print(f"输出: {stdout.strip()}")
            if stderr:
                print(f"错误: {stderr.strip()}")
            if success is not None and stderr == "" and stdout == "":
                print(f"命令完成 - 成功: {success}")
                break
    except Exception as e:
        print(f"执行交互式命令时出错: {e}")
    
    print("\n关闭SSH连接...")
    await ssh_pool.close_all_connections()
    print("测试完成!")

if __name__ == "__main__":
    asyncio.run(test_cli_functionality())