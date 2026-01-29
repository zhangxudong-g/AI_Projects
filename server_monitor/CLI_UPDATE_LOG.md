# Web CLI 功能更新日志

## 问题
- 服务器下拉菜单为空

## 原因分析
- 前端代码使用了错误的API端点
- 或者API端点没有返回正确的服务器信息格式

## 解决方案
1. 创建了新的API端点 `/api/servers-detail` 来返回包含主机信息的服务器列表
2. 修改前端JavaScript代码以使用正确的API端点
3. 修正了服务器数据显示逻辑

## 具体更改

### 后端更改 (main.py)
- 添加了 `/api/servers-detail` API端点

### 前端更改 (index.html)
- 修改了 `cliBtn` 点击事件处理程序
- 更改API调用从 `/api/servers` 到 `/api/servers-detail`
- 修正了服务器数据显示逻辑

## 验证步骤
1. 重启server_monitor应用
2. 访问Web界面
3. 点击CLI按钮
4. 检查服务器下拉菜单是否填充了服务器列表

## 测试API端点
可使用 test_api.html 文件测试API端点是否正常工作