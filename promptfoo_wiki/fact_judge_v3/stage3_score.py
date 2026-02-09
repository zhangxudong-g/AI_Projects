from typing import Dict, Any


def clamp(v: float, min_v: float = 0, max_v: float = 100) -> float:
    return max(min_v, min(max_v, v))


# =========================
# 分辨率增强工具
# =========================
def snap_to_band(score: float) -> int:
    """
    将分数吸附到工程友好的离散档位
    （仅用于最终展示，不参与规则判断）
    """
    bands = [10, 20, 30, 40, 50, 60, 70, 80, 90, 95]
    return min(bands, key=lambda b: abs(b - score))


# =========================
# Risk-aware Final Scoring v3.1
# =========================
def final_score(stage2: Dict[str, Any]) -> Dict[str, Any]:
    """
    Engineering Judge v3.1
    分辨率增强版（回归安全）
    """

    # =========================
    # 0. 防御性读取
    # =========================
    comprehension_support = stage2.get("comprehension_support", "LOW")
    engineering_usefulness = stage2.get("engineering_usefulness", "LOW")
    explanation_reasonableness = stage2.get("explanation_reasonableness", "LOW")
    abstraction_quality = stage2.get("abstraction_quality", "POOR")
    fabrication_risk = stage2.get("fabrication_risk", "HIGH")
    fabrication_type = stage2.get("fabrication_type", "NONE")
    summary = stage2.get("summary", "")

    # v3.1 新增（可选）
    critical_fact_error = stage2.get("critical_fact_error", False)

    # =========================
    # 1. Law 1: ARCHITECTURAL Fabrication（硬覆盖）
    # =========================
    if fabrication_type == "ARCHITECTURAL":
        explanation_reasonableness = "LOW"
        fabrication_risk = "HIGH"

    # =========================
    # 2. 基础分映射（v3 原样）
    # =========================
    score = 0

    score += {
        "HIGH": 25,
        "MEDIUM": 15,
        "LOW": 5,
    }.get(comprehension_support, 5)

    score += {
        "HIGH": 35,
        "MEDIUM": 20,
        "LOW": 5,
    }.get(engineering_usefulness, 5)

    score += {
        "HIGH": 20,
        "MEDIUM": 12,
        "LOW": 4,
    }.get(explanation_reasonableness, 4)

    score += {
        "GOOD": 20,
        "OK": 12,
        "POOR": 4,
    }.get(abstraction_quality, 4)

    # =========================
    # 3. 风险扣分（v3 原样）
    # =========================
    risk_penalty = 0
    if fabrication_risk == "HIGH":
        risk_penalty = 40
    elif fabrication_risk == "MEDIUM":
        risk_penalty = 20

    raw_score = clamp(score - risk_penalty, min_v=10, max_v=95)

    # =========================
    # 4. 法律 / 封顶 / 奖励层（先于 snap）
    # =========================
    final_score_value = raw_score

    # Law 2: Abstraction Mismatch 封顶
    abstraction_mismatch = (
        explanation_reasonableness == "HIGH"
        and fabrication_risk == "LOW"
        and abstraction_quality in ["OK", "POOR"]
    )

    if abstraction_mismatch:
        final_score_value = min(final_score_value, 50)

    # 真实性奖励（不能覆盖 abstraction mismatch）
    if (
        explanation_reasonableness == "HIGH"
        and fabrication_risk == "LOW"
        and not abstraction_mismatch
    ):
        final_score_value = max(final_score_value, 60)

    # 关键事实错误上限
    if critical_fact_error:
        final_score_value = min(final_score_value, 40)

    # =========================
    # 5. 分辨率增强（最终展示层）
    # =========================
    final_score_value = snap_to_band(final_score_value)

    # =========================
    # 6. FAIL 判定（极小化）
    # =========================
    if fabrication_risk == "HIGH" and explanation_reasonableness == "LOW":
        result = "FAIL"
    else:
        result = "PASS"

    # =========================
    # 7. 输出
    # =========================
    return {
        "final_score": final_score_value,
        "result": result,
        "summary": summary,
        "details": {
            "comprehension_support": comprehension_support,
            "engineering_usefulness": engineering_usefulness,
            "explanation_reasonableness": explanation_reasonableness,
            "abstraction_quality": abstraction_quality,
            "fabrication_risk": fabrication_risk,
            "fabrication_type": fabrication_type,
            "critical_fact_error": critical_fact_error,
            "abstraction_mismatch": abstraction_mismatch,
        },
    }
