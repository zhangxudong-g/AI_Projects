#!/usr/bin/env python
"""AutoCoder 命令行工具 - 简化代码生成流程"""

import sys
import time
import requests
import json
from pathlib import Path

# 默认配置
DEFAULT_BASE_URL = "http://localhost:8001"
DEFAULT_MODEL = "nemotron-3-super:120b"
DEFAULT_PROVIDER = "ollama"


def print_colored(text: str, color: str = "white"):
    """彩色输出"""
    colors = {
        "red": "\033[91m",
        "green": "\033[92m",
        "yellow": "\033[93m",
        "blue": "\033[94m",
        "magenta": "\033[95m",
        "cyan": "\033[96m",
        "white": "\033[97m",
    }
    reset = "\033[0m"
    print(f"{colors.get(color, '')}{text}{reset}")


def check_server(base_url: str) -> bool:
    """检查服务器是否运行"""
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        return response.status_code == 200
    except requests.exceptions.ConnectionError:
        return False


def generate_code(
    request: str,
    base_url: str = DEFAULT_BASE_URL,
    model_provider: str = DEFAULT_PROVIDER,
    model_name: str = DEFAULT_MODEL,
    stream: bool = False,
):
    """生成代码"""
    url = f"{base_url}/api/generate_code"
    
    payload = {
        "request": request,
        "model_provider": model_provider,
        "model_name": model_name,
    }
    
    print_colored(f"\n📝 需求：{request}", "cyan")
    print_colored(f"🤖 模型：{model_provider}/{model_name}", "cyan")
    print_colored(f"🌐 服务：{base_url}", "cyan")
    print()
    
    try:
        if stream:
            # 流式输出（暂未实现）
            print_colored("⚠️  流式模式暂未实现，使用普通模式", "yellow")
        
        print_colored("⏳ 正在生成代码，请稍候...", "yellow")
        start_time = time.time()
        
        response = requests.post(url, json=payload, timeout=600)
        
        elapsed = time.time() - start_time
        
        if response.status_code != 200:
            print_colored(f"❌ 请求失败：{response.status_code}", "red")
            print_colored(f"错误详情：{response.text}", "red")
            return
        
        result = response.json()
        
        # 显示结果
        if result.get("success"):
            print_colored("✅ 代码生成成功！", "green")
            print_colored(f"⏱️  耗时：{elapsed:.1f}秒", "green")
            
            files = result.get("files", [])
            if files:
                print_colored(f"\n📁 生成的文件 ({len(files)} 个):", "green")
                for f in files:
                    print(f"   - {f}")
            
            output = result.get("output")
            if output:
                print_colored(f"\n📄 输出：{output}", "green")
        else:
            print_colored("❌ 代码生成失败", "red")
            errors = result.get("errors", [])
            if errors:
                print_colored("\n错误信息:", "red")
                for err in errors:
                    print(f"   - {err}")
        
        # 显示生成的文件内容
        if result.get("success") and result.get("files"):
            view_files = input("\n是否查看生成的文件内容？(y/n): ").strip().lower()
            if view_files == "y":
                for file_path in result.get("files", [])[:3]:  # 最多显示 3 个
                    view_file_content(base_url, file_path)
    
    except requests.exceptions.Timeout:
        print_colored("\n❌ 请求超时（超过 10 分钟）", "red")
        print_colored("💡 提示：大模型生成代码可能需要较长时间，请耐心等待", "yellow")
    except requests.exceptions.ConnectionError:
        print_colored(f"\n❌ 无法连接到服务器：{base_url}", "red")
        print_colored("💡 提示：请先启动服务 python -m uvicorn app.main:app --port 8001", "yellow")
    except Exception as e:
        print_colored(f"\n❌ 错误：{e}", "red")


