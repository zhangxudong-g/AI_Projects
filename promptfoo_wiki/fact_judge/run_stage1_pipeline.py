import json
from pathlib import Path
from splitters.java_splitter import split_java
from splitters.sql_splitter import split_sql
from stage1.run_stage1_chunk import run_stage1_chunk
from stage1.merge_stage1 import merge_stage1_results


def run(source_code: str, wiki_md: str, language: str):
    if language == "java":
        blocks = split_java(source_code)
    elif language == "sql":
        blocks = split_sql(source_code)
    else:
        raise ValueError("Unsupported language")

    results = []
    for block in blocks:
        print(f"[Stage1] Processing {block['name']} "
              f"({block['start_line']}-{block['end_line']})")
        res = run_stage1_chunk(block["code"], wiki_md)
        results.append(res)

    final = merge_stage1_results(results)
    Path("output/stage1.json").write_text(
        json.dumps(final, indent=2), encoding="utf-8"
    )
    return final
