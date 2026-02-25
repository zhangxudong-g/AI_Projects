#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
数据库迁移脚本：为 test_cases 表添加 tag 字段
"""

import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from backend.database import engine, SessionLocal
from sqlalchemy import text

def migrate():
    """添加 tag 字段到 test_cases 表"""
    db = SessionLocal()
    
    try:
        # 检查列是否已存在
        result = db.execute(text("""
            PRAGMA table_info(test_cases)
        """))
        columns = [row[1] for row in result.fetchall()]
        
        if 'tag' in columns:
            print("tag 字段已存在，无需迁移")
            return
        
        # 添加 tag 字段
        print("正在为 test_cases 表添加 tag 字段...")
        db.execute(text("""
            ALTER TABLE test_cases ADD COLUMN tag VARCHAR
        """))
        db.commit()
        
        # 创建索引
        print("正在为 tag 字段创建索引...")
        db.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_test_cases_tag ON test_cases(tag)
        """))
        db.commit()
        
        print("[OK] 迁移完成！test_cases 表现在包含 tag 字段")
        
    except Exception as e:
        db.rollback()
        print(f"[FAIL] 迁移失败：{str(e)}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    migrate()
