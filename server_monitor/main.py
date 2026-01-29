import asyncio
import json
from fastapi import FastAPI, WebSocket, Request
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict
from config import config
from ssh_client import ssh_pool
from monitor import MultiServerMonitor
from db import get_server_metrics
from analytics import get_comprehensive_analysis, get_visualization_data
from alerts import alert_manager, AlertRule, AlertSeverity, AlertType
from notifications import email_notifier, webhook_notifier, setup_email_notifier_from_config, setup_webhook_notifier_from_config
from auth import authenticate_user, create_access_token, User, Token
from fastapi import Depends
from datetime import timedelta
from fastapi import status
import logging
import jwt
from compression import compressor
from cache import cache_manager
from api_extensions import router as api_extensions_router
from plugins import plugin_manager
import subprocess
import shlex

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Remote Server Monitor", version="1.0.0")

# 添加CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 在生产环境中应限制为特定域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 包含API扩展路由
app.include_router(api_extensions_router)

# 挂载静态文件
app.mount("/static", StaticFiles(directory="static"), name="static")

# 设置模板目录
templates = Jinja2Templates(directory="templates")

# 初始化监控器
monitor = None

@app.on_event("startup")
async def startup_event():
    global monitor
    logger.info("Initializing SSH connections...")
    await ssh_pool.initialize_connections(config.servers)
    monitor = MultiServerMonitor(ssh_pool)
    logger.info("SSH connections initialized")

    # 初始化缓存管理器
    await cache_manager.start_cleanup_task()
    logger.info("Cache manager initialized")

    # 初始化插件系统
    plugin_manager.load_plugins()
    plugin_manager.initialize_plugins()
    logger.info("Plugin system initialized")


@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Closing SSH connections...")
    await ssh_pool.close_all_connections()
    logger.info("SSH connections closed")


@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    """渲染主页面"""
    return templates.TemplateResponse("index.html", {"request": request})



@app.websocket("/ws/{server_name}")
async def websocket_endpoint(websocket: WebSocket, server_name: str):
    """WebSocket端点，用于实时推送服务器监控数据"""
    await websocket.accept()

    # 检查服务器是否存在
    if server_name not in monitor.collectors:
        await websocket.send_text(json.dumps({"error": f"Server {server_name} not found"}))
        await websocket.close()
        return

    try:
        while True:
            # 定期发送监控数据
            data = await monitor.collect_from_server(server_name)

            # 检查是否启用压缩
            if hasattr(config.monitoring, 'enable_compression') and config.monitoring.enable_compression:
                # 使用压缩发送数据
                compressed_data, method, ratio = compressor.compress_with_best_method(data)
                logger.debug(f"Compression ratio for {server_name}: {ratio:.2%} using {method}")

                # 发送压缩标记和数据
                await websocket.send_bytes(compressed_data)
            else:
                # 不压缩，直接发送JSON
                await websocket.send_text(json.dumps(data, ensure_ascii=False))

            # 等待配置的刷新间隔
            await asyncio.sleep(config.monitoring.refresh_interval)
    except Exception as e:
        logger.error(f"WebSocket error for {server_name}: {e}")
    finally:
        await websocket.close()


@app.websocket("/ws-all")
async def websocket_all_endpoint(websocket: WebSocket):
    """WebSocket端点，用于实时推送所有服务器的监控数据"""
    await websocket.accept()

    try:
        while True:
            # 收集所有服务器的数据
            data = await monitor.collect_from_all_servers()

            # 检查是否启用压缩
            if hasattr(config.monitoring, 'enable_compression') and config.monitoring.enable_compression:
                # 使用压缩发送数据
                compressed_data, method, ratio = compressor.compress_with_best_method(data)
                logger.debug(f"Compression ratio for all servers: {ratio:.2%} using {method}")

                # 发送压缩标记和数据
                await websocket.send_bytes(compressed_data)
            else:
                # 不压缩，直接发送JSON
                await websocket.send_text(json.dumps(data, ensure_ascii=False))

            # 等待配置的刷新间隔
            await asyncio.sleep(config.monitoring.refresh_interval)
    except Exception as e:
        logger.error(f"WebSocket error for all servers: {e}")
    finally:
        await websocket.close()


