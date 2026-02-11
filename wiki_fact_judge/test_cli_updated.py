import sys
import os
import subprocess
from pathlib import Path

# 切换到 cli 目录
original_cwd = os.getcwd()
cli_dir = os.path.join(original_cwd, 'cli')
os.chdir(cli_dir)

# 添加 cli 目录到 Python 路径
sys.path.insert(0, cli_dir)

try:
    from run_single_case_pipeline import run_single_case

    # 测试 CLI 功能
    print("Testing CLI functionality...")

    result = run_single_case(
        case_id="test_case_1",
        vars_cfg={
            "source_code": "test_data/test_source.py",
            "wiki_md": "test_data/test_wiki.md"
        },
        output_dir="output/test_case_1"
    )

    print(f"Final score: {result['final_score']}")
    print(f"Evaluation result: {result['result']}")
    print("CLI test completed successfully!")

finally:
    # 恢复原始工作目录
    os.chdir(original_cwd)