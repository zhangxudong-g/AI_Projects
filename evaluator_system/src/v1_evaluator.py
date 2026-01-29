"""
V1 评测系统 - 验证 Wiki 是否忠实转述已解析事实
实现 PRD 中定义的核心规则校验逻辑
"""

import json
from typing import Dict, List, Any, Tuple
from dataclasses import dataclass
from enum import Enum
try:
    from .io_handler import IOHandler
except ImportError:
    from io_handler import IOHandler  # 用于直接运行脚本的情况


class ViolationType(Enum):
    """违规类型枚举"""
    INVALID_REF = "invalid_ref"          # 无效的事实引用
    MISSING_FACT = "missing_fact"        # 缺失事实
    OVER_INFERENCE = "over_inference"    # 越权推断
    REDUNDANCY = "redundancy"            # 冗余


@dataclass
class Violation:
    """违规记录"""
    claim: str
    reason: str
    violation_type: ViolationType


@dataclass
class EvaluationResult:
    """评测结果"""
    metrics: Dict[str, float]
    violations: List[Violation]
    pass_evaluation: bool


class V1Evaluator:
    """V1 评测系统核心类"""

    def __init__(self):
        # 越权推断黑名单词汇
        self.over_inference_keywords = {
            "确保", "保证", "防止", "避免", "提升性能", "优化", "改进",
            "提高", "增强", "加强", "实现", "达到", "完成", "解决",
            "满足", "符合", "适应", "应对", "管理", "控制"
        }

        # 语义对齐映射
        self.semantic_alignment = {
            "calls": ["调用", "执行", "启动", "触发", "发起", "进行", "校验"],
            "writes": ["写入", "更新", "修改", "保存", "存储", "变更"],
            "annotations": ["声明", "标注", "标记", "注解", "添加", "使用"],
            "conditions": ["条件", "判断", "检查", "验证", "当", "时执行"]
        }

    def validate_fact_references(self, claims: List[Dict], facts: List[Dict]) -> List[Violation]:
        """F1: 校验Claim是否包含合法fact_ref"""
        violations = []

        # 创建事实ID集合便于查找
        fact_ids = set()
        for fact in facts:
            fact_ids.add(fact.get('id'))
            # 添加可能的引用格式
            if 'calls' in fact:
                for call in fact['calls']:
                    fact_ids.add(f'calls:{call}')
            if 'writes' in fact:
                for write in fact['writes']:
                    fact_ids.add(f'writes:{write}')
            if 'annotations' in fact:
                for annotation in fact['annotations']:
                    fact_ids.add(f'annotations:{annotation}')
            if 'conditions' in fact:
                for condition in fact['conditions']:
                    fact_ids.add(f'conditions:{condition}')

        for claim in claims:
            text = claim.get('text', '')
            refs = claim.get('fact_refs', [])

            if not refs:
                violations.append(Violation(
                    claim=text,
                    reason="Claim缺少fact_ref",
                    violation_type=ViolationType.MISSING_FACT
                ))
                continue

            for ref in refs:
                if ref not in fact_ids:
                    violations.append(Violation(
                        claim=text,
                        reason=f"无效的事实引用: {ref}",
                        violation_type=ViolationType.INVALID_REF
                    ))

        return violations

    def check_semantic_alignment(self, claims: List[Dict], facts: List[Dict]) -> List[Violation]:
        """F2: 校验Claim与Fact的语义对齐"""
        violations = []

        for claim in claims:
            text = claim.get('text', '')
            refs = claim.get('fact_refs', [])

            # 检查每个引用的语义对齐
            for ref in refs:
                if ':' in ref:
                    ref_type, ref_value = ref.split(':', 1)

                    # 检查文本是否包含正确的语义词汇
                    aligned = False
                    if ref_type in self.semantic_alignment:
                        for keyword in self.semantic_alignment[ref_type]:
                            if keyword in text:
                                aligned = True
                                break

                    if not aligned:
                        violations.append(Violation(
                            claim=text,
                            reason=f"语义不对齐: {ref_type} 类型应包含对应语义词汇",
                            violation_type=ViolationType.MISSING_FACT
                        ))

        return violations

    def detect_over_inference(self, claims: List[Dict]) -> List[Violation]:
        """F3: 检测越权推断"""
        violations = []

        for claim in claims:
            text = claim.get('text', '')

            for keyword in self.over_inference_keywords:
                if keyword in text:
                    violations.append(Violation(
                        claim=text,
                        reason=f"检测到越权推断关键词: {keyword}",
                        violation_type=ViolationType.OVER_INFERENCE
                    ))
                    # 注意：这里不break，因为一个声明可能包含多个越权推断关键词

        return violations

    def calculate_key_fact_recall(self, claims: List[Dict], facts: List[Dict]) -> float:
        """F4: 计算关键事实覆盖率"""
        if not facts:
            return 1.0 if not claims else 0.0

        # 收集所有关键事实
        key_facts = set()
        for fact in facts:
            if 'calls' in fact:
                for call in fact['calls']:
                    key_facts.add(f'calls:{call}')
            if 'writes' in fact:
                for write in fact['writes']:
                    key_facts.add(f'writes:{write}')
            if 'annotations' in fact:
                for annotation in fact['annotations']:
                    key_facts.add(f'annotations:{annotation}')
            if 'conditions' in fact:
                for condition in fact['conditions']:
                    key_facts.add(f'conditions:{condition}')

        # 如果没有关键事实，则认为完全覆盖
        if not key_facts:
            return 1.0

        # 检查哪些关键事实在claims中被引用了
        referenced_facts = set()
        for claim in claims:
            refs = claim.get('fact_refs', [])
            for ref in refs:
                if ref in key_facts:
                    referenced_facts.add(ref)

        # 计算召回率
        recall = len(referenced_facts) / len(key_facts) if key_facts else 1.0
        return recall

    def detect_redundancy(self, claims: List[Dict]) -> List[Violation]:
        """F5: 检测冗余与噪声"""
        violations = []

        for claim in claims:
            text = claim.get('text', '')
            refs = claim.get('fact_refs', [])

            # 简单的冗余检测：如果文本很短且没有明确的事实增量，则认为是冗余
            if len(text.strip()) < 5 and len(refs) == 0:
                violations.append(Violation(
                    claim=text,
                    reason="文本过短且无事实引用，可能是冗余内容",
                    violation_type=ViolationType.REDUNDANCY
                ))
            elif len(set(text)) < 5:  # 字符种类太少，可能是重复或无意义内容
                violations.append(Violation(
                    claim=text,
                    reason="文本字符种类过少，可能是冗余内容",
                    violation_type=ViolationType.REDUNDANCY
                ))

        return violations

    def evaluate_from_files(self, facts_file_path: str, wiki_file_path: str) -> EvaluationResult:
        """从文件路径执行评测"""
        io_handler = IOHandler()

        # 加载并验证输入文件
        facts_data = io_handler.load_json_file(facts_file_path)
        wiki_data = io_handler.load_json_file(wiki_file_path)

        if not io_handler.validate_facts_format(facts_data):
            raise ValueError(f"Invalid facts format in {facts_file_path}")

        if not io_handler.validate_wiki_format(wiki_data):
            raise ValueError(f"Invalid wiki format in {wiki_file_path}")

        return self.evaluate_from_data(facts_data, wiki_data)

    def evaluate_from_data(self, facts_data: Dict[str, Any], wiki_data: Dict[str, Any]) -> EvaluationResult:
        """从数据对象执行评测"""
        facts = facts_data.get('facts', [])
        claims = wiki_data.get('claims', [])

        all_violations = []

        # 执行各项检查
        all_violations.extend(self.validate_fact_references(claims, facts))
        all_violations.extend(self.check_semantic_alignment(claims, facts))
        all_violations.extend(self.detect_over_inference(claims))
        all_violations.extend(self.detect_redundancy(claims))

        # 计算各项指标
        total_claims = len(claims) if claims else 1  # 避免除零错误
        valid_claims = total_claims - len([v for v in all_violations if v.violation_type != ViolationType.REDUNDANCY])

        faithfulness = valid_claims / total_claims if total_claims > 0 else 1.0
        hallucination_rate = len([v for v in all_violations if v.violation_type == ViolationType.OVER_INFERENCE]) / total_claims if total_claims > 0 else 0.0
        key_fact_recall = self.calculate_key_fact_recall(claims, facts)
        redundancy_rate = len([v for v in all_violations if v.violation_type == ViolationType.REDUNDANCY]) / total_claims if total_claims > 0 else 0.0

        metrics = {
            "faithfulness": faithfulness,
            "hallucination_rate": hallucination_rate,
            "key_fact_recall": key_fact_recall,
            "redundancy_rate": redundancy_rate
        }

        # 判断是否通过评测
        pass_evaluation = (
            faithfulness >= 0.95 and
            hallucination_rate <= 0.0 and  # 严格要求零幻觉
            key_fact_recall >= 0.85 and
            redundancy_rate <= 0.15
        )

        return EvaluationResult(
            metrics=metrics,
            violations=all_violations,
            pass_evaluation=pass_evaluation
        )

    def evaluate(self, facts_json: str, wiki_json: str) -> EvaluationResult:
        """执行完整评测（兼容旧版接口）"""
        io_handler = IOHandler()
        facts_data = io_handler.load_json_string(facts_json)
        wiki_data = io_handler.load_json_string(wiki_json)

        return self.evaluate_from_data(facts_data, wiki_data)


def main():
    """主函数，用于直接运行评测"""
    import argparse

    parser = argparse.ArgumentParser(description='V1 评测系统')
    parser.add_argument('--facts', required=True, help='facts.json 文件路径')
    parser.add_argument('--wiki', required=True, help='wiki.json 文件路径')
    parser.add_argument('--out', required=True, help='输出结果文件路径')

    args = parser.parse_args()

    evaluator = V1Evaluator()

    result = evaluator.evaluate_from_files(args.facts, args.wiki)

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
        "pass": result.pass_evaluation
    }

    io_handler = IOHandler()
    io_handler.save_evaluation_result(output, args.out)

    print(f"Evaluation completed. Result saved to {args.out}")
    print(f"Pass: {result.pass_evaluation}")


if __name__ == "__main__":
    main()