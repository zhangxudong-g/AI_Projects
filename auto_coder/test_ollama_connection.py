"""测试 Ollama 连接"""

import requests
import json

# Ollama 服务器地址
OLLAMA_BASE_URL = "http://133.238.28.90:51434"

def test_connection():
    """测试连接"""
    print(f"测试连接到：{OLLAMA_BASE_URL}")
    
    # 测试 /api/tags 端点
    try:
        response = requests.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=10)
        response.raise_for_status()
        
        print("✓ 连接成功！")
        print(f"状态码：{response.status_code}")
        
        # 解析响应
        data = response.json()
        print(f"\n可用模型:")
        
        if "models" in data:
            for model in data["models"]:
                name = model.get("name", "unknown")
                size = model.get("size", 0)
                modified = model.get("modified_at", "unknown")
                print(f"  - {name} (大小：{size / 1024 / 1024 / 1024:.2f}GB)")
        else:
            print(json.dumps(data, indent=2, ensure_ascii=False))
        
        return True
    
    except requests.exceptions.ConnectionError as e:
        print(f"✗ 连接失败：无法连接到服务器")
        print(f"错误：{e}")
        return False
    except requests.exceptions.Timeout:
        print(f"✗ 连接超时：服务器响应超时")
        return False
    except Exception as e:
        print(f"✗ 错误：{e}")
        return False


def test_chat(model_name: str = "qwen2.5-coder:7b"):
    """测试聊天"""
    print(f"\n测试聊天（模型：{model_name}）")
    
    url = f"{OLLAMA_BASE_URL}/api/chat"
    
    payload = {
        "model": model_name,
        "messages": [
            {
                "role": "user",
                "content": "你好，请用一句话介绍你自己"
            }
        ],
        "stream": False
    }
    
    try:
        response = requests.post(url, json=payload, timeout=60)
        response.raise_for_status()
        
        data = response.json()
        message = data.get("message", {})
        content = message.get("content", "")
        
        print(f"回复：{content}")
        return True
    
    except Exception as e:
        print(f"✗ 聊天测试失败：{e}")
        return False


def test_generate(model_name: str = "qwen2.5-coder:7b"):
    """测试代码生成"""
    print(f"\n测试代码生成（模型：{model_name}）")
    
    url = f"{OLLAMA_BASE_URL}/api/generate"
    
    payload = {
        "model": model_name,
        "prompt": "用 Python 写一个 Hello World 函数",
        "stream": False
    }
    
    try:
        response = requests.post(url, json=payload, timeout=60)
        response.raise_for_status()
        
        data = response.json()
        response_text = data.get("response", "")
        
        print(f"生成内容:\n{response_text[:500]}...")
        return True
    
    except Exception as e:
        print(f"✗ 生成测试失败：{e}")
        return False


if __name__ == "__main__":
    print("=" * 50)
    print("Ollama 连接测试工具")
    print("=" * 50)
    
    # 测试连接
    if test_connection():
        # 获取模型列表
        try:
            response = requests.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=10)
            data = response.json()
            models = data.get("models", [])
            
            if models:
                # 使用第一个可用模型
                model_name = models[0].get("name", "qwen2.5-coder:7b")
                
                # 测试聊天
                test_chat(model_name)
                
                # 测试生成
                test_generate(model_name)
        except Exception as e:
            print(f"获取模型列表失败：{e}")
    else:
        print("\n请检查:")
        print("1. Ollama 服务器是否运行")
        print("2. 网络连接是否正常")
        print("3. 防火墙设置")
