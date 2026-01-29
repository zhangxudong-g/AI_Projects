# Remote Server Monitor

一个用于实时监控远程Linux服务器运行状态的Web系统，特别针对Ollama模型和GPU使用情况进行监控。

## 功能特性

- **实时监控**: 通过WebSocket实时推送服务器状态
- **多服务器支持**: 可同时监控多个远程服务器
- **Ollama模型监控**: 显示当前运行的Ollama模型及其资源使用情况
- **GPU监控**: 实时显示GPU利用率、显存使用、温度等信息
- **系统资源监控**: 监控CPU、内存使用情况
- **磁盘监控**: 显示磁盘使用情况和可用空间
- **网络监控**: 监控网络接口流量和带宽使用情况
- **进程监控**: 显示系统中运行的进程及其资源使用情况
- **硬件温度监控**: 监控CPU、主板等硬件温度
- **自定义命令监控**: 支持配置自定义命令进行监控
- **告警系统**: 基于阈值的智能告警，支持多种告警类型和严重级别
- **邮件通知**: 支持通过电子邮件发送告警通知
- **Webhook通知**: 支持通过HTTP请求发送告警通知到第三方系统
- **数据存储**: 将监控数据存储到数据库，支持历史数据分析
- **历史数据分析**: 提供历史数据查询和分析功能
- **数据可视化**: 提供图表和图形化展示监控数据
- **身份验证**: 支持用户身份验证和会话管理
- **访问控制**: 基于角色的权限控制系统
- **SSH连接池优化**: 高效的SSH连接管理和复用
- **数据压缩**: 支持传输数据的压缩以减少带宽使用
- **数据缓存**: 实现智能缓存机制以提高响应速度
- **插件系统**: 支持插件扩展，可自定义监控功能
- **API扩展**: 提供丰富的API端点以支持二次开发
- **Web界面**: 直观的仪表板界面，实时展示所有监控数据
- **响应式设计**: 支持桌面和移动设备的自适应界面
- **深色模式**: 支持深色/浅色主题切换

## 项目状态

✅ **已完成**: 所有功能均已实现并通过测试

## 技术栈

- **后端**: FastAPI, AsyncSSH
- **前端**: HTML, CSS, JavaScript (Bootstrap)
- **协议**: WebSocket
- **数据解析**: 正则表达式解析命令行输出

## 系统架构

```
[浏览器] <--WebSocket--> [FastAPI服务器] <--SSH--> [远程Linux服务器]
   |                          |                      |
[实时UI] <--JSON数据---- [数据采集器] ---- [命令执行]
```

## 安装部署

### 1. 克隆项目

```bash
git clone <repository-url>
cd server_monitor
```

### 2. 安装依赖

```bash
pip install -r requirements.txt
```

### 3. 配置服务器信息

编辑 `config.yaml` 文件，添加您的服务器信息：

```yaml
servers:
  - name: "Production Server"
    host: "192.168.1.100"
    port: 22
    username: "your_username"
    ssh_key_path: "~/.ssh/id_rsa"
    # password: "your_password"  # 如果使用密码认证

monitoring:
  refresh_interval: 1  # 监控刷新间隔（秒）
  gpu_refresh_interval: 0.5  # GPU监控刷新间隔（秒）
  custom_commands:
    - name: "Disk Usage Check"
      command: "df -h | grep -E '^/dev/' | awk '{print $5 \" \" $1 \" \" $6}'"
      enabled: true
      interval: 60
    - name: "Load Average"
      command: "uptime | awk -F'load average:' '{print $2}'"
      enabled: true
      interval: 30
  email_notifications:
    smtp_server: "smtp.gmail.com"
    smtp_port: 587
    username: "your_email@gmail.com"
    password: "your_app_password"
    sender_email: "your_email@gmail.com"
    recipient_emails: ["admin@example.com", "ops@example.com"]
    enabled: true
    use_tls: true
  webhook_notifications:
    url: "https://hooks.example.com/webhook"
    headers:
      Authorization: "Bearer your_token"
      Content-Type: "application/json"
    enabled: true
    timeout: 30

ollama:
  enabled: true
  endpoint: "http://localhost:11434"
```

### 4. 启动服务

```bash
python main.py
```

服务将启动在 `http://localhost:8000`

## 使用说明

### 配置SSH密钥认证（推荐）

1. 在本地生成SSH密钥对（如果还没有）：
```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

2. 将公钥复制到远程服务器：
```bash
ssh-copy-id username@remote_host
```

3. 在 `config.yaml` 中配置SSH密钥路径

### 监控数据

系统会定期收集以下数据：

- **Ollama模型**: 通过 `ollama ps` 命令获取
- **GPU信息**: 通过 `nvidia-smi` 命令获取
- **系统资源**: 通过 `top` 和 `free` 命令获取

## API端点

- `GET /` - 主页面
- `GET /api/servers` - 获取服务器列表
- `GET /api/server/{server_name}` - 获取指定服务器数据
- `GET /api/all-servers` - 获取所有服务器数据
- `GET /api/history/{server_name}` - 获取指定服务器的历史数据
- `GET /api/history-all` - 获取所有服务器的历史数据
- `GET /api/analysis/{server_name}` - 获取服务器的历史数据分析
- `GET /api/visualization/{server_name}` - 获取用于可视化的数据
- `GET /api/alerts/active` - 获取活跃告警
- `GET /api/alerts/history` - 获取告警历史
- `POST /api/alerts/rules` - 添加告警规则
- `DELETE /api/alerts/rules/{rule_name}` - 删除告警规则
- `GET /api/alerts/rules` - 获取所有告警规则
- `POST /api/alerts/{alert_id}/acknowledge` - 确认告警
- `GET /api/email/config` - 获取邮件配置
- `POST /api/email/config` - 更新邮件配置
- `POST /api/email/test` - 测试邮件配置
- `GET /api/webhook/config` - 获取Webhook配置
- `POST /api/webhook/config` - 更新Webhook配置
- `POST /api/webhook/test` - 测试Webhook配置
- `GET /health` - 健康检查
- `WS /ws/{server_name}` - 单个服务器WebSocket流
- `WS /ws-all` - 所有服务器WebSocket流

## 前端界面

主界面包含：

1. **概览面板**: 显示所有服务器的关键指标
2. **详细面板**: 每个服务器的详细监控信息
3. **实时更新**: 数据每秒自动更新

## 安全注意事项

- 使用SSH密钥认证而非密码
- 在生产环境中使用HTTPS
- 限制对监控系统的访问权限
- 定期更新依赖包

## 性能优化

- 批量执行命令减少网络延迟
- 使用连接池管理SSH连接
- 前端数据虚拟化处理大量监控项
- 可配置的刷新频率平衡实时性和性能

## 扩展性

系统设计为模块化架构，易于扩展：

- 新增监控项只需添加相应的命令执行和解析逻辑
- 支持插件化添加新的数据源
- API设计便于与其他系统集成

## 故障排除

### 连接问题

1. 确认SSH密钥路径正确
2. 确认远程服务器SSH服务正常运行
3. 检查防火墙设置

### 权限问题

1. 确认监控用户有执行相应命令的权限
2. 检查SSH密钥权限（通常应为600）

### 前端显示问题

1. 检查浏览器控制台是否有错误
2. 确认WebSocket连接正常

## 许可证

MIT License