@app.get("/api/servers")
async def get_servers():
    """获取服务器列表（包含主机信息）"""
    server_list = []
    for server in config.servers:
        server_list.append({
            "name": server.name,
            "host": server.host
        })
    return {"servers": server_list}


@app.get("/api/server/{server_name}")
async def get_server_data(server_name: str):
    """获取单个服务器的当前数据"""
    if monitor is None:
        return {"error": "Monitor not initialized"}

    # 使用缓存版本的方法
    return await monitor.collect_from_server_cached(server_name)


@app.get("/api/all-servers")
async def get_all_servers_data():
    """获取所有服务器的当前数据"""
    if monitor is None:
        return {"error": "Monitor not initialized"}

    # 使用缓存版本的方法
    return await monitor.collect_from_all_servers_cached()


# 添加一个健康检查端点
@app.get("/health")
async def health_check():
    return {"status": "healthy", "message": "Server monitor is running"}


# 历史数据API端点
@app.get("/api/history/{server_name}")
async def get_history_data(server_name: str, start_time: str = None, end_time: str = None, limit: int = 100):
    """获取服务器的历史监控数据"""
    try:
        from datetime import datetime
        start_dt = datetime.fromisoformat(start_time) if start_time else None
        end_dt = datetime.fromisoformat(end_time) if end_time else None

        # 生成缓存键
        cache_key = f"{server_name}:{start_time}:{end_time}:{limit}"

        # 尝试从缓存获取数据
        cached_data = cache_manager.get_history_data(server_name, start_time or "", end_time or "", limit)
        if cached_data is not None:
            logger.debug(f"Cache hit for history data: {cache_key}")
            return cached_data

        session = monitor.Session()
        history_data = get_server_metrics(session, server_name, start_dt, end_dt, limit)
        session.close()

        # 将结果存入缓存
        result = {"server_name": server_name, "history": history_data}
        cache_manager.set_history_data(server_name, start_time or "", end_time or "", limit, result)

        return result
    except Exception as e:
        return {"error": str(e)}


@app.get("/api/history-all")
async def get_all_history_data(start_time: str = None, end_time: str = None, limit: int = 100):
    """获取所有服务器的历史监控数据"""
    try:
        from datetime import datetime
        start_dt = datetime.fromisoformat(start_time) if start_time else None
        end_dt = datetime.fromisoformat(end_time) if end_time else None

        all_history = {}
        for server_name in config.servers:
            session = monitor.Session()
            history_data = get_server_metrics(session, server_name.name, start_dt, end_dt, limit)
            session.close()
            all_history[server_name.name] = history_data

        return {"history": all_history}
    except Exception as e:
        return {"error": str(e)}


# 数据分析API端点
@app.get("/api/analysis/{server_name}")
async def get_analysis_data(server_name: str, hours: int = 24):
    """获取服务器的历史数据分析"""
    try:
        # 尝试从缓存获取数据
        cached_data = cache_manager.get_analysis_data(server_name, hours)
        if cached_data is not None:
            logger.debug(f"Cache hit for analysis data: {server_name}:{hours}")
            return cached_data

        session = monitor.Session()
        analysis = get_comprehensive_analysis(session, server_name, hours)
        session.close()

        # 将结果存入缓存
        cache_manager.set_analysis_data(server_name, hours, analysis)

        return analysis
    except Exception as e:
        return {"error": str(e)}


@app.get("/api/visualization/{server_name}")
async def get_visualization_data_api(server_name: str, hours: int = 24):
    """获取用于可视化的数据"""
    try:
        # 尝从缓存获取数据
        cached_data = cache_manager.get_analysis_data(server_name, hours)  # 重用分析数据的缓存
        if cached_data is not None:
            logger.debug(f"Cache hit for visualization data: {server_name}:{hours}")
            return cached_data

        session = monitor.Session()
        vis_data = get_visualization_data(session, server_name, hours)
        session.close()

        # 将结果存入缓存
        cache_manager.set_analysis_data(server_name, hours, vis_data)  # 重用分析数据的缓存

        return vis_data
    except Exception as e:
        return {"error": str(e)}


