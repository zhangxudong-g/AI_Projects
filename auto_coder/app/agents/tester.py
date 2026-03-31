"""Tester Agent - 测试执行"""

import logging
from typing import Any, Callable

from langchain_core.language_models import BaseLanguageModel
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage

from app.core.deep_agent import DeepAgentState, ExecutionStatus
from app.core.config import get_settings
from app.tools.shell_tools import run_command
from app.tools.file_tools import list_files, read_file

logger = logging.getLogger(__name__)


# Tester 系统提示词
TESTER_SYSTEM_PROMPT = """你是一个专业的测试工程师。

你的职责是：
1. 运行项目的测试用例
2. 检查代码是否可以正常运行
3. 发现并报告错误
4. 验证功能是否符合需求

测试类型：
- 语法检查：确保代码没有语法错误
- 单元测试：运行单元测试用例
- 集成测试：运行集成测试
- 功能验证：验证核心功能

可用工具：
- run_command(cmd): 运行命令
- list_files(path): 列出文件
- read_file(path): 读取文件

输出格式：
请输出测试结果：
1. 测试是否通过
2. 如果有错误，详细描述错误信息
3. 如果有警告，列出警告信息
"""


class TesterAgent:
    """Tester Agent 类
    
    负责运行测试
    """
    
    def __init__(self, llm: BaseLanguageModel, tools: list[Callable]):
        self.llm = llm
        self.tools = tools
        self.settings = get_settings()
    
    def run_tests(self, files: list[str]) -> dict[str, Any]:
        """运行测试
        
        Args:
            files: 要测试的文件列表
        
        Returns:
            测试结果
        """
        results = {
            "passed": True,
            "tests_run": 0,
            "errors": [],
            "warnings": [],
            "output": "",
        }
        
        # 1. 检查 Python 文件语法
        py_files = [f for f in files if f.endswith(".py")]
        for py_file in py_files:
            syntax_result = self._check_syntax(py_file)
            if not syntax_result["success"]:
                results["passed"] = False
                results["errors"].append({
                    "file": py_file,
                    "error": syntax_result["error"],
                    "type": "syntax",
                })
        
        # 2. 尝试运行 pytest
        pytest_result = self._run_pytest()
        if pytest_result["success"]:
            results["output"] += pytest_result.get("stdout", "")
            results["tests_run"] = self._parse_pytest_count(pytest_result.get("stdout", ""))
        else:
            # pytest 可能没有测试用例，尝试直接运行主文件
            if py_files:
                run_result = self._run_main(py_files[0])
                if not run_result["success"]:
                    results["passed"] = False
                    results["errors"].append({
                        "file": py_files[0],
                        "error": run_result.get("stderr", "运行失败"),
                        "type": "runtime",
                    })
        
        return results
    
    def _check_syntax(self, file_path: str) -> dict[str, Any]:
        """检查 Python 文件语法"""
        cmd = f'python -m py_compile "{file_path}"'
        result = run_command(cmd)
        
        return {
            "success": result["success"],
            "error": result.get("stderr", ""),
        }
    
    def _run_pytest(self) -> dict[str, Any]:
        """运行 pytest"""
        cmd = "pytest -v --tb=short"
        result = run_command(cmd, timeout=120)
        
        return result
    
    def _run_main(self, file_path: str) -> dict[str, Any]:
        """运行主文件"""
        cmd = f'python "{file_path}"'
        result = run_command(cmd, timeout=30)
        
        return result
    
    def _parse_pytest_count(self, output: str) -> int:
        """解析 pytest 运行数量"""
        import re
        match = re.search(r"(\d+) passed", output)
        if match:
            return int(match.group(1))
        return 0
    
    def verify_project_structure(self) -> dict[str, Any]:
        """验证项目结构"""
        files_result = list_files(".", recursive=True)
        
        if not files_result["success"]:
            return {
                "valid": False,
                "error": files_result.get("error", "无法列出文件"),
            }
        
        files = files_result.get("files", [])
        file_paths = [f["path"] for f in files]
        
        # 检查基本结构
        has_main = any("main.py" in p for p in file_paths)
        has_init = any("__init__.py" in p for p in file_paths)
        
        return {
            "valid": True,
            "files_count": len(files),
            "has_main": has_main,
            "has_init": has_init,
        }


def tester_node(
    state: DeepAgentState,
    llm: BaseLanguageModel,
    tools: list[Callable],
) -> dict[str, Any]:
    """Tester 节点函数
    
    Args:
        state: 当前状态
        llm: 语言模型
        tools: 工具列表
    
    Returns:
        状态更新
    """
    logger.info("=== Tester 节点执行 ===")
    
    if not state.generated_files:
        logger.info("没有生成的文件，跳过测试")
        return {}
    
    try:
        # 创建 Tester
        tester = TesterAgent(llm, tools)
        
        # 验证项目结构
        structure_result = tester.verify_project_structure()
        logger.info(f"项目结构验证：{structure_result}")
        
        # 运行测试
        test_result = tester.run_tests(state.generated_files)
        
        # 记录执行历史
        state.add_execution_record({
            "node": "tester",
            "action": "run_tests",
            "tests_run": test_result.get("tests_run", 0),
            "passed": test_result.get("passed", True),
            "errors_count": len(test_result.get("errors", [])),
        })
        
        # 处理测试结果
        if not test_result["passed"]:
            errors = test_result.get("errors", [])
            for error in errors:
                error_msg = f"[{error.get('type', 'unknown')}] {error.get('file', '')}: {error.get('error', '')}"
                state.add_error(error_msg)
                logger.error(f"测试失败：{error_msg}")
            
            # 发送事件
            state._emit_event("test_failed", {
                "errors": errors,
                "output": test_result.get("output", ""),
            })
            
            logger.warning(f"测试失败，共 {len(errors)} 个错误")
        else:
            # 测试通过
            state._emit_event("test_passed", {
                "tests_run": test_result.get("tests_run", 0),
                "output": test_result.get("output", ""),
            })
            
            logger.info("测试通过")
        
        # 设置最终输出（如果所有步骤完成且无错误）
        if test_result["passed"] and not state.errors:
            # 检查所有步骤是否完成（处理字典和 TaskStep 两种情况）
            all_completed = True
            for step in state.plan:
                status = step.get("status") if isinstance(step, dict) else step.status
                if status != "completed":
                    all_completed = False
                    break
            
            if all_completed:
                state.final_output = "项目生成完成，所有测试通过"

        # 如果没有错误，不再继续到 Fixer
        if not state.errors:
            return {
                "errors": state.errors,
                "final_output": state.final_output,
                "messages": state.messages + [
                    AIMessage(content=f"测试{'通过' if test_result['passed'] else '失败'}")
                ],
            }
        
        # 有错误，继续到 Fixer
        return {
            "errors": state.errors,
            "final_output": state.final_output,
            "messages": state.messages + [
                AIMessage(content="测试失败，需要修复")
            ],
        }

    except Exception as e:
        logger.exception(f"Tester 执行失败：{e}")
        state.add_error(f"Tester 执行失败：{e}")

        return {
            "errors": state.errors,
        }
