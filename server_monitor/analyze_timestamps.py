import sqlite3
import json
from datetime import datetime, timedelta

# 连接到数据库
conn = sqlite3.connect('D:/AI_Projects/server_monitor/monitoring.db')
cursor = conn.cursor()

# 检查时间戳的原始值
cursor.execute("""
    SELECT timestamp
    FROM server_metrics
    ORDER BY timestamp DESC
    LIMIT 5
""")
raw_timestamps = cursor.fetchall()

print("Raw timestamp values from DB:")
for i, raw_ts in enumerate(raw_timestamps):
    ts_str = raw_ts[0]
    print(f"  Row {i+1}: '{ts_str}' (type: {type(ts_str)})")
    
    # 尝试不同的解析方法
    try:
        # 方法1: 直接作为datetime字符串解析
        dt1 = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
        print(f"    As ISO format: {dt1}")
    except:
        print(f"    As ISO format: Failed")
    
    # 方法2: 如果是数值形式的时间戳
    try:
        ts_float = float(ts_str)
        if ts_float > 1e10:  # 可能是毫秒时间戳
            dt2 = datetime.fromtimestamp(ts_float / 1000.0)
            print(f"    As ms timestamp: {dt2}")
        elif ts_float > 1e9:  # 可能是秒时间戳
            dt2 = datetime.fromtimestamp(ts_float)
            print(f"    As sec timestamp: {dt2}")
        else:
            print(f"    As timestamp: Too small ({ts_float})")
    except:
        print(f"    As timestamp: Failed")

print()

# 检查服务器名称和GPU数据
cursor.execute("""
    SELECT s.name as server_name, COUNT(*) as record_count,
           COUNT(CASE WHEN sm.gpu_utilization IS NOT NULL THEN 1 END) as gpu_records,
           MIN(sm.timestamp) as min_time, MAX(sm.timestamp) as max_time
    FROM server_metrics sm
    JOIN servers s ON sm.server_id = s.id
    GROUP BY s.name
""")
server_stats = cursor.fetchall()

print("Server statistics:")
for stat in server_stats:
    print(f"  Server: {stat[0]}")
    print(f"    Total records: {stat[1]}")
    print(f"    GPU records: {stat[2]}")
    print(f"    Time range: {stat[3]} to {stat[4]}")

conn.close()