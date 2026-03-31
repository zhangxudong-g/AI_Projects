#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Wiki Fact Judge 系统启动脚本
支持 Windows/Linux/macOS
"""

import os
import sys
import subprocess
import time
import argparse
from pathlib import Path

# 默认端口（使用较少用的端口避免冲突）
DEFAULT_BACKEND_PORT = 8765
DEFAULT_FRONTEND_PORT = 3456


def check_command(cmd, name):
    """检查命令是否可用"""
    try:
        subprocess.run([cmd, "--version"], capture_output=True, timeout=5)
        return True
    except Exception:
        print(f"[错误] 未找到 {name}，请先安装")
        return False


def check_dependencies(project_root, start_backend, start_frontend):
    """检查并安装依赖"""
    if start_backend:
        print("[检查] 后端依赖...")
        try:
            subprocess.run([sys.executable, "-m", "pip", "show", "fastapi"], 
                         capture_output=True, check=True)
            print("  [OK] FastAPI 已安装")
        except subprocess.CalledProcessError:
            print("  [安装] 后端依赖...")
            subprocess.run([sys.executable, "-m", "pip", "install", "-r", 
                         str(project_root / "requirements.txt"), "-q"])
    
    if start_frontend:
        print("[检查] 前端依赖...")
        frontend_dir = project_root / "frontend"
        node_modules = frontend_dir / "node_modules"
        if not node_modules.exists():
            print("  [安装] 前端依赖...")
            subprocess.run(["npm", "install", "--silent"], cwd=frontend_dir)
        else:
            print("  [OK] 前端依赖已安装")
    
    print()


def start_backend(project_root, port):
    """启动后端服务"""
    print(f"[启动] 后端服务 (端口 {port})...")
    backend_dir = project_root / "backend"
    
    cmd = [sys.executable, "-m", "uvicorn", "main:app", "--reload", 
           "--port", str(port), "--host", "0.0.0.0"]
    
    process = subprocess.Popen(cmd, cwd=backend_dir)
    print(f"  [OK] 后端服务已启动 (PID: {process.pid})")
    return process


def start_frontend(project_root, port):
    """启动前端服务"""
    print(f"[启动] 前端服务 (端口 {port})...")
    frontend_dir = project_root / "frontend"
    
    env = os.environ.copy()
    env["PORT"] = str(port)
    
    # Windows 需要使用 npm.cmd
    if sys.platform == "win32":
        npm_cmd = "npm.cmd"
    else:
        npm_cmd = "npm"
    
    process = subprocess.Popen([npm_cmd, "start"], cwd=frontend_dir, env=env, shell=True)
    print(f"  [OK] 前端服务已启动 (PID: {process.pid})")
    return process


def main():
    parser = argparse.ArgumentParser(description="Wiki Fact Judge 系统启动脚本")
    parser.add_argument("--backend", action="store_true", help="只启动后端服务")
    parser.add_argument("--frontend", action="store_true", help="只启动前端服务")
    parser.add_argument("--backend-port", type=int, default=DEFAULT_BACKEND_PORT,
                       help=f"后端端口 (默认：{DEFAULT_BACKEND_PORT})")
    parser.add_argument("--frontend-port", type=int, default=DEFAULT_FRONTEND_PORT,
                       help=f"前端端口 (默认：{DEFAULT_FRONTEND_PORT})")
    
    args = parser.parse_args()
    
    # 确定启动模式
    start_backend_flag = not (args.backend or args.frontend) or args.backend
    start_frontend_flag = not (args.backend or args.frontend) or args.frontend
    
    # 打印信息
    print("=" * 60)
    print("Wiki Fact Judge 系统启动脚本")
    print("=" * 60)
    print()
    print(f"默认端口：后端={args.backend_port}, 前端={args.frontend_port}")
    print()
    
    # 获取项目根目录
    project_root = Path(__file__).parent
    
    # 检查依赖
    if not check_command("python", "Python"):
        sys.exit(1)
    
    if start_frontend_flag and not check_command("node", "Node.js"):
        sys.exit(1)
    
    print("[OK] Python 和 Node.js 已安装")
    print()
    
    # 检查并安装依赖
    check_dependencies(project_root, start_backend_flag, start_frontend_flag)
    
    # 启动服务
    processes = []
    
    if start_backend_flag:
        processes.append(start_backend(project_root, args.backend_port))
        time.sleep(2)  # 等待后端启动
    
    if start_frontend_flag:
        processes.append(start_frontend(project_root, args.frontend_port))
    
    print()
    print("=" * 60)
    print("服务启动完成!")
    print()
    if start_backend_flag:
        print(f"后端 API:  http://localhost:{args.backend_port}")
        print(f"后端文档：http://localhost:{args.backend_port}/docs")
    if start_frontend_flag:
        print(f"前端界面：http://localhost:{args.frontend_port}")
    print("=" * 60)
    print()
    print("按 Ctrl+C 停止所有服务")
    print()
    
    # 等待进程结束
    try:
        for proc in processes:
            proc.wait()
    except KeyboardInterrupt:
        print("\n正在停止服务...")
        for proc in processes:
            proc.terminate()
        print("所有服务已停止")


if __name__ == "__main__":
    main()
