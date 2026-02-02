from typing import List, Dict


def merge_stage1_results(chunks: List[Dict]) -> Dict:
    merged = {
        "coverage": {
            "total_items": 0,
            "covered_items": 0,
            "missing": [],
        },
        "correctness": {
            "wrong_count": 0,
            "mismatches": [],
        },
        "hallucination": [],
        "usefulness": {
            "missing_explanations": [],
        }
    }

    pos = 1

    for chunk in chunks:
        cov = chunk.get("coverage", {})
        merged["coverage"]["total_items"] += cov.get("total_items", 0)
        merged["coverage"]["covered_items"] += cov.get("covered_items", 0)

        for item in cov.get("missing", []):
            merged["coverage"]["missing"].append({
                "position": pos,
                "content": item["content"]
            })
            pos += 1

        corr = chunk.get("correctness", {})
        merged["correctness"]["wrong_count"] += corr.get("wrong_count", 0)
        merged["correctness"]["mismatches"].extend(corr.get("mismatches", []))

        merged["hallucination"].extend(chunk.get("hallucination", []))
        merged["usefulness"]["missing_explanations"].extend(
            chunk.get("usefulness", {}).get("missing_explanations", [])
        )

    return merged
