import sys
import os
sys.path.insert(0, os.path.join(os.getcwd(), 'cli'))

from cli.run_single_case_pipeline import run_single_case

# 测试 CLI 功能
print("Testing CLI functionality...")

result = run_single_case(
    case_id="test_case_1",
    vars_cfg={
        "source_code": "cli/test_data/test_source.py",
        "wiki_md": "cli/test_data/test_wiki.md"
    },
    output_dir="cli/output/test_case_1"
)

print(f"Final score: {result['final_score']}")
print(f"Evaluation result: {result['result']}")
print("CLI test completed successfully!")