def view_file_content(base_url: str, file_path: str):
    """查看文件内容"""
    try:
        response = requests.get(f"{base_url}/api/workspace/files/{file_path}")
        if response.status_code == 200:
            data = response.json()
            content = data.get("content", "")
            
            print_colored(f"\n📄 {file_path}:", "magenta")
            print("-" * 60)
            
            # 显示前 50 行
            lines = content.split("\n")
            for i, line in enumerate(lines[:50], 1):
                print(f"{i:4d} | {line}")
            
            if len(lines) > 50:
                print(f"... 还有 {len(lines) - 50} 行")
            
            print("-" * 60)
        else:
            print_colored(f"无法读取文件：{file_path}", "yellow")
    except Exception as e:
        print_colored(f"读取文件失败：{e}", "red")


def interactive_mode(base_url: str):
    """交互模式"""
    print_colored("=" * 60, "cyan")
    print_colored("  AutoCoder - 自动代码生成工具", "cyan")
    print_colored("=" * 60, "cyan")
    print()
    
    # 检查服务器
    if not check_server(base_url):
        print_colored(f"❌ 无法连接到服务器：{base_url}", "red")
        print_colored("💡 请先启动服务：python -m uvicorn app.main:app --port 8001", "yellow")
        print()
        print_colored("按 Enter 退出...", "white")
        input()
        return
    
    print_colored("✅ 服务器连接成功", "green")
    print()
    print_colored("使用说明:", "cyan")
    print("  - 输入你的代码需求，按 Enter 提交")
    print("  - 输入 'quit' 或 'exit' 退出")
    print("  - 输入 'help' 查看帮助")
    print()
    
    while True:
        try:
            user_input = input("🔹 请输入需求：").strip()
            
            if not user_input:
                continue
            
            if user_input.lower() in ["quit", "exit", "q"]:
                print_colored("\n👋 再见！", "cyan")
                break
            
            if user_input.lower() == "help":
                print()
                print_colored("可用命令:", "cyan")
                print("  quit/exit/q  - 退出程序")
                print("  help         - 显示帮助")
                print("  files        - 查看已生成的文件列表")
                print()
                continue
            
            if user_input.lower() == "files":
                list_files(base_url)
                continue
            
            # 生成代码
            generate_code(user_input, base_url)
            
            print()
        
        except KeyboardInterrupt:
            print()
            print_colored("\n👋 中断退出", "yellow")
            break
        except Exception as e:
            print_colored(f"错误：{e}", "red")


def list_files(base_url: str):
    """列出工作空间文件"""
    try:
        response = requests.get(f"{base_url}/api/workspace/files?recursive=true")
        if response.status_code == 200:
            data = response.json()
            files = data.get("files", [])
            
            print_colored(f"\n📁 工作空间文件 ({len(files)} 个):", "cyan")
            for f in files:
                icon = "📂" if f.get("is_dir") else "📄"
                print(f"  {icon} {f['path']}")
        else:
            print_colored("获取文件列表失败", "red")
    except Exception as e:
        print_colored(f"错误：{e}", "red")


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="AutoCoder - 自动代码生成工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 交互模式
  python cli.py
  
  # 单次生成
  python cli.py "创建一个 Flask Hello World 应用"
  
  # 指定模型
  python cli.py "生成排序算法" --model qwen3:32b
        """,
    )
    
    parser.add_argument(
        "request",
        nargs="?",
        help="代码生成需求描述",
    )
    parser.add_argument(
        "--url",
        default=DEFAULT_BASE_URL,
        help=f"服务器地址 (默认：{DEFAULT_BASE_URL})",
    )
    parser.add_argument(
        "--provider",
        default=DEFAULT_PROVIDER,
        help=f"模型提供商 (默认：{DEFAULT_PROVIDER})",
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"模型名称 (默认：{DEFAULT_MODEL})",
    )
    parser.add_argument(
        "--stream",
        action="store_true",
        help="使用流式输出",
    )
    
    args = parser.parse_args()
    
    if args.request:
        # 单次生成模式
        generate_code(
            args.request,
            base_url=args.url,
            model_provider=args.provider,
            model_name=args.model,
            stream=args.stream,
        )
    else:
        # 交互模式
        interactive_mode(args.url)


if __name__ == "__main__":
    main()
