import sqlite3
from datetime import datetime

# 连接到数据库
conn = sqlite3.connect('D:/AI_Projects/server_monitor/monitoring.db')
cursor = conn.cursor()

# 检查当前数据分布
print("Checking current data distribution...")

# 统计错误时间戳的数据（1970年代的数据）
cursor.execute("""
    SELECT COUNT(*) 
    FROM server_metrics 
    WHERE timestamp < '1990-01-01'
""")
old_data_count = cursor.fetchone()[0]

print(f"Records with incorrect timestamps (< 1990): {old_data_count}")

# 统计正确时间戳的数据（1990年以后的数据）
cursor.execute("""
    SELECT COUNT(*) 
    FROM server_metrics 
    WHERE timestamp >= '1990-01-01'
""")
correct_data_count = cursor.fetchone()[0]

print(f"Records with correct timestamps (>= 1990): {correct_data_count}")

# 如果有错误的数据，自动删除
if old_data_count > 0:
    print(f"\nFound {old_data_count} records with incorrect timestamps.")
    print("Deleting records with incorrect timestamps...")

    # 删除错误时间戳的数据
    cursor.execute("""
        DELETE FROM server_metrics
        WHERE timestamp < '1990-01-01'
    """)

    conn.commit()
    print(f"Deleted {old_data_count} records with incorrect timestamps.")

    # 验证删除结果
    cursor.execute("SELECT COUNT(*) FROM server_metrics")
    remaining_count = cursor.fetchone()[0]
    print(f"Remaining records in database: {remaining_count}")
else:
    print("No records with incorrect timestamps found.")

# 关闭连接
conn.close()