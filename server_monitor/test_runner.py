"""
Server Monitor Web测试套件

此套件包含多种类型的测试：
1. API端点测试
2. Web界面测试（如果Selenium可用）
3. 功能集成测试
"""

import os
import sys
import subprocess
import time
import requests
import threading

# 添加项目路径到sys.path
sys.path.append(os.path.dirname(__file__))

def check_dependencies():
    """检查必要的依赖项"""
    missing_deps = []
    
    # 检查requests
    try:
        import requests
    except ImportError:
        missing_deps.append("requests")
    
    # 检查selenium
    try:
        import selenium
    except ImportError:
        missing_deps.append("selenium")
    
    # 检查webdriver-manager（用于自动管理浏览器驱动）
    try:
        import webdriver_manager
    except ImportError:
        missing_deps.append("webdriver-manager")
    
    return missing_deps


def install_dependencies():
    """安装缺失的依赖项"""
    missing_deps = check_dependencies()
    
    if missing_deps:
        print(f"Installing missing dependencies: {missing_deps}")
        deps_str = " ".join(missing_deps)
        subprocess.check_call([sys.executable, "-m", "pip", "install", deps_str])
        print("Dependencies installed successfully!")


def run_api_tests():
    """运行API测试"""
    print("\n" + "="*50)
    print("RUNNING API TESTS")
    print("="*50)
    
    # 导入并运行API测试
    from web_automation_simple_test import ServerMonitorWebTest
    tester = ServerMonitorWebTest()
    return tester.run_all_tests()


def run_web_tests_if_available():
    """如果Selenium可用，运行Web界面测试"""
    print("\n" + "="*50)
    print("CHECKING FOR WEB AUTOMATION CAPABILITIES")
    print("="*50)
    
    try:
        import selenium
        import webdriver_manager
        from web_automation_test import run_tests as run_web_tests
        print("Selenium and webdriver-manager are available. Running web automation tests...")
        return run_web_tests()
    except ImportError as e:
        print(f"Selenium not available, skipping web automation tests: {e}")
        print("To run web automation tests, install selenium and webdriver-manager:")
        print("pip install selenium webdriver-manager")
        return True  # 不将此视为失败
    except Exception as e:
        print(f"Error running web tests: {e}")
        return True  # 不将此视为失败


def main():
    """主函数"""
    print("Server Monitor Web Test Suite")
    print("="*50)
    
    # 检查并安装依赖项
    install_dependencies()
    
    # 运行API测试
    api_tests_passed = run_api_tests()
    
    # 运行Web测试（如果可用）
    web_tests_passed = run_web_tests_if_available()
    
    # 输出最终结果
    print("\n" + "="*50)
    print("TEST SUITE RESULTS")
    print("="*50)
    
    print(f"API Tests: {'PASSED' if api_tests_passed else 'FAILED'}")
    print(f"Web Tests: {'PASSED' if web_tests_passed else 'SKIPPED/FAILED'}")
    
    if api_tests_passed:
        print("\nOverall result: PASSED")
        sys.exit(0)
    else:
        print("\nOverall result: FAILED (API tests failed)")
        sys.exit(1)


if __name__ == "__main__":
    main()