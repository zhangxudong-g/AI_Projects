"""
ChromaDB 查看工具
用于查看 Code Wiki 项目中存储在 ChromaDB 中的代码符号信息
"""

import argparse
import chromadb
from chromadb.config import Settings
import json
import os
from pathlib import Path


def view_chroma_contents(db_path, collection_name="code_symbols", limit=10):
    """
    查看ChromaDB内容的函数

    Args:
        db_path: ChromaDB的路径
        collection_name: 集合名称
        limit: 显示的最大文档数量
    """
    # 检查路径是否存在
    if not os.path.exists(db_path):
        print(f"[ERROR] 错误: 数据库路径不存在: {db_path}")
        return False

    try:
        # 连接到持久化数据库
        client = chromadb.PersistentClient(
            path=db_path,
            settings=Settings(anonymized_telemetry=False)
        )

        # 列出所有集合
        collections = client.list_collections()
        print("[COLLECTION] 可用集合:")
        for col in collections:
            print(f"  - {col.name} (元数据: {col.metadata})")

        # 检查目标集合是否存在
        collection_names = [col.name for col in collections]
        if collection_name not in collection_names:
            print(f"\n[ERROR] 错误: 集合 '{collection_name}' 不存在")
            print(f"可用集合: {collection_names}")
            return False

        # 获取指定集合
        collection = client.get_collection(collection_name)

        # 获取集合统计信息
        count = collection.count()
        print(f"\n[STATS] 集合 '{collection_name}' 包含 {count} 个文档")

        if count == 0:
            print("[EMPTY] 集合为空")
            return True

        # 获取所有文档ID
        all_ids = collection.get(include=['documents'])
        print(f"[COUNT] 总共 {len(all_ids['ids'])} 个文档ID")

        # 获取样本数据
        sample_size = min(limit, count)
        sample_data = collection.peek(limit=sample_size)

        print(f"\n[PREVIEW] 前 {sample_size} 个样本:")
        for i in range(len(sample_data['ids'])):
            print(f"\n{'='*60}")
            print(f"文档 {i+1}: ID={sample_data['ids'][i]}")

            if sample_data['documents'] and i < len(sample_data['documents']):
                doc_content = sample_data['documents'][i]
                doc_preview = doc_content[:300] + "..." if len(doc_content) > 300 else doc_content
                print(f"[DOC] 文档内容预览:\n{doc_preview}")

            if sample_data['metadatas'] and i < len(sample_data['metadatas']):
                metadata = sample_data['metadatas'][i]
                print(f"[META] 元数据:")
                for key, value in metadata.items():
                    print(f"   {key}: {value}")

        return True

    except Exception as e:
        print(f"[ERROR] 错误: {str(e)}")
        return False


def search_chroma_contents(db_path, query_text, collection_name="code_symbols", n_results=5):
    """
    在ChromaDB中搜索内容

    Args:
        db_path: ChromaDB的路径
        query_text: 搜索查询文本
        collection_name: 集合名称
        n_results: 返回结果数量
    """
    # 检查路径是否存在
    if not os.path.exists(db_path):
        print(f"[ERROR] 错误: 数据库路径不存在: {db_path}")
        return False

    try:
        # 连接到持久化数据库
        client = chromadb.PersistentClient(
            path=db_path,
            settings=Settings(anonymized_telemetry=False)
        )

        # 获取集合
        try:
            collection = client.get_collection(collection_name)
        except:
            print(f"[ERROR] 错误: 集合 '{collection_name}' 不存在")
            return False

        # 检查集合是否为空
        count = collection.count()
        if count == 0:
            print(f"[INFO] 集合 '{collection_name}' 为空，无法执行搜索")
            return True

        # 执行搜索
        results = collection.query(
            query_texts=[query_text],
            n_results=min(n_results, count)
        )

        print(f"\n[SEARCH] 搜索 '{query_text}' 的结果:")
        print(f"找到 {len(results['ids'][0]) if results['ids'] else 0} 个匹配项")

        for i, result_id in enumerate(results['ids'][0] if results['ids'] else []):
            print(f"\n{'-'*50}")
            print(f"结果 {i+1}: ID={result_id}")

            if results['metadatas'][0] and i < len(results['metadatas'][0]):
                meta = results['metadatas'][0][i]
                print(f"[META] 元数据:")
                for key, value in meta.items():
                    print(f"   {key}: {value}")

            if results['documents'][0] and i < len(results['documents'][0]):
                doc_content = results['documents'][0][i]
                doc_preview = doc_content[:300] + "..." if len(doc_content) > 300 else doc_content
                print(f"[DOC] 文档内容预览:\n{doc_preview}")

            if results['distances'][0] and i < len(results['distances'][0]):
                distance = results['distances'][0][i]
                similarity = 1 / (1 + distance)  # 转换为相似度
                print(f"[SIMILARITY] 相似度: {similarity:.4f} (距离: {distance:.4f})")

        return True

    except Exception as e:
        print(f"[ERROR] 搜索错误: {str(e)}")
        return False


def list_projects(base_path="projects"):
    """
    列出所有项目

    Args:
        base_path: 项目基础路径
    """
    projects_dir = Path(base_path)
    if not projects_dir.exists():
        print(f"[DIR] 项目目录不存在: {base_path}")
        return []

    projects = []
    for item in projects_dir.iterdir():
        if item.is_dir():
            # 检查是否有chroma_store目录
            chroma_dir = item / "chroma_store"
            if chroma_dir.exists():
                projects.append(item.name)

    return projects


def main():
    parser = argparse.ArgumentParser(description="ChromaDB 查看工具 - Code Wiki 项目专用")
    parser.add_argument("--db-path", type=str, help="ChromaDB 路径")
    parser.add_argument("--project", type=str, help="项目名称 (如果指定，会自动构建路径)")
    parser.add_argument("--collection", type=str, default="code_symbols", help="集合名称 (默认: code_symbols)")
    parser.add_argument("--limit", type=int, default=5, help="显示的最大文档数量 (默认: 5)")
    parser.add_argument("--search", type=str, help="搜索查询文本")
    parser.add_argument("--list-projects", action="store_true", help="列出所有项目")
    
    args = parser.parse_args()
    
    # 列出项目
    if args.list_projects:
        print("[DIR] Code Wiki 项目列表:")
        projects = list_projects()
        if projects:
            for project in projects:
                chroma_path = f"projects/{project}/chroma_store/"
                exists = "[OK]" if os.path.exists(chroma_path) else "[MISSING]"
                print(f"  {exists} {project}")
        else:
            print("  没有找到项目")
        return
    
    # 确定数据库路径
    db_path = None
    if args.db_path:
        db_path = args.db_path
    elif args.project:
        db_path = f"projects/{args.project}/chroma_store/"
    else:
        print("[ERROR] 请指定 --db-path 或 --project 参数")
        parser.print_help()
        return

    print(f"[CONNECT] 连接到 ChromaDB: {db_path}")

    # 执行搜索或查看
    if args.search:
        success = search_chroma_contents(
            db_path=db_path,
            query_text=args.search,
            collection_name=args.collection,
            n_results=args.limit
        )
    else:
        success = view_chroma_contents(
            db_path=db_path,
            collection_name=args.collection,
            limit=args.limit
        )

    if success:
        print(f"\n[DONE] 操作完成")
    else:
        print(f"\n[FAILED] 操作失败")


if __name__ == "__main__":
    main()