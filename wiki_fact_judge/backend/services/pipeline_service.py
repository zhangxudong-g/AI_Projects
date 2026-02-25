import subprocess
import json
from pathlib import Path
from typing import Dict, Any
from sqlalchemy.orm import Session
from backend.database import TestCase, TestReport
from backend.services import report_service
import os


def run_case_with_report(db: Session, case_id: str) -> Dict[str, Any]:
    """
    运行单个测试案例并创建报告
    """
    return _run_case_internal(db, case_id, create_report=True)


def run_case_without_report(db: Session, case_id: str) -> Dict[str, Any]:
    """
    运行单个测试案例但不创建报告（用于计划执行）
    """
    return _run_case_internal(db, case_id, create_report=False)


def _run_case_internal(db: Session, case_id: str, create_report: bool = True) -> Dict[str, Any]:
    """
    内部运行单个测试案例的函数
    通过 subprocess 调用 CLI pipeline
    """
    # 获取测试案例信息
    case = db.query(TestCase).filter(TestCase.case_id == case_id).first()
    if not case:
        raise ValueError(f"未找到测试案例: {case_id}")

    # 导入必要的模块
    import json
    from backend.database import TestReport
    from datetime import datetime

    # 如果需要创建报告，则更新报告状态为RUNNING
    if create_report:
        # 检查是否已有报告，如果没有则创建
        existing_report = (
            db.query(TestReport)
            .filter(TestReport.case_id == case_id)
            .order_by(TestReport.created_at.desc())
            .first()
        )
        if existing_report:
            # 更新现有报告的状态
            existing_report.status = "RUNNING"
            existing_report.result = json.dumps(
                {"status": "RUNNING", "message": "Pipeline is running"}
            )
            existing_report.updated_at = datetime.utcnow()
        else:
            # 创建新的测试报告
            report = TestReport(
                report_name=report_service.generate_unique_report_name(case_id=case_id, db=db),
                case_id=case_id,
                status="RUNNING",
                result=json.dumps({"status": "RUNNING", "message": "Pipeline is running"}),
                output_path="",
            )
            db.add(report)

        db.commit()

    # 获取项目根目录（与 case_router.py 中的路径计算保持一致）
    project_root = Path(
        __file__
    ).parent.parent.parent.resolve()  # 这会得到 D:\AI_Projects\wiki_fact_judge (项目根目录)

    # 构建文件的绝对路径并验证安全性
    source_code_abs_path = None
    wiki_abs_path = None
    yaml_abs_path = None

    if case.source_code_path:
        # 防止路径遍历攻击 - 使用项目根目录构建绝对路径
        safe_path = project_root / case.source_code_path
        if not str(safe_path).startswith(str(project_root)):
            raise ValueError(f"Invalid source code path: {case.source_code_path}")
        source_code_abs_path = safe_path

    if case.wiki_path:
        # 防止路径遍历攻击 - 使用项目根目录构建绝对路径
        safe_path = project_root / case.wiki_path
        if not str(safe_path).startswith(str(project_root)):
            raise ValueError(f"Invalid wiki path: {case.wiki_path}")
        wiki_abs_path = safe_path

    if case.yaml_path:
        # 防止路径遍历攻击 - 使用项目根目录构建绝对路径
        safe_path = project_root / case.yaml_path
        if not str(safe_path).startswith(str(project_root)):
            raise ValueError(f"Invalid YAML path: {case.yaml_path}")
        yaml_abs_path = safe_path

    # 验证文件是否存在
    missing_files = []
    if source_code_abs_path and not source_code_abs_path.exists():
        missing_files.append(f"Source code: {source_code_abs_path}")
    if wiki_abs_path and not wiki_abs_path.exists():
        missing_files.append(f"Wiki: {wiki_abs_path}")
    if yaml_abs_path and not yaml_abs_path.exists():
        missing_files.append(f"YAML: {yaml_abs_path}")

    if missing_files:
        # 如果需要创建报告，创建失败的测试报告
        if create_report:
            from backend.database import TestReport

            report = TestReport(
                report_name=report_service.generate_unique_report_name(case_id=case_id, db=db),
                case_id=case_id,
                status="FAILED",
                result=json.dumps({"error": f"以下文件不存在: {', '.join(missing_files)}"}),
                output_path="",
            )
            db.add(report)
            db.commit()

        return {
            "success": False,
            "case_id": case_id,
            "error": f"以下文件不存在: {', '.join(missing_files)}",
        }

    # 创建输出目录
    output_dir = project_root / "data" / "output" / case_id
    output_dir.mkdir(parents=True, exist_ok=True)

    # 构建 CLI 脚本调用命令
    # CLI 目录在项目根目录下，不是在 backend 目录下
    project_root_full = Path(
        __file__
    ).parent.parent.parent.resolve()  # 完整的项目根目录
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
        with open(env_file_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    env[key.strip()] = value.strip()

    # 准备 CLI 脚本的参数
    import tempfile
    import sys

    # 创建一个临时的 Python 脚本来执行案例
    cli_script_content = f"""
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
"""

    # 使用临时文件来执行 CLI 脚本
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".py", delete=False, encoding="utf-8"
    ) as temp_file:
        temp_file.write(cli_script_content)
        temp_script_path = temp_file.name

    try:
        # 设置环境变量以处理缓存问题
        modified_env = env.copy()

        # 使用同步方式执行CLI脚本，工作目录设置为 CLI 目录
        result = sp.run(
            [sys.executable, temp_script_path],
            capture_output=True,
            text=False,  # 不直接解码为文本
            cwd=str(cli_dir),  # 在 CLI 目录下执行
            env=modified_env,
        )
        # 手动处理输出编码，避免 UnicodeDecodeError
        try:
            # 尝试使用 utf-8 解码，如果失败则使用系统默认编码
            stdout_str = result.stdout.decode("utf-8", errors="replace")
        except (UnicodeDecodeError, AttributeError):
            try:
                # 如果 utf-8 失败，尝试使用系统默认编码
                import locale

                encoding = locale.getpreferredencoding()
                stdout_str = result.stdout.decode(encoding, errors="ignore")
            except:
                # 如果都失败了，转换为字符串表示
                stdout_str = str(result.stdout)
        try:
            stderr_str = result.stderr.decode("utf-8", errors="ignore")
        except (UnicodeDecodeError, AttributeError):
            try:
                # 如果 utf-8 失敗，嘗試使用系統默認編碼
                import locale

                encoding = locale.getpreferredencoding()
                stderr_str = result.stderr.decode(encoding, errors="ignore")
            except:
                # 如果都失敗了，轉換為字符串表示
                stderr_str = str(result.stderr)

        # 将输出打印到主进程，使用 ignore 忽略无法显示的字符
        if stdout_str:
            # 编码为 utf-8 并忽略无法编码的字符，然后解码回字符串
            safe_stdout = stdout_str.encode('gbk', errors='ignore').decode('gbk', errors='ignore')
            print(f"[CLI STDOUT] {safe_stdout}", flush=True)
        if stderr_str:
            safe_stderr = stderr_str.encode('gbk', errors='ignore').decode('gbk', errors='ignore')
            print(f"[CLI STDERR] {safe_stderr}", flush=True)

        # 删除临时脚本
        if os.path.exists(temp_script_path):
            os.remove(temp_script_path)

        if result.returncode != 0:
            return {
                "success": False,
                "case_id": case_id,
                "error": f"Pipeline 执行失败: {result.stderr}",
            }

        # 直接读取 final_score.json 文件，而不是解析输出
        final_score_path = output_dir / "final_score.json"
        
        if not final_score_path.exists():
            return {
                "success": False,
                "case_id": case_id,
                "error": f"final_score.json 文件未生成: {final_score_path}",
            }
        
        try:
            # 读取并解析 final_score.json 文件
            with open(final_score_path, 'r', encoding='utf-8') as f:
                final_result = json.load(f)

            # 如果需要创建报告，创建成功的测试报告
            if create_report:
                from backend.database import TestReport

                report = TestReport(
                    report_name=report_service.generate_unique_report_name(case_id=case_id, db=db),
                    case_id=case_id,
                    status="FINISHED",
                    final_score=(
                        final_result.get("final_score")
                        if isinstance(final_result, dict) and "final_score" in final_result
                        else None
                    ),
                    result=json.dumps(final_result),  # 保存完整的JSON结果
                    output_path=str(final_score_path),
                )
                db.add(report)
                db.commit()

            # 返回结果，包含完整的多层JSON结构
            return {
                "success": True,
                "case_id": case_id,
                "result": final_result,
                "output_path": str(final_score_path),
            }
        except json.JSONDecodeError as e:
            # 如果需要创建报告，创建失败的测试报告
            if create_report:
                from backend.database import TestReport

                report = TestReport(
                    report_name=report_service.generate_unique_report_name(case_id=case_id, db=db),
                    case_id=case_id,
                    status="FAILED",
                    result=json.dumps(
                        {
                            "error": f"无法解析 final_score.json 文件为JSON: {str(e)}"
                        }
                    ),
                    output_path="",
                )
                db.add(report)
                db.commit()

            return {
                "success": False,
                "case_id": case_id,
                "error": f"无法解析 final_score.json 文件为JSON: {str(e)}",
            }
        except Exception as e:
            # 如果需要创建报告，创建失败的测试报告
            if create_report:
                from backend.database import TestReport

                report = TestReport(
                    report_name=report_service.generate_unique_report_name(case_id=case_id, db=db),
                    case_id=case_id,
                    status="FAILED",
                    result=json.dumps({"error": f"处理 final_score.json 文件时发生未知错误: {str(e)}"}),
                    output_path="",
                )
                db.add(report)
                db.commit()

            return {
                "success": False,
                "case_id": case_id,
                "error": f"处理 final_score.json 文件时发生未知错误: {str(e)}",
            }

    except Exception as e:
        # 确保临时脚本被清理
        try:
            if "temp_script_path" in locals() and os.path.exists(temp_script_path):
                os.remove(temp_script_path)
        except:
            pass  # 忽略清理过程中的错误
        return {"success": False, "case_id": case_id, "error": str(e)}


