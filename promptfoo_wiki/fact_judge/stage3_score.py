import json
from pathlib import Path

LEVEL_SCORE = {
    "HIGH": 1.0,
    "MEDIUM": 0.6,
    "LOW": 0.3,
}

CORRECTNESS_PENALTY = {
    "GOOD": 0,
    "MINOR_ISSUES": 5,
    "WRONG": 20,
}

HALLUCINATION_PENALTY = {
    "NONE": 0,
    "MINOR": 10,
    "SEVERE": 40,
}


def final_score(stage1, stage2):
    print("[Stage3] Scoring...")
    # print(f"  Stage1 data: {json.dumps(stage1, indent=2, ensure_ascii=False)}")
    # print(f"  Stage2 data: {json.dumps(stage2, indent=2, ensure_ascii=False)}")
    # =========================
    # 1. 从 Stage1 取基础事实
    # =========================
    facts = stage1
    coverage = facts["coverage"]
    coverage_rate = coverage["covered_items"] / coverage["total_items"]

    score = 0
    score += coverage_rate * 40
    score += LEVEL_SCORE[stage2["usefulness_level"]] * 30
    score += LEVEL_SCORE[stage2["coverage_level"]] * 20

    score -= CORRECTNESS_PENALTY[stage2["correctness_level"]]
    score -= HALLUCINATION_PENALTY[stage2["hallucination_level"]]

    score = round(max(score, 0), 2)
    correctness = facts["correctness"]
    hallucination = facts.get("hallucination", [])
    correctness_penalty = correctness["wrong_count"]
    return {
        "final_score": score,
        "result": "PASS" if score >= 60 else "FAIL",
        "summary": stage2["notes"],
        "details": {
            "coverage_rate": round(coverage_rate, 3),
            "usefulness_level": stage2["usefulness_level"],
            "coverage_level": stage2["coverage_level"],
            "correctness_level": stage2["correctness_level"],
            "hallucination_level": stage2["hallucination_level"],
            "correctness_wrong": correctness_penalty,
            "coverage": coverage,
            "correctness": correctness,
            "hallucination": hallucination,
        },
    }


# 临时不用这个函数了
def score(stage1: dict, stage2: dict) -> dict:
    """
    Stage3:
    - 读取 Stage1（fact extractor 的硬事实）
    - 读取 Stage2（soft judge 的判断）
    - 合成最终评分
    """
    print("[Stage3] Scoring...")
    print(f"  Stage1 data: {json.dumps(stage1, indent=2, ensure_ascii=False)}")
    print(f"  Stage2 data: {json.dumps(stage2, indent=2, ensure_ascii=False)}")
    # =========================
    # 1. 从 Stage1 取基础事实
    # =========================
    facts = stage1

    coverage = facts["coverage"]
    correctness = facts["correctness"]
    hallucination = facts.get("hallucination", [])

    # 示例：硬指标
    coverage_rate = coverage["covered_items"] / coverage["total_items"]
    correctness_penalty = correctness["wrong_count"]
    hallucination_count = len(hallucination)

    # =========================
    # 2. 从 Stage2 取 soft judge
    # =========================
    soft = stage2

    usefulness = soft.get("usefulness_score", 0)
    summary = soft.get("summary", "")

    # =========================
    # 3. 最终打分逻辑（你可随意改）
    # =========================
    final_score = (
        coverage_rate * 40
        + usefulness * 0.4
        - correctness_penalty * 1.5
        - hallucination_count * 5
    )

    final_score = round(max(final_score, 0), 2)

    return {
        "coverage_rate": round(coverage_rate, 3),
        "correctness_wrong": correctness_penalty,
        "hallucination_count": hallucination_count,
        "coverage": coverage,
        "correctness": correctness,
        "hallucination": hallucination,
        "usefulness": usefulness,
        "final_score": final_score,
        "summary": summary,
        "result": "PASS" if final_score >= 60 else "FAIL",
    }
