"""
简化版评估工具
直接从源码和MD格式的Wiki文档进行评估，一步到位
"""

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path

from src.code_parser import CodeParser
from src.v1_evaluator import V1Evaluator
from src.md_converter import convert_md_to_wiki_json_with_fact_matching


def main():
    """主函数，直接评估源码和MD格式的Wiki文档"""
    parser = argparse.ArgumentParser(description='直接评估源码和MD格式的Wiki文档')
    parser.add_argument('--code', required=True, help='源代码文件路径')
    parser.add_argument('--wiki-md', required=True, help='MD格式的Wiki文档路径')
    parser.add_argument('--output', help='输出结果文件路径（如果不指定，则保存到results目录并以代码文件名命名）')
    parser.add_argument('--results-dir', default='results', help='结果保存目录（默认：results）')
    parser.add_argument('--lang', choices=['python', 'java'], default='python', help='代码语言')
    parser.add_argument('--verbose', '-v', action='store_true', help='显示详细输出')

    args = parser.parse_args()

    # 如果没有指定输出路径，则根据代码文件名生成输出路径
    if not args.output:
        code_filename = Path(args.code).stem
        results_dir = Path(args.results_dir)
        results_dir.mkdir(exist_ok=True)  # 创建结果目录
        args.output = str(results_dir / f"{code_filename}_evaluation.json")
    
    # 创建临时文件来存储提取的事实
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as temp_facts_file:
        temp_facts_path = temp_facts_file.name
    
    try:
        # 1. 解析代码并提取事实
        if args.verbose:
            print(f"正在解析代码文件: {args.code}")
        
        code_parser = CodeParser()
        
        if args.lang == 'python':
            facts = code_parser.parse_python_file(args.code)
        elif args.lang == 'java':
            facts = code_parser.parse_java_file(args.code)
        else:
            print(f"不支持的语言: {args.lang}")
            return
        
        # 保存提取的事实到临时文件
        facts_data = {"facts": facts}
        with open(temp_facts_path, 'w', encoding='utf-8') as f:
            json.dump(facts_data, f, ensure_ascii=False, indent=2)
        
        if args.verbose:
            print(f"成功提取了 {len(facts)} 个事实")
        
        # 2. 从MD格式的Wiki提取claims并匹配事实
        if args.verbose:
            print(f"正在处理Wiki文档: {args.wiki_md}")
        
        # 从代码事实中提取Wiki
        wiki_json = convert_md_to_wiki_json_with_fact_matching(args.wiki_md, facts)
        
        # 临时保存Wiki JSON
        temp_wiki_path = temp_facts_path.replace('_facts.json', '_wiki.json')
        with open(temp_wiki_path, 'w', encoding='utf-8') as f:
            json.dump(wiki_json, f, ensure_ascii=False, indent=2)
        
        # 3. 使用V1评测系统评估
        if args.verbose:
            print("正在进行评估...")
        
        evaluator = V1Evaluator()
        result = evaluator.evaluate_from_data(facts_data, wiki_json)
        
        # 准备输出结果
        output = {
            "metrics": result.metrics,
            "violations": [
                {
                    "claim": v.claim,
                    "reason": v.reason,
                    "violation_type": v.violation_type.value
                } for v in result.violations
            ],
            "pass": result.pass_evaluation,
            "summary": {
                "file": Path(args.code).name,
                "total_claims": len(wiki_json.get("claims", [])),
                "matched_facts": sum(1 for claim in wiki_json.get("claims", []) if claim.get("fact_refs")),
                "unmatched_claims": len([c for c in wiki_json.get("claims", []) if not c.get("fact_refs")])
            }
        }
        
        # 保存结果
        with open(args.output, 'w', encoding='utf-8') as f:
            json.dump(output, f, ensure_ascii=False, indent=2)
        
        if args.verbose:
            print(f"评估完成。结果已保存至: {args.output}")
            print(f"评估通过: {result.pass_evaluation}")
            print(f"信仰度: {result.metrics['faithfulness']:.2f}")
            print(f"幻觉率: {result.metrics['hallucination_rate']:.2f}")
            print(f"关键事实召回率: {result.metrics['key_fact_recall']:.2f}")
            print(f"冗余率: {result.metrics['redundancy_rate']:.2f}")
            
            if result.violations:
                print(f"\n发现 {len(result.violations)} 个违规:")
                for i, violation in enumerate(result.violations[:5]):  # 只显示前5个
                    # 处理可能的编码问题
                    claim = violation.claim.encode('utf-8', errors='replace').decode('utf-8', errors='replace')
                    reason = violation.reason.encode('utf-8', errors='replace').decode('utf-8', errors='replace')
                    print(f"  {i+1}. '{claim}' - {reason}".encode(sys.stdout.encoding, errors='replace').decode(sys.stdout.encoding, errors='replace'))
                if len(result.violations) > 5:
                    print(f"  ... 还有 {len(result.violations) - 5} 个违规未显示".encode(sys.stdout.encoding, errors='replace').decode(sys.stdout.encoding, errors='replace'))
    
    finally:
        # 清理临时文件
        for temp_path in [temp_facts_path, temp_wiki_path]:
            if os.path.exists(temp_path):
                os.unlink(temp_path)


if __name__ == "__main__":
    main()