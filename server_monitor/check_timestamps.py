import sqlite3
import json
from datetime import datetime

# 连接到数据库
conn = sqlite3.connect('D:/AI_Projects/server_monitor/monitoring.db')
cursor = conn.cursor()

# 检查时间戳的实际值
cursor.execute("""
    SELECT timestamp, datetime(timestamp, 'unixepoch') as readable_time
    FROM server_metrics
    ORDER BY timestamp DESC
    LIMIT 5
""")
timestamps = cursor.fetchall()
print("Timestamp analysis:")
for ts in timestamps:
    print(f"  Raw timestamp: {ts[0]} -> Readable time: {ts[1]}")

print()

# 检查最新的GPU数据
cursor.execute("""
    SELECT sm.timestamp, datetime(sm.timestamp, 'unixepoch') as readable_time, s.name, sm.gpu_utilization, sm.gpu_memory_used, sm.gpu_memory_total, sm.gpu_temperature
    FROM server_metrics sm
    JOIN servers s ON sm.server_id = s.id
    WHERE sm.gpu_utilization IS NOT NULL
    ORDER BY sm.timestamp DESC
    LIMIT 10
""")
samples = cursor.fetchall()
print("Latest GPU records with corrected timestamps:")
for sample in samples:
    print(f"  {sample[1]} - Server: {sample[2]}, GPU Util: {sample[3]}%, Mem: {sample[4]}/{sample[5]}MB, Temp: {sample[6]}°C")

# 关闭连接
conn.close()