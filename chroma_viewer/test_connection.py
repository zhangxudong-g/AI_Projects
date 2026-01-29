#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
测试连接到现有的ChromaDB数据库
"""

import chromadb
from chromadb.config import Settings

def test_connection():
    # 尝试连接到现有的数据库
    try:
        print("尝试连接到 test_chroma_db 目录...")
        
        # 使用ChromaDB 0.3.x的API
        client = chromadb.Client(
            chromadb.config.Settings(
                chroma_db_impl="duckdb+parquet",
                persist_directory="../test_chroma_db"
            )
        )
        
        print("连接成功!")
        
        # 列出所有集合
        collections = client.list_collections()
        print(f"找到 {len(collections)} 个集合:")
        for col in collections:
            print(f"  - {col.name} (元数据: {getattr(col, 'metadata', {})})")
            
            # 尝试获取集合中的文档数量
            try:
                collection = client.get_collection(name=col.name)
                count = collection.count()
                print(f"    文档数量: {count}")
            except Exception as e:
                print(f"    获取文档数量失败: {e}")
                
    except Exception as e:
        print(f"连接失败: {e}")
        
        # 尝试另一种方式
        try:
            print("\n尝试使用不同的设置...")
            client = chromadb.Client(
                chromadb.config.Settings(
                    chroma_db_impl="duckdb",
                    persist_directory="../test_chroma_db"
                )
            )
            
            print("连接成功!")
            collections = client.list_collections()
            print(f"找到 {len(collections)} 个集合:")
            for col in collections:
                print(f"  - {col.name}")
        except Exception as e2:
            print(f"第二种方式也失败: {e2}")

if __name__ == "__main__":
    test_connection()