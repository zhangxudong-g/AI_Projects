"""Fixer Agent - 错误修复"""

import logging
from typing import Any, Callable

from langchain_core.language_models import BaseLanguageModel
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage

from app.core.deep_agent import DeepAgentState, ExecutionStatus
from app.core.config import get_settings
from app.tools.file_tools import read_file, write_file
from app.tools.shell_tools import run_command

logger = logging.getLogger(__name__)


# Fixer 系统提示词
FIXER_SYSTEM_PROMPT = """你是一个专业的代码调试专家。

你的职责是：
1. 分析错误信息，定位问题根源
2. 提供修复方案并修改代码
3. 确保修复不会引入新的问题
4. 验证修复是否有效

可用工具：
- read_file(path): 读取文件内容
- write_file(path, content): 写入文件内容
- run_command(cmd): 运行命令验证修复

输出格式：
请按照以下格式输出修复：

分析：
[错误分析]

修复方案：
[修复步骤]

代码修改：
```python
# 文件路径：path/to/file.py
# 修复后的代码...
```

注意：
1. 只修改必要的代码
2. 保持代码风格一致
3. 添加必要的注释说明修复内容
4. 确保修复后代码可以运行
"""


class FixerAgent:
    """Fixer Agent 类
    
    负责修复错误
    """
    
    def __init__(self, llm: BaseLanguageModel, tools: list[Callable]):
        self.llm = llm
        self.tools = tools
        self.settings = get_settings()
    
    def analyze_error(
        self,
        error: str,
        file_path: str,
        error_type: str = "runtime",
    ) -> dict[str, Any]:
        """分析错误
        
        Args:
            error: 错误信息
            file_path: 相关文件路径
            error_type: 错误类型
        
        Returns:
            分析结果
        """
        # 读取文件内容（如果存在）
        file_content = ""
        if file_path:
            read_result = read_file(file_path)
            if read_result["success"]:
                file_content = read_result.get("content", "")
        
        # 构建提示词
        prompt = f"""
{FIXER_SYSTEM_PROMPT}

错误类型：{error_type}
错误信息：
{error}

相关文件：{file_path}

文件内容：
{file_content}

请分析错误并提供修复方案。
"""
        
        messages = [
            SystemMessage(content=FIXER_SYSTEM_PROMPT),
            HumanMessage(content=prompt),
        ]
        
        response = self.llm.invoke(messages)
        
        return {
            "analysis": response.content,
            "fix": self._parse_fix(response.content),
        }
    
    def _parse_fix(self, content: str) -> list[dict[str, str]]:
        """解析修复内容"""
        import re
        
        fixes = []
        
        # 格式 1: ```python # 文件路径：xxx
        pattern1 = r"```(?:python)?\s*#?\s*文件路径：([^\n]+)\n(.*?)```"
        for match in re.finditer(pattern1, content, re.DOTALL):
            path = match.group(1).strip()
            code = match.group(2).strip()
            fixes.append({"path": path, "content": code})
        
        # 格式 2: <file path="xxx">
        pattern2 = r'<file\s+path="([^"]+)">\s*(.*?)\s*</file>'
        for match in re.finditer(pattern2, content, re.DOTALL):
            path = match.group(1).strip()
            code = match.group(2).strip()
            fixes.append({"path": path, "content": code})
        
        return fixes
    
    def fix_errors(
        self,
        errors: list[str],
        generated_files: list[str],
    ) -> dict[str, Any]:
        """修复错误
        
        Args:
            errors: 错误列表
            generated_files: 生成的文件列表
        
        Returns:
            修复结果
        """
        results = {
            "fixed": False,
            "fixes_applied": [],
            "remaining_errors": [],
        }
        
        for error in errors:
            # 尝试从错误信息中提取文件路径
            file_path = self._extract_file_path(error, generated_files)
            error_type = self._classify_error(error)
            
            # 分析并修复
            fix_result = self.analyze_error(error, file_path, error_type)
            
            # 应用修复
            for fix in fix_result.get("fix", []):
                write_result = write_file(fix["path"], fix["content"])
                if write_result["success"]:
                    results["fixes_applied"].append({
                        "file": fix["path"],
                        "success": True,
                    })
                    logger.info(f"修复已应用：{fix['path']}")
                else:
                    results["fixes_applied"].append({
                        "file": fix["path"],
                        "success": False,
                        "error": write_result.get("error", ""),
                    })
        
        # 检查是否还有错误
        results["fixed"] = len(results["fixes_applied"]) > 0
        
        return results
    
    def _extract_file_path(
        self, 
        error: str, 
        known_files: list[str]
    ) -> str:
        """从错误信息中提取文件路径"""
        import re
        
        # 尝试匹配文件路径
        patterns = [
            r'File "([^"]+)"',
            r'in ([\w./\\]+\.py)',
            r'at ([\w./\\]+\.py)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, error)
            if match:
                return match.group(1)
        
        # 尝试在已知文件中查找
        for file_path in known_files:
            if file_path in error:
                return file_path
        
        # 返回第一个 Python 文件
        py_files = [f for f in known_files if f.endswith(".py")]
        if py_files:
            return py_files[0]
        
        return ""
    
    def _classify_error(self, error: str) -> str:
        """分类错误类型"""
        error_lower = error.lower()
        
        if "syntax" in error_lower or "invalid syntax" in error_lower:
            return "syntax"
        elif "import" in error_lower or "module not found" in error_lower:
            return "import"
        elif "name" in error_lower and "not defined" in error_lower:
            return "name_error"
        elif "type" in error_lower:
            return "type_error"
        elif "attribute" in error_lower and "has no attribute" in error_lower:
            return "attribute_error"
        elif "key" in error_lower and "error" in error_lower:
            return "key_error"
        elif "index" in error_lower and "out of range" in error_lower:
            return "index_error"
        elif "file" in error_lower or "no such file" in error_lower:
            return "file_error"
        else:
            return "runtime"


def fixer_node(
    state: DeepAgentState,
    llm: BaseLanguageModel,
    tools: list[Callable],
) -> dict[str, Any]:
    """Fixer 节点函数
    
    Args:
        state: 当前状态
        llm: 语言模型
        tools: 工具列表
    
    Returns:
        状态更新
    """
    logger.info("=== Fixer 节点执行 ===")
    
    if not state.errors:
        logger.info("没有错误需要修复")
        return {}
    
    try:
        # 创建 Fixer
        fixer = FixerAgent(llm, tools)
        
        # 获取当前错误
        current_errors = state.errors.copy()
        
        # 修复错误
        fix_result = fixer.fix_errors(current_errors, state.generated_files)
        
        # 记录执行历史
        state.add_execution_record({
            "node": "fixer",
            "action": "fix_errors",
            "errors_count": len(current_errors),
            "fixes_applied": len(fix_result.get("fixes_applied", [])),
        })
        
        # 发送事件
        state._emit_event("errors_fixed", {
            "original_errors": current_errors,
            "fixes_applied": fix_result.get("fixes_applied", []),
        })
        
        logger.info(f"修复完成，应用了 {len(fix_result.get('fixes_applied', []))} 个修复")

        # 检查迭代次数，超过限制则停止
        state.iteration_count += 1
        if state.iteration_count >= 5:
            state.add_error("达到最大修复次数限制 (5 次)")
            return {
                "errors": state.errors,  # 保留错误，不再修复
                "generated_files": state.generated_files,
                "iteration_count": state.iteration_count,
                "messages": state.messages + [
                    AIMessage(content=f"已尝试修复 5 次，仍有错误未解决")
                ],
            }

        return {
            "errors": [],  # 清空错误，让下一轮测试验证
            "generated_files": state.generated_files,
            "iteration_count": state.iteration_count,
            "messages": state.messages + [
                AIMessage(content=f"修复了 {len(fix_result.get('fixes_applied', []))} 个问题")
            ],
        }

    except Exception as e:
        logger.exception(f"Fixer 执行失败：{e}")
        state.add_error(f"Fixer 执行失败：{e}")

        return {
            "errors": state.errors,
        }
