#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
创建一个测试数据库用于验证ChromaDB查看工具
"""

import chromadb
from chromadb.config import Settings
from chromadb.utils import embedding_functions

def create_test_database():
    print("创建测试数据库...")

    # 使用ChromaDB 0.3.x的API创建客户端
    client = chromadb.Client(
        chromadb.config.Settings(
            chroma_db_impl="duckdb+parquet",
            persist_directory="./test_new_db"
        )
    )

    # 创建一个集合，使用Sentence Transformer嵌入函数
    embedding_function = embedding_functions.SentenceTransformerEmbeddingFunction(model_name="all-MiniLM-L6-v2")
    collection = client.create_collection(name="code_symbols", embedding_function=embedding_function)

    # 添加一些测试数据
    test_documents = [
        {
            "id": "func_001",
            "content": "def calculate_sum(a, b):\n    return a + b",
            "metadata": {"file_path": "math_utils.py", "language": "python", "type": "function"}
        },
        {
            "id": "class_001",
            "content": "class DataProcessor:\n    def __init__(self):\n        self.data = []\n    \n    def process(self, item):\n        return item * 2",
            "metadata": {"file_path": "processor.py", "language": "python", "type": "class"}
        },
        {
            "id": "var_001",
            "content": "MAX_CONNECTIONS = 100",
            "metadata": {"file_path": "config.py", "language": "python", "type": "variable"}
        }
    ]

    # 提取ID、文档和元数据
    ids = [doc["id"] for doc in test_documents]
    documents = [doc["content"] for doc in test_documents]
    metadatas = [doc["metadata"] for doc in test_documents]

    # 添加到集合
    collection.add(
        ids=ids,
        documents=documents,
        metadatas=metadatas
    )

    print(f"成功添加 {len(test_documents)} 个文档到 'code_symbols' 集合")

    # 验证数据
    count = collection.count()
    print(f"集合中的总文档数: {count}")

    # 查询一些数据以验证
    results = collection.peek(limit=5)
    print(f"检索到 {len(results['ids'])} 个文档进行验证")

    for i, doc_id in enumerate(results['ids']):
        print(f"  - ID: {doc_id}, 内容预览: {results['documents'][i][:50]}...")

    print("测试数据库创建完成!")

if __name__ == "__main__":
    create_test_database()