from typing import Dict, Any


def clamp(v: float, min_v: float = 0, max_v: float = 100) -> float:
    normalized = round(v / 85 * 100, 1)
    return max(min_v, min(max_v, normalized))


# =========================
# 主打分函数
# =========================
def final_score(stage2: Dict[str, Any]) -> Dict[str, Any]:
    """
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
            "hallucination_level": hallucination_level
        },
    }
