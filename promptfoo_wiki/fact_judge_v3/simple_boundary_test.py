#!/usr/bin/env python3
"""
简化边界测试
"""

import json
from pathlib import Path
from run_single_case_pipeline import run_single_case

def run_simple_boundary_test():
    """运行简化边界测试"""
    
    # 创建测试输出目录
    output_base = Path("output/simple_boundary_test")
    output_base.mkdir(parents=True, exist_ok=True)
    
    # 测试空内容
    test_case = {
        "name": "empty_content_test",
        "vars": {
            "source_code": "./test_cases/empty_empty_test.java",
            "wiki_md": "./test_cases/empty_empty_wiki.md"
        }
    }
    
    print("运行简化边界测试...")
    print(f"测试: {test_case['name']}")
    
    try:
        result = run_single_case(
            case_id=test_case["name"],
            vars_cfg=test_case["vars"],
            output_dir=output_base / test_case["name"]
        )
        
        print(f"✅ 测试成功!")
        print(f"  结果: {result['result']}")
        print(f"  分数: {result['final_score']}")
        print(f"  详情: {json.dumps(result['details'], indent=2, ensure_ascii=False)}")
        
        return True
        
    except Exception as e:
        print(f"❌ 测试失败: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = run_simple_boundary_test()
    if success:
        print("\n✅ 简化边界测试通过！")
    else:
        print("\n❌ 简化边界测试失败！")