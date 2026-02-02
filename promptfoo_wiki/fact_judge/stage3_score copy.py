import json
from pathlib import Path

LEVEL_SCORE = {
    "HIGH": 1.0,
    "MEDIUM": 0.6,
    "LOW": 0.3,
}

CORRECTNESS_PENALTY = {
    "GOOD": 0,
    "MINOR_ISSUES": 10,
    "BAD": 30,
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

    hallucination_level = stage2["hallucination_level"]
    if stage2["hallucination_level"] == "SEVERE" and not stage1["hallucination"]:
        # downgrade
        hallucination_level = "NONE"

    score -= HALLUCINATION_PENALTY[hallucination_level]

    score = round(max(score, 0), 2)
    correctness = facts["correctness"]
    hallucination = facts.get("hallucination", [])
    correctness_penalty = correctness["wrong_count"]
    return {
        "final_score": score,
        "result": "PASS" if score >= 60 else "FAIL",
        "summary": stage2["summary"],
        "details": {
            "coverage_rate": round(coverage_rate, 3),
            "usefulness_level": stage2["usefulness_level"],
            "coverage_level": stage2["coverage_level"],
            "correctness_level": stage2["correctness_level"],
            "hallucination_level": stage2["hallucination_level"],
            "correctness_wrong": correctness_penalty,
            # "coverage": coverage,
            # "correctness": correctness,
            "hallucination": hallucination,
        },
    }
