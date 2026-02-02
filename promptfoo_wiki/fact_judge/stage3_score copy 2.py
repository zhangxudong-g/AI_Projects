# stage3_score.py
from typing import Dict, Any

# =========================
# 等级 → 分数 / 惩罚 映射
# =========================

COVERAGE_SCORE = {
    "HIGH": 40,
    "MEDIUM": 25,
    "LOW": 10,
}

USEFULNESS_SCORE = {
    "HIGH": 40,
    "MEDIUM": 25,
    "LOW": 10,
}

CORRECTNESS_PENALTY = {
    "GOOD": 0,
    "MINOR_ISSUES": 10,
    "BAD": 20,
}

HALLUCINATION_PENALTY = {
    "NONE": 0,
    "MINOR": 10,
    "SEVERE": 40,
}


# =========================
# 工具函数
# =========================

def _safe_get(mapping: Dict[str, int], key: str, default: int = 0) -> int:
    """防御式读取，避免 KeyError"""
    if key not in mapping:
        return default
    return mapping[key]


def _normalize_hallucination(stage2: Dict[str, Any]) -> None:
    """
    保证 hallucination_level 与 hallucination list 语义一致
    """
    level = stage2.get("hallucination_level")
    items = stage2.get("hallucination", [])

    if level == "SEVERE" and not items:
        stage2["hallucination_level"] = "NONE"


def _sanitize_summary(summary: str) -> str:
    """
    禁止出现“insufficient input / missing source”等逃生话术
    """
    forbidden_phrases = [
        "insufficient input",
        "missing source",
        "not enough information",
        "cannot be evaluated",
        "without the source",
    ]

    lowered = summary.lower()
    for phrase in forbidden_phrases:
        if phrase in lowered:
            return (
                "The documentation quality is insufficient to guide a new developer."
            )

    return summary


# =========================
# 主打分函数
# =========================

def final_score(stage1: Dict[str, Any], stage2: Dict[str, Any]) -> Dict[str, Any]:
    """
    输入：
      - stage1: 覆盖率等定量信息
      - stage2: LLM 定性判断结果

    输出：
      - 最终可用的评测结果（0～100）
    """

    # --------
    # 兜底修正
    # --------
    _normalize_hallucination(stage2)

    coverage_level = stage2.get("coverage_level", "LOW")
    usefulness_level = stage2.get("usefulness_level", "LOW")
    correctness_level = stage2.get("correctness_level", "BAD")
    hallucination_level = stage2.get("hallucination_level", "NONE")

    # --------
    # 基础分
    # --------
    score = 0

    score += _safe_get(COVERAGE_SCORE, coverage_level)
    score += _safe_get(USEFULNESS_SCORE, usefulness_level)

    # --------
    # 惩罚项
    # --------
    score -= _safe_get(CORRECTNESS_PENALTY, correctness_level)
    score -= _safe_get(HALLUCINATION_PENALTY, hallucination_level)

    # --------
    # Coverage rate 轻微加权（防止 LOW 被完全吃掉）
    # --------
    coverage_rate = stage1.get("coverage", {}).get("rate")
    if isinstance(coverage_rate, (int, float)):
        score += coverage_rate * 10  # 最多 +10

    # --------
    # 最终裁剪
    # --------
    score = round(max(min(score, 100), 0), 2)

    # --------
    # Summary 清洗
    # --------
    summary = _sanitize_summary(stage2.get("summary", ""))

    return {
        "final_score": score,
        "result": "PASS" if score >= 60 else "FAIL",
        "summary": summary,
        "details": {
            "coverage_level": coverage_level,
            "usefulness_level": usefulness_level,
            "correctness_level": correctness_level,
            "hallucination_level": hallucination_level,
            "coverage_rate": coverage_rate,
        },
    }
