from flask import Flask, render_template, request, jsonify
import chromadb
from chromadb.config import Settings
import os
from pathlib import Path
import platform

app = Flask(__name__)

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
        return {"error": f"数据库路径不存在: {db_path}"}

    try:
        # 检查是否是SQLite文件路径（如果是文件而不是目录）
        if os.path.isfile(db_path):
            # 如果是文件路径，取其所在的目录
            db_dir = os.path.dirname(db_path)
        else:
            # 如果是目录路径，直接使用
            db_dir = db_path

        # 连接到持久化数据库 - 适配ChromaDB 0.3.x API
        client = chromadb.Client(chromadb.config.Settings(chroma_db_impl="duckdb+parquet", persist_directory=db_dir))

        # 列出所有集合
        collections = client.list_collections()
        collection_list = [{"name": col.name, "metadata": getattr(col, 'metadata', {})} for col in collections]

        # 检查目标集合是否存在
        collection_names = [col.name for col in collections]
        if collection_name not in collection_names:
            return {"error": f"集合 '{collection_name}' 不存在", "available_collections": collection_names}

        # 获取指定集合
        collection = client.get_collection(name=collection_name)

        # 获取集合统计信息
        count = collection.count()

        if count == 0:
            return {"collections": collection_list, "stats": {"collection_name": collection_name, "count": 0}, "documents": []}

        # 获取样本数据 - 适配旧版本API
        sample_size = min(limit, count)
        sample_data = collection.peek(limit=sample_size)

        documents = []
        for i in range(len(sample_data['ids'])):
            doc_info = {
                "id": sample_data['ids'][i],
                "content": sample_data['documents'][i][:300] + "..." if len(sample_data['documents'][i]) > 300 else sample_data['documents'][i],
                "metadata": sample_data['metadatas'][i] if sample_data['metadatas'] and i < len(sample_data['metadatas']) else {}
            }
            documents.append(doc_info)

        return {
            "collections": collection_list,
            "stats": {"collection_name": collection_name, "count": count},
            "documents": documents
        }

    except Exception as e:
        return {"error": f"错误: {str(e)}"}


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
        return {"error": f"数据库路径不存在: {db_path}"}

    try:
        # 检查是否是SQLite文件路径（如果是文件而不是目录）
        if os.path.isfile(db_path):
            # 如果是文件路径，取其所在的目录
            db_dir = os.path.dirname(db_path)
        else:
            # 如果是目录路径，直接使用
            db_dir = db_path

        # 连接到持久化数据库 - 适配ChromaDB 0.3.x API
        client = chromadb.Client(chromadb.config.Settings(chroma_db_impl="duckdb+parquet", persist_directory=db_dir))

        # 获取集合
        try:
            collection = client.get_collection(name=collection_name)
        except:
            return {"error": f"集合 '{collection_name}' 不存在"}

        # 检查集合是否为空
        count = collection.count()
        if count == 0:
            return {"info": f"集合 '{collection_name}' 为空，无法执行搜索", "results": []}

        # 执行搜索 - 适配旧版本API
        results = collection.query(
            query_texts=[query_text],
            n_results=min(n_results, count)
        )

        search_results = []
        for i, result_id in enumerate(results['ids'][0] if results['ids'] else []):
            doc_info = {
                "id": result_id,
                "content": results['documents'][0][i][:300] + "..." if len(results['documents'][0][i]) > 300 else results['documents'][0][i],
                "metadata": results['metadatas'][0][i] if results['metadatas'][0] and i < len(results['metadatas'][0]) else {},
                "similarity": round(1 / (1 + results['distances'][0][i]), 4) if results['distances'][0] and i < len(results['distances'][0]) else 0
            }
            search_results.append(doc_info)

        return {
            "query": query_text,
            "results": search_results
        }

    except Exception as e:
        return {"error": f"搜索错误: {str(e)}"}


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/api/view', methods=['POST'])
def api_view():
    data = request.json
    db_path = data.get('db_path')
    collection_name = data.get('collection_name', 'code_symbols')
    limit = data.get('limit', 10)

    result = view_chroma_contents(db_path, collection_name, limit)
    return jsonify(result)


@app.route('/api/search', methods=['POST'])
def api_search():
    data = request.json
    db_path = data.get('db_path')
    query_text = data.get('query_text')
    collection_name = data.get('collection_name', 'code_symbols')
    n_results = data.get('n_results', 5)

    result = search_chroma_contents(db_path, query_text, collection_name, n_results)
    return jsonify(result)


def find_chroma_dbs(base_paths=None):
    """
    查找系统上可能的ChromaDB路径

    Args:
        base_paths: 要搜索的基础路径列表
    """
    if base_paths is None:
        # 默认搜索路径
        base_paths = [
            os.getcwd(),  # 当前工作目录
            os.path.expanduser("~"),  # 用户主目录
            os.path.join(os.getcwd(), "projects"),  # 当前目录下的projects文件夹
            os.path.join(os.getcwd(), "chroma_stores"),  # 当前目录下的chroma_stores文件夹
        ]

        # 添加一些常见的项目目录
        if platform.system() == "Windows":
            base_paths.extend([
                "C:\\Projects",
                "C:\\Users\\Public\\Documents",
            ])
        else:
            base_paths.extend([
                "/tmp",
                "/var/lib",
                "/opt",
            ])

    found_paths = []

    for base_path in base_paths:
        if not os.path.exists(base_path):
            continue

        # 搜索所有名为 chroma_store 或包含 .parquet 文件的目录
        for root, dirs, files in os.walk(base_path):
            # 检查是否是ChromaDB目录 (通常包含 .parquet 文件或其他ChromaDB特征文件)
            has_parquet = any(file.endswith('.parquet') for file in files)
            has_index = any(file.startswith('index') for file in files)
            has_metadata = any(file == 'metadata.json' for file in files)

            if has_parquet or has_index or has_metadata or 'chroma_store' in root:
                found_paths.append(root)

            # 限制搜索深度以避免过度搜索
            if root[len(base_path):].count(os.sep) >= 3:
                dirs[:] = []  # 不再深入子目录

    # 去重并返回
    return list(set(found_paths))


