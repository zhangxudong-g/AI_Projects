import subprocess
import json
from pathlib import Path
from typing import Dict, Any
from sqlalchemy.orm import Session
from backend.database import TestCase
import os


def run_case(db: Session, case_id: str) -> Dict[str, Any]:
    """
    运行单个测试案例
    通过 subprocess 调用 CLI pipeline
    """
    # 获取测试案例信息
    case = db.query(TestCase).filter(TestCase.case_id == case_id).first()
    if not case:
        raise ValueError(f"未找到测试案例: {case_id}")

    # 获取项目根目录（与 case_router.py 中的路径计算保持一致）
    project_root = Path(__file__).parent.parent.resolve()  # 这会得到 D:\AI_Projects\wiki_fact_judge\backend

    # 构建文件的绝对路径
    source_code_abs_path = project_root / case.source_code_path if case.source_code_path else None
    wiki_abs_path = project_root / case.wiki_path if case.wiki_path else None
    yaml_abs_path = project_root / case.yaml_path if case.yaml_path else None

    # 验证文件是否存在
    missing_files = []
    if source_code_abs_path and not source_code_abs_path.exists():
        missing_files.append(f"Source code: {source_code_abs_path}")
    if wiki_abs_path and not wiki_abs_path.exists():
        missing_files.append(f"Wiki: {wiki_abs_path}")
    if yaml_abs_path and not yaml_abs_path.exists():
        missing_files.append(f"YAML: {yaml_abs_path}")

    if missing_files:
        # 创建失败的测试报告
        from backend.database import TestReport
        report = TestReport(
            report_name=f"Report_{case_id}",
            case_id=case_id,
            status="FAILED",
            result=json.dumps({"error": f"以下文件不存在: {', '.join(missing_files)}"}),
            output_path=""
        )
        db.add(report)
        db.commit()
        
        return {
            "success": False,
            "case_id": case_id,
            "error": f"以下文件不存在: {', '.join(missing_files)}"
        }

    # 创建输出目录
    output_dir = project_root / "data" / "output" / case_id
    output_dir.mkdir(parents=True, exist_ok=True)

    # 构建 CLI 脚本调用命令
    # CLI 目录在项目根目录下，不是在 backend 目录下
    project_root_full = Path(__file__).parent.parent.parent.resolve()  # 完整的项目根目录
    cli_dir = project_root_full / "cli"

    # 准备变量配置
    vars_cfg = {
        "source_code": str(source_code_abs_path) if source_code_abs_path else "",
        "wiki_md": str(wiki_abs_path) if wiki_abs_path else "",
    }
    if yaml_abs_path:
        vars_cfg["yaml_config"] = str(yaml_abs_path)

    # 直接执行 CLI 脚本，避免多重子进程问题
    import subprocess as sp
    env = os.environ.copy()

    # 从 .env 文件加载环境变量
    env_file_path = project_root_full / "cli" / ".env"
    if env_file_path.exists():
        # 读取 .env 文件并添加到环境变量
        with open(env_file_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env[key.strip()] = value.strip()

    # 准备 CLI 脚本的参数
    import tempfile
    import sys
    
    # 创建一个临时的 Python 脚本来执行案例
    cli_script_content = f'''
import sys
import os
import json
sys.path.insert(0, r"{str(cli_dir)}")

# 切 CLI 目录导入模块
os.chdir(r"{str(cli_dir)}")
from run_single_case_pipeline import run_single_case

# 运行单个案例
case_id = "{case_id}"
vars_cfg = {json.dumps(vars_cfg, ensure_ascii=False)}
output_dir = r"{str(output_dir)}"

result = run_single_case(
    case_id=case_id,
    vars_cfg=vars_cfg,
    output_dir=output_dir
)

# 输出结果为JSON格式
print(json.dumps(result))
'''

    # 使用临时文件来执行 CLI 脚本
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False, encoding='utf-8') as temp_file:
        temp_file.write(cli_script_content)
        temp_script_path = temp_file.name

    try:
        # 执行 CLI 脚本，工作目录设置为 CLI 目录
        # 为了避免编码问题，我们不直接使用 text=True，而是手动处理编码
        result = sp.run(
            [sys.executable, temp_script_path],
            capture_output=True,
            text=False,  # 不直接解码为文本
            cwd=str(cli_dir),  # 在 CLI 目录下执行
            env=env
        )
        
        # 手动处理输出编码，避免 UnicodeDecodeError
        try:
            # 尝试使用 utf-8 解码，如果失败则使用系统默认编码
            stdout_str = result.stdout.decode('utf-8', errors='replace')
        except (UnicodeDecodeError, AttributeError):
            try:
                # 如果 utf-8 失败，尝试使用系统默认编码
                import locale
                encoding = locale.getpreferredencoding()
                stdout_str = result.stdout.decode(encoding, errors='replace')
            except:
                # 如果都失败了，转换为字符串表示
                stdout_str = str(result.stdout)
        
        try:
            stderr_str = result.stderr.decode('utf-8', errors='replace')
        except (UnicodeDecodeError, AttributeError):
            try:
                # 如果 utf-8 失敗，嘗試使用系統默認編碼
                import locale
                encoding = locale.getpreferredencoding()
                stderr_str = result.stderr.decode(encoding, errors='replace')
            except:
                # 如果都失敗了，轉換為字符串表示
                stderr_str = str(result.stderr)
        
        # 将输出打印到主进程，以便在控制台上看到日志
        if stdout_str:
            print(f"[CLI STDOUT] {stdout_str}")
        if stderr_str:
            print(f"[CLI STDERR] {stderr_str}")

        # 删除临时脚本
        if os.path.exists(temp_script_path):
            os.remove(temp_script_path)

        if result.returncode != 0:
            return {
                "success": False,
                "case_id": case_id,
                "error": f"Pipeline 执行失败: {result.stderr}"
            }

        # 解析输出结果
        import re
        try:
            # 先尝试将字节数据解码为字符串
            if isinstance(result.stdout, bytes):
                # 尝试多种编码方式
                decoded_output = None
                for encoding in ['utf-8', 'shift-jis', 'cp932', 'euc-jp']:
                    try:
                        decoded_output = result.stdout.decode(encoding)
                        break
                    except UnicodeDecodeError:
                        continue
                
                if decoded_output is None:
                    # 如果所有编码都失败，使用错误替换
                    decoded_output = result.stdout.decode('utf-8', errors='replace')
            else:
                # 如果已经是字符串
                decoded_output = result.stdout
            
            # 查找所有可能的JSON对象
            matches = []
            # 找到所有可能的JSON对象
            start = 0
            while start < len(decoded_output):
                pos = decoded_output.find('{', start)
                if pos == -1:
                    break
                # 计算匹配的闭合括号
                bracket_count = 0
                for i in range(pos, len(decoded_output)):
                    if decoded_output[i] == '{':
                        bracket_count += 1
                    elif decoded_output[i] == '}':
                        bracket_count -= 1
                        if bracket_count == 0:
                            matches.append(decoded_output[pos:i+1])
                            break
                start = pos + 1
            
            # 尝试解析每个找到的JSON对象，优先寻找包含最多关键字段的JSON对象
            final_result = None
            target_json_str = None
            
            # 首先尝试找到包含最多关键字段的JSON对象（通常是最终结果）
            for json_str in reversed(matches):
                try:
                    parsed_json = json.loads(json_str)
                    if isinstance(parsed_json, dict):
                        # 计算包含的关键字段数量
                        key_fields = ['final_score', 'result', 'summary', 'details', 'comprehension_support', 'engineering_usefulness', 'engineering_action']
                        matched_keys_count = sum(1 for key in key_fields if key in parsed_json)
                        
                        # 如果包含至少3个关键字段，认为是最终结果
                        if matched_keys_count >= 3:
                            final_result = parsed_json
                            target_json_str = json_str
                            break
                except json.JSONDecodeError:
                    continue
            
            # 如果没有找到包含足够关键字段的JSON对象，尝试找包含final_score的
            if final_result is None:
                for json_str in reversed(matches):
                    try:
                        parsed_json = json.loads(json_str)
                        if isinstance(parsed_json, dict) and 'final_score' in parsed_json:
                            final_result = parsed_json
                            target_json_str = json_str
                            break
                    except json.JSONDecodeError:
                        continue
            
            # 如果仍然没找到，尝试解析最后一个找到的JSON对象
            if final_result is None and matches:
                for json_str in reversed(matches):
                    try:
                        final_result = json.loads(json_str)
                        target_json_str = json_str
                        break  # 成功解析就退出
                    except json.JSONDecodeError:
                        continue
            
            # 如果没有找到任何可解析的JSON对象，尝试解析整个输出
            if final_result is None:
                final_result = json.loads(decoded_output.strip())
            
            # 创建成功的测试报告
            from backend.database import TestReport
            report = TestReport(
                report_name=f"Report_{case_id}",
                case_id=case_id,
                status="FINISHED",
                final_score=final_result.get('final_score') if isinstance(final_result, dict) and 'final_score' in final_result else None,
                result=json.dumps(final_result),  # 保存完整的JSON结果
                output_path=str(output_dir / "final_score.json")
            )
            db.add(report)
            db.commit()
            
            # 返回结果，包含完整的多层JSON结构
            return {
                "success": True,
                "case_id": case_id,
                "result": final_result,
                "output_path": str(output_dir / "final_score.json")
            }
        except json.JSONDecodeError as e:
            # 创建失败的测试报告
            from backend.database import TestReport
            report = TestReport(
                report_name=f"Report_{case_id}_error",
                case_id=case_id,
                status="FAILED",
                result=json.dumps({"error": f"无法解析 CLI 输出为JSON: {str(e)}, 输出内容: {decoded_output[:500] if 'decoded_output' in locals() else str(result.stdout)[:500]}"}),
                output_path=""
            )
            db.add(report)
            db.commit()
            
            return {
                "success": False,
                "case_id": case_id,
                "error": f"无法解析 CLI 输出为JSON: {str(e)}, 输出内容: {decoded_output[:500] if 'decoded_output' in locals() else str(result.stdout)[:500]}"
            }

    except Exception as e:
        # 确保临时脚本被清理
        try:
            if 'temp_script_path' in locals() and os.path.exists(temp_script_path):
                os.remove(temp_script_path)
        except:
            pass  # 忽略清理过程中的错误
        return {
            "success": False,
            "case_id": case_id,
            "error": str(e)
        }


def run_plan(db: Session, plan_id: int):
    """
    运行测试计划
    执行计划中的所有案例并聚合结果
    """
    from backend.services.plan_service import get_plan_cases

    # 获取计划中的所有案例
    cases = get_plan_cases(db, plan_id)

    results = []
    total_score = 0
    completed_count = 0

    for case in cases:
        result = run_case(db, case.case_id)
        results.append({
            "case_id": case.case_id,
            "result": result
        })

        # 如果有分数，累加用于计算平均分
        if result.get("success") and "result" in result:
            res_data = result["result"]
            if isinstance(res_data, dict) and "final_score" in res_data:
                total_score += float(res_data["final_score"])
                completed_count += 1

    # 计算平均分数
    average_score = total_score / completed_count if completed_count > 0 else 0

    return {
        "plan_id": plan_id,
        "total_cases": len(cases),
        "completed_cases": completed_count,
        "average_score": average_score,
        "results": results
    }