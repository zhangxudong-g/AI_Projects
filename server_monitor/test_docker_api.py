import asyncio
import sys
import os

# 添加项目路径
sys.path.insert(0, r'D:\AI_Projects\server_monitor')

from config import config
from ssh_client import ssh_pool
from main import get_docker_containers, get_docker_images

async def test_docker_api():
    print("初始化SSH连接池...")
    await ssh_pool.initialize_connections(config.servers)
    
    print(f"找到 {len(config.servers)} 个服务器配置")
    
    for server in config.servers:
        print(f"\n测试服务器: {server.name}")
        
        print("获取Docker容器信息...")
        containers_result = await get_docker_containers(server.name)
        print(f"容器结果: {containers_result}")
        
        print("获取Docker镜像信息...")
        images_result = await get_docker_images(server.name)
        print(f"镜像结果: {images_result}")
    
    print("\n关闭SSH连接...")
    await ssh_pool.close_all_connections()

if __name__ == "__main__":
    asyncio.run(test_docker_api())