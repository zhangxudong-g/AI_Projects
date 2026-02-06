from typing import Dict, Any


def clamp(v: float, min_v: float = 0, max_v: float = 100) -> float:
    # 限制分数在0-100范围内
    return max(min_v, min(max_v, v))


# =========================
# Risk-aware 打分函数
# =========================
def final_score(stage2: Dict[str, Any]) -> Dict[str, Any]:
    """
    stage2: engineering assessment for Engineering Judge v2

    stage2 expected keys:
      - comprehension_support: HIGH | MEDIUM | LOW
      - engineering_usefulness: HIGH | MEDIUM | LOW
      - explanation_reasonableness: HIGH | MEDIUM | LOW
      - abstraction_quality: GOOD | OK | POOR
      - fabrication_risk: LOW | MEDIUM | HIGH
      - summary: str
    """

    # =========================
    # 0. 防御性读取（不会 KeyError）
    # =========================
    comprehension_support = stage2.get("comprehension_support", "LOW")
    engineering_usefulness = stage2.get("engineering_usefulness", "LOW")
    explanation_reasonableness = stage2.get("explanation_reasonableness", "LOW")
    abstraction_quality = stage2.get("abstraction_quality", "POOR")
    fabrication_risk = stage2.get("fabrication_risk", "HIGH")
    summary = stage2.get("summary", "")

    # =========================
    # 2. Scoring v2 评分逻辑（去硬 FAIL）
    # =========================
    # 基础分
    score = 0

    # 各项权重分配（总分100分）
    usefulness_points = 35  # comprehension_support和engineering_usefulness各占一部分
    comprehension_points = 25
    explanation_reasonableness_points = 20
    abstraction_quality_points = 20

    # 分数映射
    comprehension_scores = {
        "HIGH": 25,
        "MEDIUM": 15,
        "LOW": 5,
    }

    usefulness_scores = {
        "HIGH": 35,
        "MEDIUM": 20,
        "LOW": 5,
    }

    explanation_reasonableness_scores = {
        "HIGH": 20,
        "MEDIUM": 12,
        "LOW": 4,
    }

    abstraction_quality_scores = {
        "GOOD": 20,
        "OK": 12,
        "POOR": 4,
    }

    # 计算基础分数
    score += comprehension_scores.get(comprehension_support, 5)
    score += usefulness_scores.get(engineering_usefulness, 5)
    score += explanation_reasonableness_scores.get(explanation_reasonableness, 4)
    score += abstraction_quality_scores.get(abstraction_quality, 4)

    # 风险扣分
    risk_penalty = 0
    if fabrication_risk == "HIGH":
        risk_penalty = 40
    elif fabrication_risk == "MEDIUM":
        risk_penalty = 20
    # LOW 风险不扣分

    # 应用风险扣分
    final_score_value = max(0, score - risk_penalty)  # 确保分数不低于0

    # FAIL 条件（极小化）：只有在高风险且解释不合理的情况下才FAIL
    if fabrication_risk == "HIGH" and explanation_reasonableness == "LOW":
        result = "FAIL"
    else:
        result = "PASS"

    # =========================
    # 3. 输出（给人 + 给机器都好用）
    # =========================
    return {
        "final_score": round(final_score_value, 2),
        "result": result,
        "summary": summary,
        "details": {
            "comprehension_support": comprehension_support,
            "engineering_usefulness": engineering_usefulness,
            "explanation_reasonableness": explanation_reasonableness,
            "abstraction_quality": abstraction_quality,
            "fabrication_risk": fabrication_risk
        },
    }
