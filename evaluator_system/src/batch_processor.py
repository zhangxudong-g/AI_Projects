"""
批量处理工具 - 从源码和Wiki文档批量生成事实文件
"""

import os
import json
import argparse
from pathlib import Path
from typing import List, Dict, Any

from code_parser import CodeParser
from v1_evaluator import V1Evaluator
from md_converter import convert_md_to_wiki_json_with_fact_matching, find_matching_fact_refs


def find_matching_pairs(source_dir: str, wiki_dir: str) -> List[tuple]:
    """
    查找源码目录和Wiki目录中匹配的文件对
    
    Args:
        source_dir: 源码目录路径
        wiki_dir: Wiki目录路径
        
    Returns:
        匹配的文件对列表 [(source_file, wiki_file), ...]
    """
    source_path = Path(source_dir)
    wiki_path = Path(wiki_dir)
    
    pairs = []
    
    # 遍历源码目录中的所有文件
    for source_file in source_path.rglob('*'):
        if source_file.is_file() and source_file.suffix.lower() in ['.py', '.java', '.js', '.ts', '.cpp', '.c', '.go', '.rs']:
            # 构造对应的Wiki文件名（替换扩展名为.md）
            wiki_file = wiki_path / (source_file.stem + '.md')
            
            if wiki_file.exists():
                pairs.append((str(source_file), str(wiki_file)))
            else:
                # 尝试查找同名但不同扩展名的MD文件
                for md_file in wiki_path.rglob(source_file.stem + '.md'):
                    if md_file.is_file():
                        pairs.append((str(source_file), str(md_file)))
                        break
    
    return pairs


def extract_facts_from_code(code_file: str) -> List[Dict[str, Any]]:
    """
    从代码文件中提取事实
    
    Args:
        code_file: 代码文件路径
        
    Returns:
        提取的事实列表
    """
    parser = CodeParser()
    
    ext = Path(code_file).suffix.lower()
    if ext == '.py':
        return parser.parse_python_file(code_file)
    elif ext == '.java':
        return parser.parse_java_file(code_file)
    else:
        # 对于其他语言，暂时使用Python解析器（可能不准确）
        try:
            return parser.parse_python_file(code_file)
        except:
            print(f"无法解析文件: {code_file}")
            return []