@app.route('/api/get_db_paths', methods=['GET'])
def api_get_db_paths():
    """获取可能的数据库路径"""
    try:
        paths = find_chroma_dbs()
        return jsonify({"paths": paths})
    except Exception as e:
        return jsonify({"error": f"获取数据库路径时出错: {str(e)}"})


@app.route('/api/list_dirs', methods=['POST'])
def api_list_dirs():
    """列出指定路径下的子目录"""
    try:
        data = request.json
        path = data.get('path', '.')

        # 处理相对路径
        if not os.path.isabs(path):
            path = os.path.abspath(path)

        # 验证路径存在且是一个目录
        if not os.path.exists(path):
            return jsonify({"error": f"路径不存在: {path}"})

        if not os.path.isdir(path):
            return jsonify({"error": f"路径不是一个目录: {path}"})

        # 获取目录下的所有子目录
        subdirs = []
        for item in os.listdir(path):
            item_path = os.path.join(path, item)
            if os.path.isdir(item_path):
                subdirs.append(item_path)

        # 也包括当前指定的路径，以防它本身就是一个数据库目录
        if is_chroma_db_directory(path):
            subdirs.insert(0, path)

        return jsonify({"dirs": subdirs})

    except Exception as e:
        return jsonify({"error": f"列出目录时出错: {str(e)}"})


def is_chroma_db_directory(path):
    """检查给定路径是否是ChromaDB目录"""
    try:
        files = os.listdir(path)
        # ChromaDB目录通常包含.parquet文件、metadata文件等
        has_parquet = any(file.endswith('.parquet') for file in files)
        has_index = any(file.startswith('index') for file in files)
        has_metadata = any(file == 'metadata.json' for file in files)
        # 或者包含chroma特定的文件
        has_chroma_files = any('_client' in file or 'embeddings' in file for file in files)
        # 也可能包含SQLite数据库文件
        has_sqlite = any(file.endswith('.sqlite3') or file.endswith('.db') for file in files)

        return has_parquet or has_index or has_metadata or has_chroma_files or has_sqlite
    except:
        return False


@app.route('/api/list_directory', methods=['POST'])
def api_list_directory():
    """列出指定目录的内容"""
    try:
        data = request.json
        path = data.get('path', '.')

        # 处理特殊路径
        if path == '' or path == '~':
            path = os.path.expanduser("~")  # 用户主目录
        elif not os.path.isabs(path):
            path = os.path.abspath(path)

        # 验证路径存在且是一个目录
        if not os.path.exists(path):
            return jsonify({"error": f"路径不存在: {path}"})

        if not os.path.isdir(path):
            return jsonify({"error": f"路径不是一个目录: {path}"})

        # 获取父目录路径
        parent_path = os.path.dirname(path)
        if parent_path != path:  # 确保不是根目录
            parent_path_display = parent_path
        else:
            parent_path = None

        # 获取目录内容
        items = os.listdir(path)
        directories = []
        chroma_dbs = []

        for item in items:
            item_path = os.path.join(path, item)
            if os.path.isdir(item_path):
                is_chroma = is_chroma_db_directory(item_path)
                dir_info = {
                    "name": item,
                    "path": item_path,
                    "is_chroma_db": is_chroma
                }

                if is_chroma:
                    chroma_dbs.append(dir_info)
                else:
                    directories.append(dir_info)

        # 对目录和数据库进行排序
        directories.sort(key=lambda x: x['name'].lower())
        chroma_dbs.sort(key=lambda x: x['name'].lower())

        return jsonify({
            "current_path": path,
            "parent_path": parent_path,
            "directories": directories,
            "chroma_dbs": chroma_dbs
        })

    except Exception as e:
        return jsonify({"error": f"列出目录时出错: {str(e)}"})


@app.route('/api/get_collections', methods=['POST'])
def api_get_collections():
    """获取指定数据库路径的集合列表"""
    try:
        data = request.json
        db_path = data.get('db_path', '.')

        # 处理相对路径
        if not os.path.isabs(db_path):
            db_path = os.path.abspath(db_path)

        # 验证路径存在
        if not os.path.exists(db_path):
            return jsonify({"error": f"数据库路径不存在: {db_path}"})

        # 检查是否是SQLite文件路径（如果是文件而不是目录）
        if os.path.isfile(db_path):
            # 如果是文件路径，取其所在的目录
            db_dir = os.path.dirname(db_path)
        else:
            # 如果是目录路径，直接使用
            db_dir = db_path

        # 验证路径是一个目录
        if not os.path.isdir(db_dir):
            return jsonify({"error": f"数据库路径不是一个目录: {db_dir}"})

        # 连接到ChromaDB - 适配ChromaDB 0.3.x API
        client = chromadb.Client(chromadb.config.Settings(chroma_db_impl="duckdb+parquet", persist_directory=db_dir))

        # 获取所有集合
        collections = client.list_collections()
        collections_info = []

        for col in collections:
            # 获取集合中的文档数量
            try:
                collection_obj = client.get_collection(col.name)
                count = collection_obj.count()
            except:
                count = 0

            collections_info.append({
                "name": col.name,
                "count": count,
                "metadata": col.metadata
            })

        return jsonify({"collections": collections_info})

    except Exception as e:
        return jsonify({"error": f"获取集合列表时出错: {str(e)}"})


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)