def run_case(db: Session, case_id: str) -> Dict[str, Any]:
    """
    运行单个测试案例（向后兼容，等同于带报告的版本）
    """
    return run_case_with_report(db, case_id)


def run_plan(db: Session, plan_id: int):
    """
    运行测试计划
    执行计划中的所有案例并聚合结果
    """
    from backend.services.plan_service import get_plan_cases
    from backend.database import TestReport
    from datetime import datetime
    import json

    # 获取计划中的所有案例
    cases = get_plan_cases(db, plan_id)


    # 每次运行都创建新的计划报告（不覆盖已有报告）
    # 生成唯一的报告名称
    report_name = report_service.generate_unique_report_name(plan_id=plan_id, db=db)
    
    plan_report = TestReport(
        report_name=report_name,
        plan_id=plan_id,
        case_id=None,
        status="RUNNING",
        result=json.dumps(
            {
                "status": "RUNNING",
                "message": f"Running plan with {len(cases)} cases",
                "total_cases": len(cases),
                "completed_cases": 0,
            }
        ),
        output_path="",
    )
    db.add(plan_report)
    db.commit()
    results = []
    total_score = 0
    completed_count = 0

    execution_errors = []
    print(f"[INFO] Starting plan {plan_id} with {cases}")  # 日志输出
    for i, case in enumerate(cases):
        try:
            # 使用不创建报告的版本来执行case
            result = run_case_without_report(db, case.case_id)  # 使用不创建报告的版本
            results.append({"case_id": case.case_id, "result": result})

            # 如果有分数，累加用于计算平均分
            if result.get("success") and "result" in result:
                res_data = result["result"]
                if isinstance(res_data, dict) and "final_score" in res_data:
                    try:
                        total_score += float(res_data["final_score"])
                        completed_count += 1
                    except (ValueError, TypeError):
                        pass  # 如果分数不是有效数字，跳过
            else:
                # 如果case执行失败，记录错误
                execution_errors.append(
                    {
                        "case_id": case.case_id,
                        "error": result.get("error", "Unknown error"),
                    }
                )
                print(
                    f"[ERROR] Failed to execute case {case.case_id}: {result.get('error', 'Unknown error')}"
                )

        except Exception as e:
            # 捕获执行case时的异常
            error_msg = f"Failed to execute case {case.case_id}: {str(e)}"
            execution_errors.append({"case_id": case.case_id, "error": error_msg})

            # 添加错误结果到结果列表
            results.append(
                {
                    "case_id": case.case_id,
                    "result": {
                        "success": False,
                        "case_id": case.case_id,
                        "error": error_msg,
                    },
                }
            )

        # 更新计划报告的进度
        if plan_report:
            plan_report.result = json.dumps(
                {
                    "status": "RUNNING",
                    "message": f"Running plan: {i+1}/{len(cases)} cases completed",
                    "total_cases": len(cases),
                    "completed_cases": i + 1,
                    "current_case": case.case_id,
                    "errors": execution_errors,  # 包含错误信息
                }
            )
            plan_report.updated_at = datetime.utcnow()
            db.commit()

    # 计算平均分数
    average_score = total_score / completed_count if completed_count > 0 else 0

    # 确定计划的最终状态
    final_status = (
        "FINISHED"
        if len(execution_errors) == 0
        else "PARTIAL_SUCCESS" if completed_count > 0 else "FAILED"
    )

    # 更新计划报告为完成状态
    if plan_report:
        plan_report.status = final_status
        plan_report.final_score = average_score
        plan_report.result = json.dumps(
            {
                "status": final_status,
                "message": f"Plan completed with {completed_count}/{len(cases)} cases successful. {len(execution_errors)} cases failed.",
                "total_cases": len(cases),
                "completed_cases": completed_count,
                "failed_cases": len(execution_errors),
                "average_score": average_score,
                "results": [r["result"] for r in results],
                "errors": execution_errors,
            }
        )
        plan_report.updated_at = datetime.utcnow()
        db.commit()

    return {
        "plan_id": plan_id,
        "total_cases": len(cases),
        "completed_cases": completed_count,
        "average_score": average_score,
        "results": results,
    }
