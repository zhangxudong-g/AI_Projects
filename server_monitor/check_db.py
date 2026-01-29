import sqlite3
import json
from datetime import datetime

# 连接到数据库
conn = sqlite3.connect('D:/AI_Projects/server_monitor/monitoring.db')
cursor = conn.cursor()

# 查询服务器信息
cursor.execute("SELECT id, name, host FROM servers")
servers = cursor.fetchall()
print("Servers in database:")
for server in servers:
    print(f"  ID: {server[0]}, Name: {server[1]}, Host: {server[2]}")

print()

# 查询是否有GPU数据
cursor.execute("""
    SELECT COUNT(*) as total_records,
           COUNT(CASE WHEN gpu_utilization IS NOT NULL THEN 1 END) as gpu_records,
           MIN(timestamp) as earliest_time,
           MAX(timestamp) as latest_time
    FROM server_metrics
""")
stats = cursor.fetchone()
print(f"Database stats:")
print(f"  Total records: {stats[0]}")
print(f"  Records with GPU data: {stats[1]}")
print(f"  Earliest record: {stats[2]}")
print(f"  Latest record: {stats[3]}")

print()

# 如果有GPU数据，查看一些样本
if stats[1] > 0:
    print("Sample GPU records:")
    cursor.execute("""
        SELECT sm.timestamp, s.name, sm.gpu_utilization, sm.gpu_memory_used, sm.gpu_memory_total, sm.gpu_temperature
        FROM server_metrics sm
        JOIN servers s ON sm.server_id = s.id
        WHERE sm.gpu_utilization IS NOT NULL
        ORDER BY sm.timestamp DESC
        LIMIT 10
    """)
    samples = cursor.fetchall()
    for sample in samples:
        print(f"  {sample[0]} - Server: {sample[1]}, GPU Util: {sample[2]}%, Mem: {sample[3]}/{sample[4]}MB, Temp: {sample[5]}°C")
else:
    print("No GPU data found in database.")

# 关闭连接
conn.close()