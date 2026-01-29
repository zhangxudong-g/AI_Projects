# Remote Server Monitor - 文档和使用说明

## 目录
1. [概述](#概述)
2. [功能特性](#功能特性)
3. [技术架构](#技术架构)
4. [安装与部署](#安装与部署)
5. [配置说明](#配置说明)
6. [使用指南](#使用指南)
7. [API参考](#api参考)
8. [故障排除](#故障排除)
9. [常见问题](#常见问题)

## 概述

Remote Server Monitor 是一个功能强大的远程服务器监控系统，专为监控运行Ollama模型的服务器而设计。该系统提供实时监控、告警通知、数据可视化等功能，帮助用户全面掌握服务器运行状态。

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
- **Webhook通知**: 支持通过HTTP请求发送告警通知
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

## 技术架构

Remote Server Monitor 采用现代化的技术栈构建：

- **后端**: FastAPI (Python) - 提供高性能的API服务
- **前端**: HTML/CSS/JavaScript (Bootstrap) - 提供直观的用户界面
- **协议**: WebSocket - 实现实时数据推送
- **数据传输**: JSON - 标准化的数据交换格式
- **数据存储**: SQLite (可扩展至其他数据库) - 存储监控数据
- **SSH客户端**: AsyncSSH - 异步SSH连接管理
- **数据可视化**: Chart.js - 提供图表可视化功能
- **数据压缩**: gzip/zlib - 优化数据传输效率
- **缓存系统**: LRU缓存 - 提高数据访问速度

## 安装与部署

### 系统要求

- Python 3.8+
- Linux/Unix系统（推荐Ubuntu 20.04+或CentOS 8+）
- SSH访问权限到目标服务器
- 网络连接（用于下载依赖）

### 安装步骤

1. **克隆项目**
   ```bash
   git clone https://github.com/your-repo/remote-server-monitor.git
   cd remote-server-monitor
   ```

2. **创建虚拟环境**
   ```bash
   python -m venv venv
   source venv/bin/activate  # Linux/Mac
   # 或
   venv\Scripts\activate  # Windows
   ```

3. **安装依赖**
   ```bash
   pip install -r requirements.txt
   ```

4. **配置服务器信息**
   编辑 `config.yaml` 文件，添加要监控的服务器信息

5. **启动服务**
   ```bash
   python main.py
   ```

6. **访问Web界面**
   打开浏览器访问 `http://localhost:9000`

### Docker部署（可选）

```bash
# 构建镜像
docker build -t remote-server-monitor .

# 运行容器
docker run -d -p 9000:9000 -v ./config.yaml:/app/config.yaml remote-server-monitor
```

## 配置说明

### 主配置文件 (config.yaml)

```yaml
servers:
  - name: "Production Server"
    host: "192.168.1.100"
    port: 22
    username: "monitor_user"
    ssh_key_path: "/path/to/private/key"  # 或使用密码认证
    # password: "your_password"

monitoring:
  refresh_interval: 1.0  # 监控刷新间隔（秒）
  gpu_refresh_interval: 0.5  # GPU监控刷新间隔（秒）
  enable_compression: true  # 启用数据压缩
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

### SSH密钥配置

为了安全地访问远程服务器，建议使用SSH密钥认证：

1. **生成SSH密钥对**
   ```bash
   ssh-keygen -t rsa -b 4096 -C "monitor@yourdomain.com"
   ```

2. **将公钥复制到远程服务器**
   ```bash
   ssh-copy-id -i ~/.ssh/monitor_key.pub user@remote_server
   ```

3. **在配置文件中指定私钥路径**
   ```yaml
   ssh_key_path: "~/.ssh/monitor_key"
   ```

## 使用指南

### 1. 启动监控系统

首次启动时，系统会根据配置文件连接到所有指定的服务器：

```bash
python main.py
```

### 2. 访问Web界面

打开浏览器访问 `http://<server_ip>:9000`，您将看到实时监控仪表板。

### 3. 配置告警规则

通过API或管理界面配置告警规则：

```bash
curl -X POST http://localhost:9000/api/alerts/rules \
  -H "Content-Type: application/json" \
  -d '{
    "name": "High CPU Usage",
    "alert_type": "cpu_usage",
    "threshold_value": 80.0,
    "severity": "high",
    "enabled": true,
    "description": "CPU usage exceeds 80%"
  }'
```

### 4. 查看历史数据

通过API端点获取历史监控数据：

```bash
curl "http://localhost:9000/api/history/server1?hours=24"
```

### 5. 管理插件

通过插件系统扩展监控功能：

```bash
# 获取已安装的插件
curl http://localhost:9000/api/plugins/list

# 重新加载插件
curl -X POST http://localhost:9000/api/plugins/reload
```

### 6. 配置邮件通知

通过API配置邮件通知：

```bash
curl -X POST http://localhost:9000/api/email/config \
  -H "Content-Type: application/json" \
  -d '{
    "smtp_server": "smtp.gmail.com",
    "smtp_port": 587,
    "username": "your_email@gmail.com",
    "password": "your_app_password",
    "sender_email": "your_email@gmail.com",
    "recipient_emails": ["admin@example.com"],
    "enabled": true
  }'
```

## API参考

### 服务器监控API

#### 获取所有服务器数据
- **GET** `/api/servers`
- 返回所有服务器的基本信息

#### 获取单个服务器数据
- **GET** `/api/server/{server_name}`
- 返回指定服务器的详细监控数据

#### 获取所有服务器数据
- **GET** `/api/all-servers`
- 返回所有服务器的完整监控数据

### 历史数据API

#### 获取服务器历史数据
- **GET** `/api/history/{server_name}`
- 参数: `start_time`, `end_time`, `limit`
- 返回指定时间段内的历史数据

#### 获取所有服务器历史数据
- **GET** `/api/history-all`
- 参数: `start_time`, `end_time`, `limit`

### 告警系统API

#### 获取活跃告警
- **GET** `/api/alerts/active`

#### 获取告警历史
- **GET** `/api/alerts/history`
- 参数: `limit`

#### 添加告警规则
- **POST** `/api/alerts/rules`
- 请求体: 告警规则配置

#### 删除告警规则
- **DELETE** `/api/alerts/rules/{rule_name}`

#### 确认告警
- **POST** `/api/alerts/{alert_id}/acknowledge`

### 通知系统API

#### 获取邮件配置
- **GET** `/api/email/config`

#### 更新邮件配置
- **POST** `/api/email/config`
- 请求体: 邮件配置

#### 测试邮件配置
- **POST** `/api/email/test`

### 插件系统API

#### 获取插件列表
- **GET** `/api/plugins/list`

#### 重新加载插件
- **POST** `/api/plugins/reload`

### WebSocket端点

#### 单个服务器实时数据
- **WS** `/ws/{server_name}`
- 实时推送指定服务器的监控数据

#### 所有服务器实时数据
- **WS** `/ws-all`
- 实时推送所有服务器的监控数据

## 故障排除

### 常见问题及解决方案

#### 1. SSH连接失败
**症状**: 无法连接到远程服务器
**解决方案**:
- 检查SSH密钥路径是否正确
- 确认远程服务器SSH服务是否运行
- 验证用户名和认证信息
- 检查防火墙设置

#### 2. GPU监控数据为空
**症状**: GPU信息显示为空或N/A
**解决方案**:
- 确认目标服务器安装了nvidia-smi工具
- 检查用户是否有执行nvidia-smi的权限
- 验证GPU驱动是否正确安装

#### 3. Ollama模型信息不显示
**症状**: Ollama模型列表为空
**解决方案**:
- 确认Ollama服务正在运行
- 检查Ollama API端点配置
- 验证用户是否有访问Ollama服务的权限

#### 4. 告警通知未发送
**症状**: 告警触发但通知未发送
**解决方案**:
- 检查告警规则配置
- 验证邮件/Webhook配置
- 确认通知功能已启用

#### 5. Web界面加载缓慢
**症状**: 页面响应时间长
**解决方案**:
- 检查网络连接
- 验证服务器性能
- 调整监控刷新间隔

### 日志查看

系统日志可以帮助诊断问题：

```bash
# 查看应用日志
tail -f logs/app.log

# 查看错误日志
tail -f logs/error.log
```

### 性能调优

#### 优化监控频率
- 根据服务器性能调整 `refresh_interval`
- 对于高负载服务器，增加刷新间隔
- 考虑启用数据压缩以减少网络传输

#### 数据库性能
- 定期清理历史数据
- 使用索引优化查询性能
- 考虑使用更强大的数据库系统

## 常见问题

### 1. 如何添加新的监控服务器？

编辑 `config.yaml` 文件，在 `servers` 数组中添加新的服务器配置：

```yaml
servers:
  - name: "New Server"
    host: "192.168.1.200"
    port: 22
    username: "user"
    ssh_key_path: "/path/to/key"
```

重启服务后即可监控新服务器。

### 2. 如何自定义告警阈值？

通过API端点添加或修改告警规则：

```bash
curl -X POST http://localhost:9000/api/alerts/rules \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Custom Memory Alert",
    "alert_type": "memory_usage",
    "threshold_value": 90.0,
    "severity": "critical",
    "enabled": true,
    "description": "Memory usage exceeds 90%"
  }'
```

### 3. 如何扩展监控功能？

使用插件系统扩展监控功能：

1. 创建插件文件，继承 `MonitorPlugin` 类
2. 实现 `collect_additional_metrics` 方法
3. 将插件文件放置在 `plugins/` 目录下
4. 重启服务以加载新插件

### 4. 如何备份监控数据？

监控数据存储在SQLite数据库中，可以通过复制数据库文件进行备份：

```bash
cp monitoring.db backup_monitoring_$(date +%Y%m%d_%H%M%S).db
```

### 5. 如何升级系统？

1. 备份配置文件和数据库
2. 下载新版本代码
3. 安装新的依赖包
4. 恢复配置文件
5. 启动服务

## 联系支持

如需技术支持，请联系：
- 邮箱: support@yourcompany.com
- GitHub Issues: [链接到GitHub Issues页面]

---

感谢您使用 Remote Server Monitor！