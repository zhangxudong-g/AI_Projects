# Server Monitor Web自动化测试

本项目包含用于测试Server Monitor Web界面的自动化测试脚本。

## 测试内容

该测试套件包含以下测试：

1. **API端点测试** - 验证所有API端点是否正常工作
2. **Web界面测试** - 使用Selenium测试Web界面的交互功能
3. **WebSocket连接测试** - 验证WebSocket连接是否正常
4. **图表功能测试** - 验证实时图表是否正确更新
5. **Docker状态功能测试** - 验证Docker状态查看功能
6. **CLI功能测试** - 验证Web CLI功能
7. **主题切换测试** - 验证深色/浅色主题切换
8. **自定义仪表板测试** - 验证仪表板定制功能

## 依赖项

运行测试前，请确保安装以下依赖项：

```bash
pip install -r requirements.txt
```

## 运行测试

### 方法1：运行完整的测试套件

```bash
python test_runner.py
```

### 方法2：仅运行API测试

```bash
python web_automation_simple_test.py
```

### 方法3：运行Web自动化测试（需要Selenium）

```bash
python web_automation_test.py
```

## 测试脚本说明

- `test_runner.py` - 主测试运行器，自动检测可用的测试类型并运行
- `web_automation_simple_test.py` - 基于requests的API测试
- `web_automation_test.py` - 基于Selenium的Web界面测试
- `requirements.txt` - 测试所需的依赖项

## 测试覆盖范围

### 仪表板功能
- [x] 页面加载
- [x] 服务器概览显示
- [x] 实时数据更新
- [x] 图表可视化
- [x] 自定义仪表板设置

### 交互功能
- [x] Docker状态模态框
- [x] Web CLI模态框
- [x] GPU历史峰值模态框
- [x] 主题切换功能

### API端点
- [x] `/health` - 健康检查
- [x] `/api/servers` - 服务器列表
- [x] `/api/all-servers` - 所有服务器数据
- [x] `/api/server/{server_name}` - 单个服务器数据
- [x] WebSocket端点 - 实时数据流

## 浏览器驱动

如果使用Selenium测试，系统将自动下载适当的浏览器驱动。你也可以手动安装ChromeDriver：

1. 下载ChromeDriver：https://chromedriver.chromium.org/
2. 将其添加到系统PATH中

## 注意事项

1. 确保Server Monitor应用程序正在运行（默认端口9000）
2. 某些测试可能需要实际的服务器连接才能完全验证功能
3. Web自动化测试在无头模式下运行，如需查看浏览器界面，请修改测试脚本中的Chrome选项

## 故障排除

如果遇到问题，请检查：

1. Server Monitor是否正在运行
2. 端口9000是否可用
3. 所有依赖项是否已正确安装
4. 浏览器驱动是否正确配置