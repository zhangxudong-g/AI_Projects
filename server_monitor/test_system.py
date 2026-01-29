"""
测试脚本 - 验证监控系统的各个组件
"""
import asyncio
import sys
import os

# 添加项目根目录到Python路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import config
from ssh_client import SSHClient
from parsers import parse_ollama_ps, parse_nvidia_smi
from monitor import MonitorCollector


async def test_ssh_connection(server_config):
    """测试SSH连接"""
    print(f"Testing SSH connection to {server_config.name}...")
    client = SSHClient(server_config)
    
    connected = await client.connect()
    if connected:
        print(f"[OK] Connected to {server_config.name}")

        # 测试执行简单命令
        success, stdout, stderr = await client.execute_command('uname -a')
        if success:
            print(f"[OK] Command executed successfully: {stdout.strip()}")
        else:
            print(f"[ERROR] Command failed: {stderr}")

        await client.disconnect()
        print(f"[OK] Disconnected from {server_config.name}")
    else:
        print(f"[ERROR] Failed to connect to {server_config.name}")
    
    return connected


def test_parsers():
    """测试解析器功能"""
    print("\nTesting parsers...")
    
    # 测试Ollama解析器
    sample_ollama_output = """NAME                    ID              SIZE        PROCESSOR       STATUS
llama2:7b              abc123def456    3.8 GB      gpu:0           running
mistral:latest         def789ghi012    4.1 GB      cpu             running
"""
    models = parse_ollama_ps(sample_ollama_output)
    print(f"[OK] Parsed {len(models)} Ollama models")
    for model in models:
        print(f"  - {model.name}: {model.status}, {model.size}")

    # 测试nvidia-smi解析器（简化版）
    sample_nvidia_output = """index,name,utilization.gpu,memory.used,memory.total,temperature.gpu
0,NVIDIA GeForce RTX 3080,75,8192,12288,72
1,NVIDIA GeForce RTX 3080,23,2048,12288,65
"""
    gpus = parse_nvidia_smi(sample_nvidia_output)
    print(f"[OK] Parsed {len(gpus)} GPUs")
    for gpu in gpus:
        print(f"  - GPU {gpu.index}: {gpu.name}, {gpu.utilization}% utilization")


async def test_monitor_collector(server_config):
    """测试监控收集器"""
    print(f"\nTesting monitor collector for {server_config.name}...")
    
    client = SSHClient(server_config)
    connected = await client.connect()
    
    if connected:
        collector = MonitorCollector(client)
        
        # 测试收集Ollama模型信息
        print("  Testing Ollama model collection...")
        models = await collector.collect_ollama_models()
        print(f"  [OK] Collected {len(models)} models")

        # 测试收集GPU信息
        print("  Testing GPU info collection...")
        gpus = await collector.collect_gpu_info()
        print(f"  [OK] Collected {len(gpus)} GPUs")

        # 测试收集系统资源
        print("  Testing system resource collection...")
        system_info = await collector.collect_system_resources()
        print(f"  [OK] Collected system info: CPU={system_info.cpu_percent}%, Memory={system_info.memory_used}/{system_info.memory_total}GB")

        await client.disconnect()
    else:
        print(f"  [ERROR] Cannot test collector - failed to connect to {server_config.name}")


async def main():
    print("=== Server Monitor System Test ===\n")
    
    # 测试配置加载
    print(f"Loaded {len(config.servers)} servers from config")
    for server in config.servers:
        print(f"  - {server.name}: {server.host}:{server.port}")
    
    # 测试SSH连接
    for server in config.servers:
        await test_ssh_connection(server)
    
    # 测试解析器
    test_parsers()
    
    # 测试监控收集器（仅对第一个服务器）
    if config.servers:
        await test_monitor_collector(config.servers[0])
    
    print("\n=== Test Complete ===")


if __name__ == "__main__":
    asyncio.run(main())