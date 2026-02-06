import json


def extract_llm_json(promptfoo_output_path: str) -> dict:
    """
    从 promptfoo eval 的输出中，
    提取并 parse LLM 返回的 JSON
    """
    raw = json.loads(open(promptfoo_output_path, encoding="utf-8").read())

    try:
        output_text = raw["results"]["results"][0]["response"]["output"]
        # print(f"[LLM OUTPUT] {output_text}")
    except (KeyError, IndexError):
        raise RuntimeError("Invalid promptfoo output structure")

    try:
        return json.loads(output_text)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"LLM output is not valid JSON:\n{output_text}") from e