# 告警系统API端点
@app.get("/api/alerts/active")
async def get_active_alerts():
    """获取所有活跃告警"""
    active_alerts = alert_manager.get_active_alerts()
    return {"active_alerts": [alert.__dict__ for alert in active_alerts]}


@app.get("/api/alerts/history")
async def get_alert_history(limit: int = 100):
    """获取告警历史"""
    history = alert_manager.get_alert_history(limit)
    return {"history": [alert.__dict__ for alert in history]}


@app.post("/api/alerts/rules")
async def add_alert_rule(request: dict):
    """添加告警规则"""
    try:
        rule = AlertRule(
            name=request["name"],
            alert_type=AlertType(request["alert_type"]),
            threshold_value=float(request["threshold_value"]),
            severity=AlertSeverity(request["severity"]),
            enabled=request.get("enabled", True),
            description=request.get("description", "")
        )
        alert_manager.add_rule(rule)
        return {"message": "Alert rule added successfully", "rule": rule.__dict__}
    except Exception as e:
        return {"error": str(e)}


@app.delete("/api/alerts/rules/{rule_name}")
async def remove_alert_rule(rule_name: str):
    """删除告警规则"""
    try:
        alert_manager.remove_rule(rule_name)
        return {"message": f"Alert rule '{rule_name}' removed successfully"}
    except Exception as e:
        return {"error": str(e)}


@app.get("/api/alerts/rules")
async def get_alert_rules():
    """获取所有告警规则"""
    rules = [{"name": rule.name, "alert_type": rule.alert_type.value, "threshold_value": rule.threshold_value,
              "severity": rule.severity.value, "enabled": rule.enabled, "description": rule.description}
             for rule in alert_manager.rules]
    return {"rules": rules}


@app.post("/api/alerts/{alert_id}/acknowledge")
async def acknowledge_alert(alert_id: str, user: str = "system"):
    """确认告警"""
    try:
        success = alert_manager.acknowledge_alert(alert_id, user)
        if success:
            return {"message": f"Alert {alert_id} acknowledged successfully"}
        else:
            return {"error": f"Alert {alert_id} not found"}
    except Exception as e:
        return {"error": str(e)}


# 邮件通知配置API端点
@app.get("/api/email/config")
async def get_email_config():
    """获取邮件配置"""
    email_cfg = config.monitoring.email_notifications
    return {
        "smtp_server": email_cfg.smtp_server,
        "smtp_port": email_cfg.smtp_port,
        "username": email_cfg.username,
        "sender_email": email_cfg.sender_email,
        "recipient_emails": email_cfg.recipient_emails,
        "enabled": email_cfg.enabled,
        "use_tls": email_cfg.use_tls
    }


@app.post("/api/email/config")
async def update_email_config(request: dict):
    """更新邮件配置"""
    try:
        # 更新配置对象
        email_cfg = config.monitoring.email_notifications
        email_cfg.smtp_server = request.get("smtp_server", email_cfg.smtp_server)
        email_cfg.smtp_port = request.get("smtp_port", email_cfg.smtp_port)
        email_cfg.username = request.get("username", email_cfg.username)
        email_cfg.password = request.get("password", email_cfg.password)
        email_cfg.sender_email = request.get("sender_email", email_cfg.sender_email)
        email_cfg.recipient_emails = request.get("recipient_emails", email_cfg.recipient_emails)
        email_cfg.enabled = request.get("enabled", email_cfg.enabled)
        email_cfg.use_tls = request.get("use_tls", email_cfg.use_tls)

        # 重新配置邮件通知器
        setup_email_notifier_from_config()

        return {"message": "Email configuration updated successfully"}
    except Exception as e:
        return {"error": str(e)}


