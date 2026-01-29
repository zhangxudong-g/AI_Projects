from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, Text, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime
import json

Base = declarative_base()

class Server(Base):
    __tablename__ = 'servers'

    id = Column(Integer, primary_key=True)
    name = Column(String(255), unique=True, nullable=False)
    host = Column(String(255), nullable=False)
    port = Column(Integer, default=22)
    username = Column(String(255), nullable=False)
    
    # 关系
    metrics = relationship("ServerMetrics", back_populates="server")

class ServerMetrics(Base):
    __tablename__ = 'server_metrics'

    id = Column(Integer, primary_key=True)
    server_id = Column(Integer, ForeignKey('servers.id'), nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    # CPU信息
    cpu_percent = Column(Float)
    
    # 内存信息
    memory_used = Column(Float)  # GB
    memory_total = Column(Float)  # GB
    
    # GPU信息
    gpu_utilization = Column(Integer)  # 百分比
    gpu_memory_used = Column(Integer)  # MB
    gpu_memory_total = Column(Integer)  # MB
    gpu_temperature = Column(Integer)  # 摄氏度
    
    # 磁盘信息 - 存储为JSON字符串
    disk_info = Column(Text)  # JSON格式存储多个磁盘分区信息
    
    # 网络信息 - 存储为JSON字符串
    network_info = Column(Text)  # JSON格式存储多个网络接口信息
    
    # 进程信息 - 存储为JSON字符串
    process_info = Column(Text)  # JSON格式存储多个进程信息
    
    # 硬件温度信息 - 存储为JSON字符串
    hardware_temp_info = Column(Text)  # JSON格式存储多个传感器信息
    
    # Ollama模型信息 - 存储为JSON字符串
    ollama_models = Column(Text)  # JSON格式存储多个模型信息
    
    # 自定义命令结果 - 存储为JSON字符串
    custom_command_results = Column(Text)  # JSON格式存储多个命令结果
    
    # 关系
    server = relationship("Server", back_populates="metrics")

def create_database(db_url="sqlite:///monitoring.db"):
    """创建数据库引擎和表"""
    engine = create_engine(db_url)
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    return engine, Session

def store_server_metrics(session, server_name, metrics_data):
    """存储服务器监控指标到数据库"""
    # 首先查找或创建服务器记录
    server = session.query(Server).filter(Server.name == server_name).first()
    if not server:
        # 从配置中获取服务器信息（这里简化处理，实际应用中需要从配置获取完整信息）
        server = Server(name=server_name, host="unknown", username="unknown")
        session.add(server)
        session.commit()
    
    # 创建指标记录
    metric_record = ServerMetrics(
        server_id=server.id,
        timestamp=datetime.fromtimestamp(metrics_data.get('timestamp', datetime.utcnow().timestamp())),
        cpu_percent=metrics_data.get('system_resources', {}).get('cpu_percent'),
        memory_used=metrics_data.get('system_resources', {}).get('memory_used'),
        memory_total=metrics_data.get('system_resources', {}).get('memory_total'),
        gpu_utilization=None,  # 从gpu_info中提取
        gpu_memory_used=None,  # 从gpu_info中提取
        gpu_memory_total=None,  # 从gpu_info中提取
        gpu_temperature=None,   # 从gpu_info中提取
        disk_info=json.dumps(metrics_data.get('system_resources', {}).get('disk_info', [])),
        network_info=json.dumps(metrics_data.get('system_resources', {}).get('network_info', [])),
        process_info=json.dumps(metrics_data.get('system_resources', {}).get('process_info', [])),
        hardware_temp_info=json.dumps(metrics_data.get('system_resources', {}).get('hardware_temp_info', [])),
        ollama_models=json.dumps(metrics_data.get('ollama_models', [])),
        custom_command_results=json.dumps(metrics_data.get('system_resources', {}).get('custom_command_results', []))
    )
    
    # 如果有GPU信息，提取相关信息
    gpu_info_list = metrics_data.get('gpu_info', [])
    if gpu_info_list:
        # 取第一个GPU的信息作为代表（实际应用中可能需要处理多个GPU）
        gpu_info = gpu_info_list[0]
        metric_record.gpu_utilization = gpu_info.get('utilization')
        if 'memory_info' in gpu_info:
            metric_record.gpu_memory_used = gpu_info['memory_info'].get('used')
            metric_record.gpu_memory_total = gpu_info['memory_info'].get('total')
        metric_record.gpu_temperature = gpu_info.get('temperature')
    
    session.add(metric_record)
    session.commit()

def get_server_metrics(session, server_name, start_time=None, end_time=None, limit=100):
    """获取服务器的历史监控指标"""
    query = session.query(ServerMetrics).join(Server).filter(Server.name == server_name)
    
    if start_time:
        query = query.filter(ServerMetrics.timestamp >= start_time)
    if end_time:
        query = query.filter(ServerMetrics.timestamp <= end_time)
    
    # 按时间倒序排列，获取最新的记录
    records = query.order_by(ServerMetrics.timestamp.desc()).limit(limit).all()
    
    # 转换为字典格式
    result = []
    for record in records:
        record_dict = {
            'id': record.id,
            'timestamp': record.timestamp.isoformat(),
            'cpu_percent': record.cpu_percent,
            'memory_used': record.memory_used,
            'memory_total': record.memory_total,
            'gpu_utilization': record.gpu_utilization,
            'gpu_memory_used': record.gpu_memory_used,
            'gpu_memory_total': record.gpu_memory_total,
            'gpu_temperature': record.gpu_temperature,
            'disk_info': json.loads(record.disk_info) if record.disk_info else [],
            'network_info': json.loads(record.network_info) if record.network_info else [],
            'process_info': json.loads(record.process_info) if record.process_info else [],
            'hardware_temp_info': json.loads(record.hardware_temp_info) if record.hardware_temp_info else [],
            'ollama_models': json.loads(record.ollama_models) if record.ollama_models else [],
            'custom_command_results': json.loads(record.custom_command_results) if record.custom_command_results else []
        }
        result.append(record_dict)
    
    return result


def get_server_performance_summary(session, server_name: str, start_time=None, end_time=None):
    """获取服务器性能摘要"""
    # 首先获取服务器ID
    server = session.query(Server).filter(Server.name == server_name).first()
    if not server:
        return None

    # 查询指标
    query = session.query(ServerMetrics).filter(ServerMetrics.server_id == server.id)

    if start_time:
        query = query.filter(ServerMetrics.timestamp >= start_time)
    if end_time:
        query = query.filter(ServerMetrics.timestamp <= end_time)

    # 获取所有匹配的指标
    metrics = query.order_by(ServerMetrics.timestamp.asc()).all()

    if not metrics:
        return None

    # 计算平均值
    cpu_sum = memory_sum = disk_sum = gpu_sum = 0
    cpu_count = memory_count = disk_count = gpu_count = 0

    for metric in metrics:
        if metric.cpu_percent is not None:
            cpu_sum += metric.cpu_percent
            cpu_count += 1

        if metric.memory_total and metric.memory_total > 0:
            memory_percent = (metric.memory_used / metric.memory_total) * 100
            memory_sum += memory_percent
            memory_count += 1

        if metric.disk_info:
            disk_data = json.loads(metric.disk_info) if isinstance(metric.disk_info, str) else metric.disk_info
            if disk_data:
                # 计算所有磁盘分区的平均使用率
                total_disk_usage = sum(float(d['percent']) for d in disk_data if 'percent' in d and 'percent' in d)
                disk_sum += total_disk_usage / len(disk_data) if len(disk_data) > 0 else 0
                disk_count += 1

        if metric.gpu_utilization is not None:
            gpu_sum += metric.gpu_utilization
            gpu_count += 1

    # 计算平均值
    cpu_avg = cpu_sum / cpu_count if cpu_count > 0 else 0
    memory_avg = memory_sum / memory_count if memory_count > 0 else 0
    disk_avg = disk_sum / disk_count if disk_count > 0 else 0
    gpu_avg = gpu_sum / gpu_count if gpu_count > 0 else None

    return {
        'server_name': server_name,
        'cpu_avg': round(cpu_avg, 2),
        'memory_avg': round(memory_avg, 2),
        'disk_avg': round(disk_avg, 2),
        'gpu_avg': round(gpu_avg, 2) if gpu_avg is not None else None,
        'period_start': start_time or metrics[0].timestamp if metrics else None,
        'period_end': end_time or metrics[-1].timestamp if metrics else None,
        'data_points': len(metrics)
    }