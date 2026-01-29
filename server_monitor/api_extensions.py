from fastapi import APIRouter, HTTPException, Depends
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from pydantic import BaseModel
from auth import get_current_active_user, Permission, require_permission, User
from config import config
from monitor import MultiServerMonitor
from db import get_server_metrics, get_server_performance_summary
from alerts import alert_manager
from plugins import plugin_manager
from models import ApiStats
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

# 数据模型
class ServerPerformanceSummary(BaseModel):
    server_name: str
    cpu_avg: float
    memory_avg: float
    disk_avg: float
    gpu_avg: Optional[float] = None
    period_start: datetime
    period_end: datetime
    data_points: int

class SystemHealthStatus(BaseModel):
    service_status: str
    server_connectivity: Dict[str, bool]
    database_status: bool
    plugin_status: Dict[str, bool]
    last_update: datetime

# 扩展API端点
@router.get("/api/servers/summary", response_model=List[ServerPerformanceSummary])
@require_permission(Permission.VIEW_SERVERS)
async def get_all_servers_summary(
    hours: int = 24,
    current_user: User = Depends(get_current_active_user)
):
    """获取所有服务器的性能摘要"""
    try:
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=hours)

        summaries = []
        for server_config in config.servers:
            from db import create_database
            engine, Session = create_database()
            session = Session()
            summary = get_server_performance_summary(
                session,
                server_config.name,
                start_time,
                end_time
            )
            session.close()

            if summary:
                summaries.append(ServerPerformanceSummary(
                    server_name=summary['server_name'],
                    cpu_avg=summary['cpu_avg'],
                    memory_avg=summary['memory_avg'],
                    disk_avg=summary['disk_avg'],
                    gpu_avg=summary['gpu_avg'],
                    period_start=summary['period_start'],
                    period_end=summary['period_end'],
                    data_points=summary['data_points']
                ))

        return summaries
    except Exception as e:
        logger.error(f"Error getting server summaries: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/api/system/health")
async def get_system_health(current_user: User = Depends(get_current_active_user)):
    """获取系统健康状况"""
    try:
        # 检查服务器连接性
        server_connectivity = {}
        for server_config in config.servers:
            # 这里可以实现具体的连接性检查
            server_connectivity[server_config.name] = True  # 简化处理

        # 检查数据库状态
        db_status = True  # 简化处理

        # 检查插件状态
        plugin_status = {}
        for plugin in plugin_manager.get_enabled_plugins():
            plugin_status[plugin.__class__.__name__] = plugin.initialized

        health_status = SystemHealthStatus(
            service_status="operational",
            server_connectivity=server_connectivity,
            database_status=db_status,
            plugin_status=plugin_status,
            last_update=datetime.utcnow()
        )

        return health_status
    except Exception as e:
        logger.error(f"Error getting system health: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/api/plugins/list")
@require_permission(Permission.VIEW_PLUGINS)
async def get_installed_plugins(current_user: User = Depends(get_current_active_user)):
    """获取已安装的插件列表"""
    try:
        plugins_info = []
        for plugin in plugin_manager.get_enabled_plugins():
            plugins_info.append({
                "name": plugin.__class__.__name__,
                "initialized": plugin.initialized,
                "metadata": plugin.metadata.__dict__ if plugin.metadata else None
            })

        return {"plugins": plugins_info}
    except Exception as e:
        logger.error(f"Error getting plugins list: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/api/plugins/reload")
@require_permission(Permission.MANAGE_PLUGINS)
async def reload_plugins(current_user: User = Depends(get_current_active_user)):
    """重新加载插件"""
    try:
        plugin_manager.load_plugins()
        plugin_manager.initialize_plugins()
        return {"message": "Plugins reloaded successfully"}
    except Exception as e:
        logger.error(f"Error reloading plugins: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/api/alerts/severity-stats")
@require_permission(Permission.VIEW_ALERTS)
async def get_alert_severity_statistics(
    days: int = 7,
    current_user: User = Depends(get_current_active_user)
):
    """获取按严重程度分类的告警统计"""
    try:
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(days=days)

        # 获取告警历史
        alerts = alert_manager.get_alert_history(limit=10000)  # 限制数量

        # 过滤指定时间范围内的告警
        filtered_alerts = [
            alert for alert in alerts
            if start_time <= alert.timestamp <= end_time
        ]

        # 按严重程度统计
        severity_stats = {}
        for alert in filtered_alerts:
            severity = alert.severity.value
            if severity not in severity_stats:
                severity_stats[severity] = 0
            severity_stats[severity] += 1

        return {
            "period": {
                "start": start_time.isoformat(),
                "end": end_time.isoformat()
            },
            "severity_stats": severity_stats,
            "total_alerts": len(filtered_alerts)
        }
    except Exception as e:
        logger.error(f"Error getting alert severity stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/api/servers/resources-comparison")
@require_permission(Permission.VIEW_SERVERS)
async def get_servers_resources_comparison(current_user: User = Depends(get_current_active_user)):
    """获取服务器资源使用对比"""
    try:
        comparison_data = {}

        # 收集所有服务器的最新数据
        # 注意：这里需要一个有效的MultiServerMonitor实例
        # 由于我们无法在此处初始化SSH连接池，我们暂时返回空数据
        for server_config in config.servers:
            # data = await monitor.collect_from_server(server_config.name)
            # 临时返回示例数据
            comparison_data[server_config.name] = {
                'cpu_percent': 0.0,
                'memory_percent': 0.0,
                'disk_usage': [],
                'gpu_utilization': [],
                'timestamp': datetime.utcnow()
            }

        return {"comparison": comparison_data}
    except Exception as e:
        logger.error(f"Error getting server resources comparison: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/api/stats/api")
async def get_api_statistics(current_user: User = Depends(get_current_active_user)):
    """获取API统计信息（简化版）"""
    try:
        # 这里可以集成实际的API统计，比如使用中间件收集数据
        stats = ApiStats(
            total_requests=0,  # 实际实现中需要从统计系统获取
            active_connections=0,  # 实际实现中需要从连接池获取
            response_times={},  # 实际实现中需要从统计系统获取
            error_rates={}  # 实际实现中需要从统计系统获取
        )
        return stats
    except Exception as e:
        logger.error(f"Error getting API statistics: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 注册定时任务来收集API统计信息
async def collect_api_stats():
    """收集API统计信息的后台任务"""
    # 这里可以实现实际的统计收集逻辑
    pass