@app.post("/api/email/test")
async def test_email_config():
    """测试邮件配置"""
    try:
        success = email_notifier.test_connection()
        if success:
            return {"message": "Email configuration test successful"}
        else:
            return {"error": "Email configuration test failed"}
    except Exception as e:
        return {"error": f"Test failed: {str(e)}"}


# Webhook通知配置API端点
@app.get("/api/webhook/config")
async def get_webhook_config():
    """获取Webhook配置"""
    webhook_cfg = config.monitoring.webhook_notifications
    return {
        "url": webhook_cfg.url,
        "headers": webhook_cfg.headers,
        "enabled": webhook_cfg.enabled,
        "timeout": webhook_cfg.timeout
    }


@app.post("/api/webhook/config")
async def update_webhook_config(request: dict):
    """更新Webhook配置"""
    try:
        # 更新配置对象
        webhook_cfg = config.monitoring.webhook_notifications
        webhook_cfg.url = request.get("url", webhook_cfg.url)
        webhook_cfg.headers = request.get("headers", webhook_cfg.headers)
        webhook_cfg.enabled = request.get("enabled", webhook_cfg.enabled)
        webhook_cfg.timeout = request.get("timeout", webhook_cfg.timeout)

        # 重新配置Webhook通知器
        setup_webhook_notifier_from_config()

        return {"message": "Webhook configuration updated successfully"}
    except Exception as e:
        return {"error": str(e)}


@app.post("/api/webhook/test")
async def test_webhook_config():
    """测试Webhook配置"""
    try:
        from alerts import Alert, AlertType, AlertSeverity
        from datetime import datetime

        # 创建一个模拟告警用于测试
        test_alert = Alert(
            id="test_alert",
            server_name="test_server",
            alert_type=AlertType.CPU_USAGE,
            message="Test alert for webhook configuration",
            severity=AlertSeverity.LOW,
            current_value=50.0,
            threshold_value=80.0,
            timestamp=datetime.utcnow()
        )

        success = await webhook_notifier.send_alert_webhook(test_alert)
        if success:
            return {"message": "Webhook configuration test successful"}
        else:
            return {"error": "Webhook configuration test failed"}
    except Exception as e:
        return {"error": f"Test failed: {str(e)}"}


@app.get("/api/docker/containers/{server_name}")
async def get_docker_containers(server_name: str):
    """获取指定服务器上的Docker容器信息"""
    try:
        client = ssh_pool.get_client(server_name)
        if not client:
            return {"error": f"Server {server_name} not found or not connected"}

        # 执行docker ps命令获取正在运行的容器，使用sudo
        success, stdout, stderr = await client.execute_command("docker ps --format \"{{.ID}}\\t{{.Names}}\\t{{.Status}}\\t{{.Ports}}\"", use_sudo=True)

        if not success:
            return {"error": f"Failed to execute docker ps: {stderr}"}

        # 解析输出
        containers = []
        if stdout.strip():
            lines = stdout.strip().split('\n')
            headers = ["ID", "Name", "Status", "Ports"]
            for line in lines:
                values = line.split('\t')
                if len(values) == len(headers):
                    container = dict(zip(headers, values))
                    containers.append(container)

        return {"containers": containers}
    except Exception as e:
        logger.error(f"Error getting Docker containers for {server_name}: {str(e)}")
        return {"error": str(e)}


@app.get("/api/docker/images/{server_name}")
async def get_docker_images(server_name: str):
    """获取指定服务器上的Docker镜像信息"""
    try:
        client = ssh_pool.get_client(server_name)
        if not client:
            return {"error": f"Server {server_name} not found or not connected"}

        # 执行docker images命令获取镜像列表，使用sudo
        success, stdout, stderr = await client.execute_command("docker images --format \"{{.Repository}}\\t{{.Tag}}\\t{{.ID}}\\t{{.Size}}\"", use_sudo=True)

        if not success:
            return {"error": f"Failed to execute docker images: {stderr}"}

        # 解析输出
        images = []
        if stdout.strip():
            lines = stdout.strip().split('\n')
            headers = ["Repository", "Tag", "ID", "Size"]
            for line in lines:
                values = line.split('\t')
                if len(values) == len(headers):
                    image = dict(zip(headers, values))
                    images.append(image)

        return {"images": images}
    except Exception as e:
        logger.error(f"Error getting Docker images for {server_name}: {str(e)}")
        return {"error": str(e)}


