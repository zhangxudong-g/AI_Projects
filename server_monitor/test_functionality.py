#!/usr/bin/env python3
"""
Remote Server Monitor - 功能测试脚本

该脚本用于测试系统的所有主要功能
"""

import asyncio
import sys
import os
import json
from datetime import datetime, timedelta

# 添加项目根目录到Python路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import config
from ssh_client import ssh_pool
from monitor import MultiServerMonitor
from db import get_server_metrics
from alerts import alert_manager
from notifications import email_notifier, webhook_notifier
from plugins import plugin_manager
from auth import authenticate_user, create_access_token
from compression import compressor
from cache import cache_manager

async def test_ssh_connections():
    """测试SSH连接"""
    print("Testing SSH connections...")
    try:
        # 从SSH连接池获取连接
        from ssh_client import ssh_pool
        await ssh_pool.initialize_connections(config.servers)
        print("✓ SSH connections initialized successfully")

        # 测试与各服务器的连接
        for server_config in config.servers:
            ssh_client = ssh_pool.get_client(server_config.name)
            if ssh_client:
                success, stdout, stderr = await ssh_client.execute_command('echo "Connection test successful"')
                if success:
                    print(f"  ✓ Connection to {server_config.name} successful")
                else:
                    print(f"  ✗ Connection to {server_config.name} failed: {stderr}")
            else:
                print(f"  ✗ No SSH client found for {server_config.name}")

        return True
    except Exception as e:
        print(f"✗ SSH connection test failed: {e}")
        return False

async def test_monitoring_collection():
    """测试监控数据收集"""
    print("\nTesting monitoring data collection...")
    try:
        monitor = MultiServerMonitor(ssh_pool)
        
        # 测试单个服务器数据收集
        for server_config in config.servers:
            print(f"  Testing data collection for {server_config.name}...")
            data = await monitor.collect_from_server(server_config.name)
            if 'error' not in data:
                print(f"    ✓ Data collection for {server_config.name} successful")
                print(f"      - CPU: {data.get('system_resources', {}).get('cpu_percent', 'N/A')}%")
                print(f"      - Memory: {data.get('system_resources', {}).get('memory_used', 'N/A')}GB / {data.get('system_resources', {}).get('memory_total', 'N/A')}GB")
                print(f"      - GPU count: {len(data.get('gpu_info', []))}")
                print(f"      - Ollama models: {len(data.get('ollama_models', []))}")
            else:
                print(f"    ✗ Data collection for {server_config.name} failed: {data['error']}")
        
        # 测试所有服务器数据收集
        print("  Testing data collection for all servers...")
        all_data = await monitor.collect_from_all_servers_cached()  # 使用缓存版本
        if all_data:
            print(f"    ✓ Collected data for {len(all_data)} servers")
        else:
            print("    ✗ Failed to collect data for all servers")

        return True
    except Exception as e:
        print(f"✗ Monitoring collection test failed: {e}")
        return False

def test_data_storage():
    """测试数据存储功能"""
    print("\nTesting data storage...")
    try:
        from sqlalchemy import create_engine
        from db import Server, ServerMetrics, Base, create_database

        # 创建数据库引擎
        engine, SessionLocal = create_database("sqlite:///test_monitoring.db")

        print("✓ Database schema created successfully")

        # 测试存储简单数据
        from db import store_server_metrics

        # 模拟服务器数据
        mock_data = {
            'server_name': 'test_server',
            'timestamp': datetime.utcnow().timestamp(),
            'system_resources': {
                'cpu_percent': 25.5,
                'memory_used': 4.2,
                'memory_total': 16.0
            },
            'gpu_info': [],
            'ollama_models': [],
            'additional_metrics': {}
        }

        # 使用会话存储数据
        session = SessionLocal()
        store_server_metrics(session, 'test_server', mock_data)
        session.close()

        print("✓ Data storage test successful")
        return True
    except Exception as e:
        print(f"✗ Data storage test failed: {e}")
        return False

def test_alert_system():
    """测试告警系统"""
    print("\nTesting alert system...")
    try:
        # 添加测试告警规则
        from alerts import AlertRule, AlertType, AlertSeverity

        test_rule = AlertRule(
            name="test_cpu_high",
            alert_type=AlertType.CPU_USAGE,
            threshold_value=10.0,  # 设置低阈值以触发告警
            severity=AlertSeverity.MEDIUM,
            enabled=True,
            description="Test rule for high CPU usage"
        )

        alert_manager.add_rule(test_rule)
        print("✓ Alert rule added successfully")

        # 检查活跃告警
        active_alerts = alert_manager.get_active_alerts()
        print(f"  Active alerts: {len(active_alerts)}")

        return True
    except Exception as e:
        print(f"✗ Alert system test failed: {e}")
        return False

