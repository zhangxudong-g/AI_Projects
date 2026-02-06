#!/usr/bin/env python3
"""
边界测试用例执行脚本
"""

import json
from pathlib import Path
from run_single_case_pipeline import run_single_case


def run_boundary_tests():
    """运行边界测试"""

    # 创建测试输出目录
    output_base = Path("output/boundary_tests")
    output_base.mkdir(parents=True, exist_ok=True)

    test_cases = [
        {
            "name": "empty_content_test",
            "vars": {
                "source_code": "./test_cases/empty_empty_test.java",
                "wiki_md": "./test_cases/empty_empty_wiki.md",
            },
        },
        {
            "name": "empty_code_with_wiki_test",
            "vars": {
                "source_code": "./test_cases/empty_code_with_wiki.java",
                "wiki_md": "./test_cases/empty_code_with_wiki_wiki.md",
            },
        },
        {
            "name": "code_empty_wiki_test",
            "vars": {
                "source_code": "./test_cases/code_empty_wiki.java",
                "wiki_md": "./test_cases/code_empty_wiki.md",
            },
        },
        {
            "name": "single_line_test",
            "vars": {
                "source_code": "./test_cases/single_line_test.java",
                "wiki_md": "./test_cases/single_line_wiki.md",
            },
        },
        {
            "name": "minimal_test",
            "vars": {
                "source_code": "./test_cases/minimal_test.java",
                "wiki_md": "./test_cases/minimal_wiki.md",
            },
        },
        {
            "name": "perfect_match_test",
            "vars": {
                "source_code": "./test_cases/perfect_match_test.java",
                "wiki_md": "./test_cases/perfect_match_wiki.md",
            },
        },
        {
            "name": "worst_case_test",
            "vars": {
                "source_code": "./test_cases/worst_case_test.java",
                "wiki_md": "./test_cases/worst_case_wiki.md",
            },
        },
        {
            "name": "fake_methods_test",
            "vars": {
                "source_code": "./test_cases/fake_methods_test.java",
                "wiki_md": "./test_cases/fake_methods_wiki.md",
            },
        },
    ]

    results = []

    print("开始运行边界测试...")
    print("=" * 60)

    for i, test_case in enumerate(test_cases, 1):
        print(f"运行测试 {i}/{len(test_cases)}: {test_case['name']}")

        try:
            result = run_single_case(
                case_id=test_case["name"],
                vars_cfg=test_case["vars"],
                output_dir=output_base / test_case["name"],
                base_output="output/boundary_tests",  # 确保base_output是正确的
            )

            result_entry = {
                "test_name": test_case["name"],
                "status": "SUCCESS",
                "final_score": result["final_score"],
                "result": result["result"],
                "details": result["details"],
            }

            print(f"  结果: {result['result']}, 分数: {result['final_score']}")

        except Exception as e:
            print(f"  错误: {str(e)}")
            result_entry = {
                "test_name": test_case["name"],
                "status": "ERROR",
                "error": str(e),
            }

        results.append(result_entry)
        print("-" * 40)

    # 保存测试结果
    results_file = output_base / "boundary_test_results.json"
    with open(results_file, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)

    print(f"\n所有边界测试完成！结果已保存到: {results_file}")

    # 输出摘要
    successful_tests = [r for r in results if r["status"] == "SUCCESS"]
    failed_tests = [r for r in results if r["status"] == "ERROR"]

    print(f"\n测试摘要:")
    print(f"  总计: {len(results)}")
    print(f"  成功: {len(successful_tests)}")
    print(f"  失败: {len(failed_tests)}")

    if successful_tests:
        avg_score = sum(r["final_score"] for r in successful_tests) / len(
            successful_tests
        )
        print(f"  平均分数: {avg_score:.2f}")

    return results


if __name__ == "__main__":
    run_boundary_tests()
