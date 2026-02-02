from typing import Dict, Any


def clamp(v: float, min_v: float = 0, max_v: float = 100) -> float:
    normalized = round(v / 85 * 100, 1)
    return max(min_v, min(max_v, normalized))


# =========================
# 主打分函数
# =========================
def final_score(stage1: Dict[str, Any], stage2: Dict[str, Any]) -> Dict[str, Any]:
    """
    stage1: fact-level extraction result (coverage facts, hallucination list, etc.)
    stage2: soft-judge qualitative assessment

    stage2 expected keys:
      - coverage_level: HIGH | MEDIUM | LOW
      - correctness_level: GOOD | MINOR_ISSUES | BAD
      - hallucination_level: NONE | MINOR | SEVERE
      - usefulness_level: HIGH | MEDIUM | LOW
      - summary: str
    """

    # =========================
    # 0. 防御性读取（不会 KeyError）
    # =========================
    coverage_level = stage2.get("coverage_level", "LOW")
    usefulness_level = stage2.get("usefulness_level", "LOW")
    correctness_level = stage2.get("correctness_level", "GOOD")
    hallucination_level = stage2.get("hallucination_level", "NONE")
    summary = stage2.get("summary", "")

    # =========================
    # 1. 基础分（安全但没用 ≠ 0 分）
    # =========================
    score = 30

    # =========================
    # 2. Coverage & Usefulness 加分
    # =========================
    coverage_bonus = {
        "HIGH": 30,
        "MEDIUM": 20,
        "LOW": 10,
    }

    usefulness_bonus = {
        "HIGH": 25,
        "MEDIUM": 15,
        "LOW": 5,
    }

    score += usefulness_bonus.get(usefulness_level, 0)

    # =========================
    # 3. Correctness 惩罚（非常重要）
    # =========================
    correctness_penalty = {
        "GOOD": 0,
        "MINOR_ISSUES": -10,
        "BAD": -40,
    }

    score += correctness_penalty.get(correctness_level, -40)

    # =========================
    # 4. Hallucination 惩罚（硬门槛）
    # =========================
    hallucination_penalty = {
        "NONE": 0,
        "MINOR": -10,
        "SEVERE": -50,
    }

    score += hallucination_penalty.get(hallucination_level, -50)

    # =========================
    # 5. Stage1 轻量校正（不主导，只兜底）
    # =========================
    coverage_rate = None
    try:
        total_items = stage1.get("coverage", {}).get("total_items")
        covered_items = stage1.get("coverage", {}).get("covered_items")
        if total_items and covered_items is not None:
            coverage_rate = covered_items / max(total_items, 1)
            # 极低 factual 覆盖，轻微降权
            # if coverage_rate < 0.2:
            #     score -= 5
    except Exception:
        pass  # 永不因为 stage1 异常翻车

    if coverage_rate < 0.3:
        coverage_level = "LOW"
    elif coverage_rate < 0.6:
        coverage_level = "MEDIUM"
    else:
        coverage_level = "HIGH"

    score += coverage_bonus.get(coverage_level, 0)
    # =========================
    # 6. 分数收敛
    # =========================
    final = round(clamp(score), 2)

    # =========================
    # 7. PASS / FAIL 判定（稳定规则）
    # =========================
    if hallucination_level == "SEVERE" or correctness_level == "BAD" or final < 60:
        result = "FAIL"
    else:
        result = "PASS"

    # =========================
    # 8. 输出（给人 + 给机器都好用）
    # =========================
    return {
        "final_score": final,
        "result": result,
        "summary": summary,
        "details": {
            "coverage_level": coverage_level,
            "usefulness_level": usefulness_level,
            "correctness_level": correctness_level,
            "hallucination_level": hallucination_level,
            "coverage_rate": (
                round(coverage_rate, 3) if coverage_rate is not None else None
            ),
        },
    }