def convert_md_to_wiki_json_with_matching(md_file: str, facts: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    将MD格式的Wiki转换为JSON格式，并尝试匹配事实

    Args:
        md_file: MD文件路径
        facts: 从代码中提取的事实列表

    Returns:
        转换后的Wiki JSON数据
    """
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 提取文件名作为方法名或类名
    stem = Path(md_file).stem

    # 更智能的MD解析：识别代码块、标题、列表等
    lines = content.split('\n')
    claims = []

    i = 0
    while i < len(lines):
        line = lines[i].strip()

        if line.startswith('#'):  # 标题
            title_text = line.lstrip('# ').strip()
            if title_text:
                fact_refs = find_matching_fact_refs(title_text, facts)
                claims.append({
                    "text": title_text,
                    "fact_refs": fact_refs
                })
        elif line.startswith('* ') or line.startswith('- ') or line.startswith('1. '):  # 列表项
            # 处理列表项，可能有多行内容
            list_item = line.lstrip('* -1234567890. ')
            j = i + 1
            # 查找连续的缩进行作为列表项的延续
            while j < len(lines):
                next_line = lines[j]
                if next_line.strip() == "":
                    j += 1
                    continue
                # 检查是否是缩进的行（作为当前列表项的补充）
                if len(next_line) - len(next_line.lstrip()) > 0:
                    list_item += " " + next_line.strip()
                    j += 1
                else:
                    break
            fact_refs = find_matching_fact_refs(list_item, facts)
            claims.append({
                "text": list_item.strip(),
                "fact_refs": fact_refs
            })
            i = j - 1  # 跳过已处理的行
        elif line and not line.startswith('```') and not line.startswith('>'):
            # 普通段落，可能跨越多行
            paragraph = line
            j = i + 1
            while j < len(lines):
                next_line = lines[j].strip()
                if next_line == "":
                    break
                elif next_line.startswith('#') or next_line.startswith('* ') or next_line.startswith('- ') or next_line.startswith('1. ') or next_line.startswith('```'):
                    break
                else:
                    paragraph += " " + next_line
                    j += 1
            if paragraph.strip():
                fact_refs = find_matching_fact_refs(paragraph, facts)
                claims.append({
                    "text": paragraph.strip(),
                    "fact_refs": fact_refs
                })
            i = j - 1  # 跳过已处理的行

        i += 1

    # 过滤掉空的claims
    claims = [claim for claim in claims if claim["text"].strip()]

    return {
        "method": stem,
        "claims": claims
    }


def main():
    """主函数，批量处理源码和Wiki文件"""
    parser = argparse.ArgumentParser(description='批量处理源码和Wiki文档，生成事实文件')
    parser.add_argument('--source-dir', required=True, help='源码目录路径')
    parser.add_argument('--wiki-dir', required=True, help='Wiki目录路径')
    parser.add_argument('--output-dir', required=True, help='输出facts目录路径')
    parser.add_argument('--eval-output-dir', help='可选：评估结果输出目录')
    parser.add_argument('--verbose', '-v', action='store_true', help='显示详细输出')
    
    args = parser.parse_args()
    
    # 创建输出目录
    os.makedirs(args.output_dir, exist_ok=True)
    
    if args.eval_output_dir:
        os.makedirs(args.eval_output_dir, exist_ok=True)
    
    # 查找匹配的文件对
    pairs = find_matching_pairs(args.source_dir, args.wiki_dir)
    
    if not pairs:
        print("未找到匹配的源码和Wiki文件对")
        return
    
    if args.verbose:
        print(f"找到 {len(pairs)} 个匹配的文件对:")
        for source_file, wiki_file in pairs:
            print(f"  {source_file} <-> {wiki_file}")
    
    # 处理每个文件对
    processed_count = 0
    for source_file, wiki_file in pairs:
        try:
            if args.verbose:
                print(f"\n处理文件对: {source_file} <-> {wiki_file}")
            
            # 从源码中提取事实
            facts = extract_facts_from_code(source_file)
            
            # 生成输出文件名
            output_filename = Path(source_file).stem + '_facts.json'
            output_path = os.path.join(args.output_dir, output_filename)
            
            # 保存事实
            output_data = {"facts": facts}
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(output_data, f, ensure_ascii=False, indent=2)
            
            if args.verbose:
                print(f"  事实已保存到: {output_path}")
                print(f"  提取了 {len(facts)} 个事实")
            
            # 如果指定了评估输出目录，则同时进行评估
            if args.eval_output_dir:
                # 将MD转换为Wiki JSON格式，并匹配事实
                wiki_json = convert_md_to_wiki_json_with_matching(wiki_file, facts)

                # 临时保存Wiki JSON
                wiki_json_path = output_path.replace('_facts.json', '_wiki.json')
                with open(wiki_json_path, 'w', encoding='utf-8') as f:
                    json.dump(wiki_json, f, ensure_ascii=False, indent=2)

                # 使用V1评测系统评估
                evaluator = V1Evaluator()
                result = evaluator.evaluate_from_data(output_data, wiki_json)

                # 生成评估结果文件名
                eval_output_filename = Path(source_file).stem + '_evaluation.json'
                eval_output_path = os.path.join(args.eval_output_dir, eval_output_filename)

                # 准备评估结果
                eval_output = {
                    "metrics": result.metrics,
                    "violations": [
                        {
                            "claim": v.claim,
                            "reason": v.reason,
                            "violation_type": v.violation_type.value
                        } for v in result.violations
                    ],
                    "pass": result.pass_evaluation
                }

                # 保存评估结果
                with open(eval_output_path, 'w', encoding='utf-8') as f:
                    json.dump(eval_output, f, ensure_ascii=False, indent=2)

                if args.verbose:
                    print(f"  评估结果已保存到: {eval_output_path}")
                    print(f"  评估通过: {result.pass_evaluation}")
                    print(f"  信仰度: {result.metrics['faithfulness']:.2f}")
                    print(f"  幻觉率: {result.metrics['hallucination_rate']:.2f}")
            
            processed_count += 1
            
        except Exception as e:
            print(f"处理文件对时出错: {source_file} <-> {wiki_file}")
            print(f"错误: {str(e)}")
    
    print(f"\n处理完成。成功处理了 {processed_count} 个文件对。")


if __name__ == "__main__":
    main()