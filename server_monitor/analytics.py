from db import get_server_metrics
from datetime import datetime, timedelta
import statistics
from typing import Dict, List, Any

def analyze_cpu_trend(session, server_name: str, hours: int = 24) -> Dict[str, Any]:
    """分析CPU使用率趋势"""
    start_time = datetime.utcnow() - timedelta(hours=hours)
    metrics = get_server_metrics(session, server_name, start_time=start_time, limit=1000)
    
    if not metrics:
        return {"error": "No data available"}
    
    cpu_values = [m['cpu_percent'] for m in metrics if m['cpu_percent'] is not None]
    
    if not cpu_values:
        return {"error": "No CPU data available"}
    
    analysis = {
        "average": round(statistics.mean(cpu_values), 2),
        "min": min(cpu_values),
        "max": max(cpu_values),
        "current": cpu_values[0],  # 最新值
        "trend": "increasing" if len(cpu_values) > 1 and cpu_values[0] > cpu_values[1] else "decreasing",
        "data_points": len(cpu_values)
    }
    
    return analysis

def analyze_memory_trend(session, server_name: str, hours: int = 24) -> Dict[str, Any]:
    """分析内存使用率趋势"""
    start_time = datetime.utcnow() - timedelta(hours=hours)
    metrics = get_server_metrics(session, server_name, start_time=start_time, limit=1000)
    
    if not metrics:
        return {"error": "No data available"}
    
    memory_values = [m['memory_used'] for m in metrics if m['memory_used'] is not None]
    
    if not memory_values:
        return {"error": "No memory data available"}
    
    analysis = {
        "average": round(statistics.mean(memory_values), 2),
        "min": min(memory_values),
        "max": max(memory_values),
        "current": memory_values[0],  # 最新值
        "trend": "increasing" if len(memory_values) > 1 and memory_values[0] > memory_values[1] else "decreasing",
        "data_points": len(memory_values)
    }
    
    return analysis

def analyze_gpu_trend(session, server_name: str, hours: int = 24) -> Dict[str, Any]:
    """分析GPU使用率趋势"""
    start_time = datetime.utcnow() - timedelta(hours=hours)
    metrics = get_server_metrics(session, server_name, start_time=start_time, limit=1000)
    
    if not metrics:
        return {"error": "No data available"}
    
    gpu_values = [m['gpu_utilization'] for m in metrics if m['gpu_utilization'] is not None]
    
    if not gpu_values:
        return {"error": "No GPU data available"}
    
    analysis = {
        "average": round(statistics.mean(gpu_values), 2),
        "min": min(gpu_values),
        "max": max(gpu_values),
        "current": gpu_values[0],  # 最新值
        "trend": "increasing" if len(gpu_values) > 1 and gpu_values[0] > gpu_values[1] else "decreasing",
        "data_points": len(gpu_values)
    }
    
    return analysis

def analyze_disk_trend(session, server_name: str, hours: int = 24) -> Dict[str, Any]:
    """分析磁盘使用率趋势"""
    start_time = datetime.utcnow() - timedelta(hours=hours)
    metrics = get_server_metrics(session, server_name, start_time=start_time, limit=1000)
    
    if not metrics:
        return {"error": "No data available"}
    
    # 从磁盘信息中提取使用率
    disk_usage_values = []
    for m in metrics:
        if m['disk_info']:
            # 计算所有磁盘分区的平均使用率
            total_usage = 0
            count = 0
            for disk in m['disk_info']:
                if 'percent' in disk:
                    total_usage += disk['percent']
                    count += 1
            if count > 0:
                avg_usage = total_usage / count
                disk_usage_values.append(avg_usage)
    
    if not disk_usage_values:
        return {"error": "No disk data available"}
    
    analysis = {
        "average": round(statistics.mean(disk_usage_values), 2),
        "min": min(disk_usage_values),
        "max": max(disk_usage_values),
        "current": disk_usage_values[0],  # 最新值
        "trend": "increasing" if len(disk_usage_values) > 1 and disk_usage_values[0] > disk_usage_values[1] else "decreasing",
        "data_points": len(disk_usage_values)
    }
    
    return analysis

