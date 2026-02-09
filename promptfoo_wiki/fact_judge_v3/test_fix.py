"""
简化测试脚本，用于验证变量传递修复
"""
import json
from pathlib import Path
from datetime import datetime
import subprocess
import os

def run_simple_test():
    """运行一个简单的测试来验证修复"""
    print("Running simple test to verify variable passing fix...")
    
    # 使用第一个正向测试用例
    case_dir = Path("stage2_positive_regression_full/PT_01_controller_good")
    
    # 读取测试配置
    import yaml
    with open(case_dir / "case.yaml", "r", encoding="utf-8") as f:
        spec = yaml.safe_load(f)
    
    files = spec.get("files", {})
    
    # 查找源代码文件
    source_filename = files.get("source", "source.java")
    source_path = case_dir / source_filename
    
    # 如果默认文件不存在，尝试其他可能的名称
    if not source_path.exists():
        possible_names = ["source.java", "source_code.java", "source_code.sql", "source.sql", "source.py", "source_code.py"]
        for name in possible_names:
            alt_path = case_dir / name
            if alt_path.exists():
                source_filename = name
                source_path = alt_path
                break
    
    # 查找wiki文件
    wiki_filename = files.get("wiki", "wiki.md")
    wiki_path = case_dir / wiki_filename
    
    # 如果默认文件不存在，尝试其他可能的名称
    if not wiki_path.exists():
        possible_names = ["wiki.md", "wiki.txt", "documentation.md", "doc.md"]
        for name in possible_names:
            alt_path = case_dir / name
            if alt_path.exists():
                wiki_filename = name
                wiki_path = alt_path
                break

    vars_cfg = {
        "source_code": str(source_path),
        "wiki_md": str(wiki_path),
    }

    # 添加语言检测
    if source_path.exists():
        ext = source_path.suffix.lower()
        if ext in ['.sql', '.plsql']:
            vars_cfg["language"] = "sql"
        elif ext in ['.py', '.txt']:
            vars_cfg["language"] = "python"
        elif ext in ['.java', '.js', '.ts', '.jsx', '.tsx', '.c', '.cpp', '.cs', '.go', '.rs', '.rb', '.php']:
            vars_cfg["language"] = ext[1:]  # 去掉点号
        else:
            vars_cfg["language"] = "java"  # 默认值

    print(f"Source file: {source_path}")
    print(f"Wiki file: {wiki_path}")
    print(f"Language: {vars_cfg.get('language', 'unknown')}")
    
    # 为 Stage 1 构建正确的命令行参数
    var_args = []
    for k, v in vars_cfg.items():
        if k in ['source_code', 'wiki_md']:
            # 文件路径使用 file:// 前缀
            var_args.append(f"--var {k}=file://{v}")
        elif k == 'language':
            # 语言参数特殊处理，不使用 file:// 前缀
            var_args.append(f"--var {k}={v}")
        else:
            # 其他参数直接传递
            var_args.append(f"--var {k}={v}")
    
    # 运行 Stage 1 测试
    output_dir = Path("output/simple_test")
    output_dir.mkdir(parents=True, exist_ok=True)
    stage1_out = output_dir / "stage1.json"
    
    cmd1 = f"promptfoo eval --no-cache --config stage1_fact_extractor.yaml {' '.join(var_args)} --output {stage1_out}"
    print(f"Running command: {cmd1}")
    
    try:
        result1 = subprocess.run(cmd1, shell=True, capture_output=True, text=True, timeout=120)
        if result1.returncode == 0:
            print("V Stage 1 completed successfully!")
            print("Variable passing fix is working correctly.")
            return True
        else:
            print(f"X Stage 1 failed with return code {result1.returncode}")
            print(f"STDOUT: {result1.stdout}")
            print(f"STDERR: {result1.stderr}")
            return False
    except subprocess.TimeoutExpired:
        print("X Stage 1 timed out")
        return False
    except Exception as e:
        print(f"X Error running Stage 1: {e}")
        return False

if __name__ == "__main__":
    success = run_simple_test()
    if success:
        print("\nV Variable passing fix verified successfully!")
    else:
        print("\nX Variable passing fix verification failed!")