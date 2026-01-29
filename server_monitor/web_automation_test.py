"""
Server Monitor Web自动化测试脚本

此脚本用于测试Server Monitor Web界面的各项功能，
包括页面加载、WebSocket连接、图表显示、Docker状态、CLI功能等。
"""

import unittest
import time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.keys import Keys
import subprocess
import threading
import sys
import os

# 添加项目路径到sys.path，以便导入其他模块
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

class ServerMonitorWebAutomationTest(unittest.TestCase):
    """Server Monitor Web自动化测试类"""
    
    @classmethod
    def setUpClass(cls):
        """在所有测试开始前启动服务器"""
        print("Starting Server Monitor application...")
        
        # 启动Server Monitor应用
        cls.server_process = subprocess.Popen([
            sys.executable, "-c", 
            "from main import app; import uvicorn; uvicorn.run(app, host='127.0.0.1', port=9000)"
        ])
        
        # 等待服务器启动
        time.sleep(5)
        
        # 设置Chrome选项
        chrome_options = Options()
        chrome_options.add_argument("--headless")  # 无头模式，如果不想要看到浏览器界面的话
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        
        # 初始化WebDriver
        cls.driver = webdriver.Chrome(options=chrome_options)
        cls.wait = WebDriverWait(cls.driver, 10)
        
    @classmethod
    def tearDownClass(cls):
        """在所有测试结束后关闭服务器和浏览器"""
        print("Stopping Server Monitor application and closing browser...")
        cls.driver.quit()
        cls.server_process.terminate()
        cls.server_process.wait()

    def setUp(self):
        """在每个测试开始前执行"""
        # 访问主页
        self.driver.get("http://127.0.0.1:9000")
        time.sleep(2)

    def test_page_loads_successfully(self):
        """测试页面是否成功加载"""
        print("Testing if page loads successfully...")
        
        # 等待页面标题出现
        self.wait.until(EC.title_contains("Remote Server Monitor"))
        
        # 检查页面标题
        self.assertIn("Remote Server Monitor", self.driver.title)
        
        # 检查页面是否包含主要元素
        header = self.driver.find_element(By.TAG_NAME, "h4")
        self.assertEqual(header.text, "Remote Server Monitor")
        
        print("Page loaded successfully!")

    def test_dashboard_elements_display(self):
        """测试仪表板元素是否正确显示"""
        print("Testing dashboard elements...")
        
        # 等待服务器概览卡片出现
        overview_card = self.wait.until(
            EC.presence_of_element_located((By.CLASS_NAME, "server-card"))
        )
        
        # 检查是否存在服务器概览标题
        overview_title = self.driver.find_element(By.XPATH, "//h5[text()='All Servers Overview']")
        self.assertIsNotNone(overview_title)
        
        # 检查是否存在自定义按钮
        customize_btn = self.driver.find_element(By.ID, "customizeBtn")
        self.assertIsNotNone(customize_btn)
        
        # 检查是否存在Docker和CLI按钮
        docker_btn = self.driver.find_element(By.ID, "dockerBtn")
        cli_btn = self.driver.find_element(By.ID, "cliBtn")
        self.assertIsNotNone(docker_btn)
        self.assertIsNotNone(cli_btn)
        
        print("Dashboard elements displayed correctly!")

    def test_customize_modal_functionality(self):
        """测试自定义模态框功能"""
        print("Testing customize modal functionality...")
        
        # 点击自定义按钮
        customize_btn = self.driver.find_element(By.ID, "customizeBtn")
        customize_btn.click()
        
        # 等待模态框出现
        modal = self.wait.until(
            EC.visibility_of_element_located((By.ID, "customizeModal"))
        )
        
        # 检查模态框是否可见
        self.assertTrue(modal.is_displayed())
        
        # 检查模态框中的各个复选框
        checkboxes = [
            "showCpu", "showMemory", "showGpu", "showDisk", 
            "showNetwork", "showTemp", "showCustomCmd", "showCharts"
        ]
        
        for checkbox_id in checkboxes:
            checkbox = self.driver.find_element(By.ID, checkbox_id)
            self.assertIsNotNone(checkbox)
            # 验证复选框可以点击
            checkbox.click()
            time.sleep(0.2)  # 短暂延迟
        
        # 检查刷新间隔输入框
        refresh_interval = self.driver.find_element(By.ID, "refreshInterval")
        self.assertIsNotNone(refresh_interval)
        
        # 检查主题选择器
        theme_selector = self.driver.find_element(By.ID, "themeSelector")
        self.assertIsNotNone(theme_selector)
        
        # 点击应用按钮
        apply_btn = self.driver.find_element(By.ID, "applyCustomization")
        apply_btn.click()
        
        # 等待模态框关闭
        self.wait.until_not(
            EC.visibility_of_element_located((By.ID, "customizeModal"))
        )
        
        print("Customize modal functionality tested successfully!")

    def test_charts_display(self):
        """测试图表是否正确显示"""
        print("Testing charts display...")
        
        # 等待图表容器出现
        chart_container = self.wait.until(
            EC.presence_of_element_located((By.ID, "chartsContainer"))
        )
        
        # 检查图表容器是否可见
        self.assertTrue(chart_container.is_displayed())
        
        # 检查是否存在CPU图表
        cpu_chart = self.driver.find_element(By.ID, "cpuChart")
        self.assertIsNotNone(cpu_chart)
        
        # 检查是否存在内存图表
        memory_chart = self.driver.find_element(By.ID, "memoryChart")
        self.assertIsNotNone(memory_chart)
        
        # 检查是否存在GPU图表
        gpu_chart = self.driver.find_element(By.ID, "gpuChart")
        self.assertIsNotNone(gpu_chart)
        
        # 检查是否存在磁盘图表
        disk_chart = self.driver.find_element(By.ID, "diskChart")
        self.assertIsNotNone(disk_chart)
        
        print("Charts displayed correctly!")

    def test_docker_modal_functionality(self):
        """测试Docker模态框功能"""
        print("Testing Docker modal functionality...")
        
        # 点击Docker按钮
        docker_btn = self.driver.find_element(By.ID, "dockerBtn")
        docker_btn.click()
        
        # 等待模态框出现
        modal = self.wait.until(
            EC.visibility_of_element_located((By.ID, "dockerModal"))
        )
        
        # 检查模态框是否可见
        self.assertTrue(modal.is_displayed())
        
        # 检查Docker内容区域
        docker_content = self.driver.find_element(By.ID, "dockerContent")
        self.assertIsNotNone(docker_content)
        
        # 等待一段时间，让Docker内容加载（即使没有实际的Docker环境）
        time.sleep(3)
        
        # 关闭模态框
        close_btn = self.driver.find_element(By.CSS_SELECTOR, "#dockerModal .btn-close")
        close_btn.click()
        
        # 等待模态框关闭
        self.wait.until_not(
            EC.visibility_of_element_located((By.ID, "dockerModal"))
        )
        
        print("Docker modal functionality tested!")

    def test_cli_modal_functionality(self):
        """测试CLI模态框功能"""
        print("Testing CLI modal functionality...")
        
        # 点击CLI按钮
        cli_btn = self.driver.find_element(By.ID, "cliBtn")
        cli_btn.click()
        
        # 等待模态框出现
        modal = self.wait.until(
            EC.visibility_of_element_located((By.ID, "cliModal"))
        )
        
        # 检查模态框是否可见
        self.assertTrue(modal.is_displayed())
        
        # 检查CLI服务器选择器
        cli_server_select = self.driver.find_element(By.ID, "cliServerSelect")
        self.assertIsNotNone(cli_server_select)
        
        # 检查sudo复选框
        cli_use_sudo = self.driver.find_element(By.ID, "cliUseSudo")
        self.assertIsNotNone(cli_use_sudo)
        
        # 检查输出区域
        cli_output = self.driver.find_element(By.ID, "cliOutput")
        self.assertIsNotNone(cli_output)
        
        # 检查输入框
        cli_input = self.driver.find_element(By.ID, "cliInput")
        self.assertIsNotNone(cli_input)
        
        # 关闭模态框
        close_btn = self.driver.find_element(By.CSS_SELECTOR, "#cliModal .btn-close")
        close_btn.click()
        
        # 等待模态框关闭
        self.wait.until_not(
            EC.visibility_of_element_located((By.ID, "cliModal"))
        )
        
        print("CLI modal functionality tested!")

    def test_theme_switching(self):
        """测试主题切换功能"""
        print("Testing theme switching...")
        
        # 检查默认主题（浅色）
        body_classes = self.driver.find_element(By.TAG_NAME, "body").get_attribute("class")
        self.assertNotIn("dark-theme", body_classes)
        
        # 打开自定义模态框
        customize_btn = self.driver.find_element(By.ID, "customizeBtn")
        customize_btn.click()
        
        # 等待模态框出现
        self.wait.until(
            EC.visibility_of_element_located((By.ID, "customizeModal"))
        )
        
        # 选择深色主题
        theme_selector = self.driver.find_element(By.ID, "themeSelector")
        theme_selector.click()
        dark_option = self.driver.find_element(By.CSS_SELECTOR, "#themeSelector option[value='dark']")
        dark_option.click()
        
        # 点击应用按钮
        apply_btn = self.driver.find_element(By.ID, "applyCustomization")
        apply_btn.click()
        
        # 等待模态框关闭
        self.wait.until_not(
            EC.visibility_of_element_located((By.ID, "customizeModal"))
        )
        
        # 等待主题切换生效
        time.sleep(1)
        
        # 检查是否应用了深色主题
        body_classes = self.driver.find_element(By.TAG_NAME, "body").get_attribute("class")
        self.assertIn("dark-theme", body_classes)
        
        print("Theme switching tested successfully!")

    def test_refresh_indicator_updates(self):
        """测试刷新指示器是否更新"""
        print("Testing refresh indicator updates...")
        
        # 获取初始时间
        initial_time_element = self.driver.find_element(By.ID, "last-update-all")
        initial_time = initial_time_element.text
        
        print(f"Initial time: {initial_time}")
        
        # 等待一段时间，让时间更新
        time.sleep(3)
        
        # 获取更新后的时间
        updated_time_element = self.driver.find_element(By.ID, "last-update-all")
        updated_time = updated_time_element.text
        
        print(f"Updated time: {updated_time}")
        
        # 验证时间已更新
        self.assertNotEqual(initial_time, updated_time)
        
        print("Refresh indicator updates correctly!")


def run_tests():
    """运行所有测试"""
    # 创建测试套件
    suite = unittest.TestSuite()
    
    # 添加所有测试方法
    test_class = ServerMonitorWebAutomationTest
    for method in [
        'test_page_loads_successfully',
        'test_dashboard_elements_display',
        'test_customize_modal_functionality',
        'test_charts_display',
        'test_docker_modal_functionality',
        'test_cli_modal_functionality',
        'test_theme_switching',
        'test_refresh_indicator_updates'
    ]:
        suite.addTest(test_class(method))
    
    # 运行测试
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    return result.wasSuccessful()


if __name__ == "__main__":
    print("Starting Server Monitor Web Automation Tests...")
    print("=" * 50)
    
    success = run_tests()
    
    print("=" * 50)
    if success:
        print("All tests passed!")
        sys.exit(0)
    else:
        print("Some tests failed!")
        sys.exit(1)