# Web CLI功能相关API端点
@app.websocket("/ws/cli/{server_name}")
async def websocket_cli_endpoint(websocket: WebSocket, server_name: str):
    """WebSocket端点，用于Web CLI功能"""
    await websocket.accept()

    # 检查服务器是否存在
    client = ssh_pool.get_client(server_name)
    if not client:
        await websocket.send_text(json.dumps({"error": f"Server {server_name} not found or not connected"}))
        await websocket.close()
        return

    try:
        while True:
            # 接收客户端发送的命令
            data = await websocket.receive_text()
            command_request = json.loads(data)
            command = command_request.get("command", "")
            use_sudo = command_request.get("use_sudo", False)

            # 执行命令并返回结果
            full_stdout = ""
            full_stderr = ""
            final_success = False

            async for success, stdout, stderr in client.execute_interactive_command(command, use_sudo):
                full_stdout = stdout  # 直接获取完整输出
                full_stderr = stderr
                final_success = success
                break  # 只处理第一次yield的结果

            # 发送完整的命令输出
            response = {
                "command": command,
                "success": final_success,
                "stdout": full_stdout,
                "stderr": full_stderr,
                "server": server_name
            }
            await websocket.send_text(json.dumps(response, ensure_ascii=False))

    except Exception as e:
        logger.error(f"WebSocket CLI error for {server_name}: {e}")
        error_response = {
            "error": str(e),
            "server": server_name
        }
        await websocket.send_text(json.dumps(error_response, ensure_ascii=False))
    finally:
        await websocket.close()


@app.get("/api/servers-for-cli")
async def get_servers_for_cli():
    """获取可用于CLI的服务器列表"""
    server_list = []
    for server in config.servers:
        server_list.append({
            "name": server.name,
            "host": server.host
        })
    return {"servers": server_list}


from fastapi.security import OAuth2PasswordRequestForm





# GPU历史峰值数据API端点
@app.get("/api/gpu-history-peaks/{server_name}")
async def get_gpu_history_peaks(server_name: str, hours: int = 24, min_utilization: int = 10):
    """
    获取GPU历史峰值数据
    :param server_name: 服务器名称
    :param hours: 查询时间范围（小时）
    :param min_utilization: 最小利用率阈值（百分比）
    """
    try:
        from datetime import datetime, timedelta
        from sqlalchemy import and_

        # 计算开始时间
        start_time = datetime.utcnow() - timedelta(hours=hours)

        # 获取数据库会话
        session = monitor.Session()

        # 查询GPU利用率大于阈值的历史数据
        from db import ServerMetrics
        peak_data = session.query(ServerMetrics).filter(
            and_(
                ServerMetrics.server_name == server_name,
                ServerMetrics.timestamp >= start_time,
                ServerMetrics.gpu_utilization is not None,
                ServerMetrics.gpu_utilization >= min_utilization
            )
        ).order_by(ServerMetrics.timestamp.desc()).all()

        # 转换数据格式
        result = []
        for record in peak_data:
            result.append({
                "timestamp": record.timestamp.isoformat(),
                "gpu_utilization": record.gpu_utilization,
                "gpu_memory_used": record.gpu_memory_used,
                "gpu_memory_total": record.gpu_memory_total,
                "gpu_temperature": record.gpu_temperature
            })

        session.close()

        return {
            "server_name": server_name,
            "time_range_hours": hours,
            "min_utilization_threshold": min_utilization,
            "peak_data": result
        }
    except Exception as e:
        logger.error(f"Error getting GPU history peaks for {server_name}: {str(e)}")
        return {"error": str(e)}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=9000)