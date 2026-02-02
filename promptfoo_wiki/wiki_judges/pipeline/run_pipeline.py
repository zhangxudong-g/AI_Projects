import subprocess
import json
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
TMP_DIR = BASE_DIR / ".tmp"
TMP_DIR.mkdir(exist_ok=True)

def render_template(template_path: Path, vars: dict) -> str:
    """
    渲染模板文件，将变量替换为实际值
    """
    text = template_path.read_text(encoding="utf-8")
    for k, v in vars.items():
        text = text.replace(f"{{{{{k}}}}}", str(v))  # 确保值转换为字符串
    return text

def run_promptfoo(yaml_text: str, output_path: Path):
    """
    运行 promptfoo 评估
    """
    tmp_yaml = TMP_DIR / f"{output_path.stem}.yaml"
    tmp_yaml.write_text(yaml_text, encoding="utf-8")

    try:
        subprocess.run(
            [
                "promptfoo", "eval",
                "--no-cache",
                "--config", str(tmp_yaml),
                "--output", str(output_path),
            ],
            check=True,
        )
    except FileNotFoundError:
        print("错误: 找不到 promptfoo 命令。请确保已安装 promptfoo:")
        print("npm install -g promptfoo")
        print("或者使用测试版本: python pipeline/test_pipeline.py")
        raise

def run_stage1(case):
    """
    运行第一阶段：事实抽取
    """
    yaml_text = render_template(
        BASE_DIR / "templates/stage1.single.yaml",
        {
            "file_path": case["file_path"],
            "language": case["language"],
            "source_code": case["source_code"],
            "wiki_md": case["wiki_md"],
        },
    )

    out = BASE_DIR / "output/stage1" / f"{case['id'].replace('/', '_').replace('\\', '_')}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    run_promptfoo(yaml_text, out)
    print(f"Stage 1 completed for {case['id']}")

def run_stage2(case):
    """
    运行第二阶段：软判断（质量评分）
    """
    stage1_output_path = BASE_DIR / "output/stage1" / f"{case['id'].replace('/', '_').replace('\\', '_')}.json"
    if not stage1_output_path.exists():
        print(f"Warning: Stage 1 output not found for {case['id']}, skipping stage 2")
        return
        
    stage1_output = stage1_output_path.read_text(encoding="utf-8")

    yaml_text = render_template(
        BASE_DIR / "templates/stage2.single.yaml",
        {"stage1_output": stage1_output},
    )

    out = BASE_DIR / "output/stage2" / f"{case['id'].replace('/', '_').replace('\\', '_')}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    run_promptfoo(yaml_text, out)
    print(f"Stage 2 completed for {case['id']}")

def run_stage3(case):
    """
    运行第三阶段：硬判断（接受/拒绝）
    """
    stage1_output_path = BASE_DIR / "output/stage1" / f"{case['id'].replace('/', '_').replace('\\', '_')}.json"
    stage2_output_path = BASE_DIR / "output/stage2" / f"{case['id'].replace('/', '_').replace('\\', '_')}.json"
    
    if not stage1_output_path.exists():
        print(f"Warning: Stage 1 output not found for {case['id']}, skipping stage 3")
        return
        
    if not stage2_output_path.exists():
        print(f"Warning: Stage 2 output not found for {case['id']}, skipping stage 3")
        return
        
    stage1_output = stage1_output_path.read_text(encoding="utf-8")
    stage2_output = stage2_output_path.read_text(encoding="utf-8")

    yaml_text = render_template(
        BASE_DIR / "templates/stage3.single.yaml",
        {
            "stage1_output": stage1_output,
            "stage2_output": stage2_output,
        },
    )

    out = BASE_DIR / "output/stage3" / f"{case['id'].replace('/', '_').replace('\\', '_')}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    run_promptfoo(yaml_text, out)
    print(f"Stage 3 completed for {case['id']}")

def run_pipeline(cases):
    """
    运行完整的三阶段评估管道
    """
    for case in cases:
        print(f"> Processing {case['id']}")
        run_stage1(case)
        run_stage2(case)
        run_stage3(case)
        print(f"Done {case['id']}")

def load_cases_from_config(config_path: str):
    """
    从配置文件加载待评估的案例
    """
    config_file = BASE_DIR / config_path
    if not config_file.exists():
        print(f"Config file {config_path} not found")
        return []
    
    with open(config_file, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    cases = []
    for case_config in config:
        case = {
            "id": case_config["id"],
            "file_path": case_config["file_path"],
            "language": case_config["language"],
            "source_code": (BASE_DIR / case_config["source_code_path"]).read_text(encoding="utf-8"),
            "wiki_md": (BASE_DIR / case_config["wiki_path"]).read_text(encoding="utf-8"),
        }
        cases.append(case)
    
    return cases

if __name__ == "__main__":
    # 从配置文件加载案例，如果没有配置文件则使用默认案例
    cases = load_cases_from_config("../cases_config.json")

    if not cases:
        print("No cases found in config, using default case...")
        cases = [
            {
                "id": "Calculator.java",
                "file_path": "sample_data/src/Calculator.java",
                "language": "java",
                "source_code": (BASE_DIR / "sample_data/src/Calculator.java").read_text(encoding="utf-8"),
                "wiki_md": (BASE_DIR / "sample_data/wiki/Calculator.md").read_text(encoding="utf-8"),
            },
        ]

    run_pipeline(cases)
    print("\nPipeline completed! Check the output/ directory for results.")