def analyze_temperature_trend(session, server_name: str, hours: int = 24) -> Dict[str, Any]:
    """分析温度趋势"""
    start_time = datetime.utcnow() - timedelta(hours=hours)
    metrics = get_server_metrics(session, server_name, start_time=start_time, limit=1000)
    
    if not metrics:
        return {"error": "No data available"}
    
    # 从硬件温度信息中提取温度值
    temp_values = []
    for m in metrics:
        if m['hardware_temp_info']:
            # 计算所有传感器的平均温度
            total_temp = 0
            count = 0
            for temp_info in m['hardware_temp_info']:
                if 'temperature' in temp_info:
                    total_temp += temp_info['temperature']
                    count += 1
            if count > 0:
                avg_temp = total_temp / count
                temp_values.append(avg_temp)
    
    if not temp_values:
        return {"error": "No temperature data available"}
    
    analysis = {
        "average": round(statistics.mean(temp_values), 2),
        "min": min(temp_values),
        "max": max(temp_values),
        "current": temp_values[0],  # 最新值
        "trend": "increasing" if len(temp_values) > 1 and temp_values[0] > temp_values[1] else "decreasing",
        "data_points": len(temp_values)
    }
    
    return analysis

def get_comprehensive_analysis(session, server_name: str, hours: int = 24) -> Dict[str, Any]:
    """获取综合分析报告"""
    analysis = {
        "server_name": server_name,
        "analysis_period_hours": hours,
        "timestamp": datetime.utcnow().isoformat(),
        "cpu_analysis": analyze_cpu_trend(session, server_name, hours),
        "memory_analysis": analyze_memory_trend(session, server_name, hours),
        "gpu_analysis": analyze_gpu_trend(session, server_name, hours),
        "disk_analysis": analyze_disk_trend(session, server_name, hours),
        "temperature_analysis": analyze_temperature_trend(session, server_name, hours)
    }
    
    return analysis

def get_visualization_data(session, server_name: str, hours: int = 24) -> Dict[str, Any]:
    """获取用于可视化的数据"""
    start_time = datetime.utcnow() - timedelta(hours=hours)
    metrics = get_server_metrics(session, server_name, start_time=start_time, limit=500)  # 限制数据点数量以提高性能
    
    if not metrics:
        return {"error": "No data available"}
    
    # 按时间排序（从旧到新）
    metrics.sort(key=lambda x: x['timestamp'])
    
    visualization_data = {
        "timestamps": [m['timestamp'] for m in metrics],
        "cpu_data": [m['cpu_percent'] if m['cpu_percent'] is not None else 0 for m in metrics],
        "memory_data": [m['memory_used'] if m['memory_used'] is not None else 0 for m in metrics],
        "gpu_data": [m['gpu_utilization'] if m['gpu_utilization'] is not None else 0 for m in metrics],
        "disk_data": [],
        "temperature_data": []
    }
    
    # 处理磁盘数据 - 计算平均使用率
    for m in metrics:
        if m['disk_info']:
            total_usage = 0
            count = 0
            for disk in m['disk_info']:
                if 'percent' in disk:
                    total_usage += disk['percent']
                    count += 1
            if count > 0:
                avg_usage = total_usage / count
                visualization_data['disk_data'].append(avg_usage)
            else:
                visualization_data['disk_data'].append(0)
        else:
            visualization_data['disk_data'].append(0)
    
    # 处理温度数据 - 计算平均温度
    for m in metrics:
        if m['hardware_temp_info']:
            total_temp = 0
            count = 0
            for temp_info in m['hardware_temp_info']:
                if 'temperature' in temp_info:
                    total_temp += temp_info['temperature']
                    count += 1
            if count > 0:
                avg_temp = total_temp / count
                visualization_data['temperature_data'].append(avg_temp)
            else:
                visualization_data['temperature_data'].append(0)
        else:
            visualization_data['temperature_data'].append(0)
    
    return visualization_data