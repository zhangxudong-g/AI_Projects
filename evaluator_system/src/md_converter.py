"""
改进的MD到Wiki JSON转换器
尝试匹配代码事实并创建适当的引用
"""

import re
from pathlib import Path
from typing import List, Dict, Any


def convert_md_to_wiki_json_with_fact_matching(md_file: str, facts: List[Dict[str, Any]]) -> Dict[str, Any]:
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


def find_matching_fact_refs(text: str, facts: List[Dict[str, Any]]) -> list:
    """
    根据文本内容查找匹配的事实引用

    Args:
        text: 要分析的文本
        facts: 事实列表

    Returns:
        匹配的事实引用列表
    """
    fact_refs = []

    # 检查文本中是否包含任何事实中的调用、写入、注解或条件
    for fact in facts:
        # 检查调用 - 使用更宽松的匹配策略
        for call in fact.get('calls', []):
            # 尝试多种匹配方式
            if call.lower() in text.lower():
                fact_refs.append(f"calls:{call}")
            else:
                # 如果调用包含点号（如 self.auth_service.validate），尝试匹配最后一部分
                if '.' in call:
                    call_parts = call.split('.')
                    last_part = call_parts[-1]  # 如 'validate'
                    if last_part.lower() in text.lower():
                        fact_refs.append(f"calls:{call}")
                    # 尝试匹配中间部分
                    for part in call_parts[1:]:  # 跳过第一个部分（通常是self）
                        if part.lower() in text.lower():
                            fact_refs.append(f"calls:{call}")
                            break

        # 检查写入
        for write in fact.get('writes', []):
            if write.lower() in text.lower():
                fact_refs.append(f"writes:{write}")
            else:
                # 如果写入包含点号，尝试匹配最后一部分
                if '.' in write:
                    write_parts = write.split('.')
                    last_part = write_parts[-1]
                    if last_part.lower() in text.lower():
                        fact_refs.append(f"writes:{write}")

        # 检查注解
        for annotation in fact.get('annotations', []):
            if annotation.lower() in text.lower():
                fact_refs.append(f"annotations:{annotation}")

        # 检查条件
        for condition in fact.get('conditions', []):
            # 移除括号和常见关键字进行匹配
            clean_condition = re.sub(r'[()]', '', condition.lower())
            if clean_condition in text.lower() or condition.lower() in text.lower():
                fact_refs.append(f"conditions:{condition}")

    # 去重
    fact_refs = list(set(fact_refs))

    return fact_refs