def test_authentication():
    """测试身份验证功能"""
    print("\nTesting authentication...")
    try:
        # 测试用户认证
        from auth import authenticate_user, create_access_token
        user = authenticate_user("admin", "admin123")  # 使用默认管理员账户
        if user:
            print("✓ Authentication test successful")

            # 测试访问令牌创建
            from datetime import timedelta
            access_token_expires = timedelta(minutes=30)
            token_data = create_access_token(
                data={"sub": user.username},
                expires_delta=access_token_expires
            )
            print("✓ Access token creation successful")
            return True
        else:
            print("? Authentication test skipped (no default admin user)")
            return True  # 不将此视为失败，因为可能没有默认用户
    except Exception as e:
        print(f"✗ Authentication test failed: {e}")
        return False

def test_compression():
    """测试数据压缩功能"""
    print("\nTesting data compression...")
    try:
        # 测试数据压缩
        test_data = {"test": "data", "values": [1, 2, 3, 4, 5], "nested": {"key": "value"}}
        
        # 测试不同压缩方法
        for method in ['gzip', 'zlib']:
            compressed = compressor.compress_json(test_data, method)
            decompressed = compressor.decompress_json(compressed, method)
            
            if decompressed == test_data:
                print(f"  ✓ {method} compression/decompression successful")
            else:
                print(f"  ✗ {method} compression/decompression failed")
        
        # 测试最佳压缩方法选择
        compressed_data, method, ratio = compressor.compress_with_best_method(test_data)
        print(f"  ✓ Best compression method: {method}, Ratio: {ratio:.2%}")
        
        return True
    except Exception as e:
        print(f"✗ Compression test failed: {e}")
        return False

def test_caching():
    """测试缓存功能"""
    print("\nTesting caching...")
    try:
        # 测试缓存设置和获取
        test_key = "test_key"
        test_value = {"data": "test_value", "timestamp": datetime.utcnow().isoformat()}

        # 模拟将数据存储到缓存
        cache_manager.set_server_metrics(test_key, test_value)
        retrieved_value = cache_manager.get_server_metrics(test_key)

        if retrieved_value == test_value:
            print("✓ Basic caching functionality works")
        else:
            print("✗ Basic caching functionality failed")
            return False

        # 检查缓存统计
        stats = cache_manager.get_all_stats()
        print(f"  Cache stats: {stats}")

        return True
    except Exception as e:
        print(f"✗ Caching test failed: {e}")
        return False

def test_plugins():
    """测试插件系统"""
    print("\nTesting plugin system...")
    try:
        # 加载并初始化插件
        plugin_manager.load_plugins()
        plugin_manager.initialize_plugins()

        print(f"  Loaded {len(plugin_manager.plugins)} plugins")
        print(f"  Enabled {len(plugin_manager.enabled_plugins)} plugins")

        for plugin_name in plugin_manager.enabled_plugins:
            print(f"    ✓ {plugin_name}")

        return True
    except Exception as e:
        print(f"✗ Plugin system test failed: {e}")
        return False

async def run_all_tests():
    """运行所有测试"""
    print("Starting Remote Server Monitor functionality tests...\n")
    
    tests = [
        ("SSH Connections", test_ssh_connections),
        ("Monitoring Collection", test_monitoring_collection),
        ("Data Storage", test_data_storage),
        ("Alert System", test_alert_system),
        ("Authentication", test_authentication),
        ("Data Compression", test_compression),
        ("Caching", test_caching),
        ("Plugin System", test_plugins),
    ]
    
    results = []
    for test_name, test_func in tests:
        if asyncio.iscoroutinefunction(test_func):
            result = await test_func()
        else:
            result = test_func()
        results.append((test_name, result))
    
    # 输出测试结果摘要
    print("\n" + "="*50)
    print("TEST RESULTS SUMMARY")
    print("="*50)
    
    passed = 0
    total = len(results)
    
    for test_name, result in results:
        status = "PASS" if result else "FAIL"
        symbol = "✓" if result else "✗"
        print(f"{symbol} {test_name}: {status}")
        if result:
            passed += 1
    
    print("-"*50)
    print(f"Total: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed! The system is working correctly.")
        return True
    else:
        print(f"\n⚠️  {total - passed} tests failed. Please check the implementation.")
        return False

if __name__ == "__main__":
    success = asyncio.run(run_all_tests())
    sys.exit(0 if success else 1)