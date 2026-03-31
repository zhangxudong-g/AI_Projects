"""Coder Agent - 代码生成"""

import logging
from typing import Any, Callable

from langchain_core.language_models import BaseLanguageModel
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

from app.core.deep_agent import DeepAgentState, ExecutionStatus, TaskStep
from app.core.config import get_settings
from app.tools.file_tools import write_file, read_file, list_files

logger = logging.getLogger(__name__)


# Coder 系统提示词
CODER_SYSTEM_PROMPT = """你是一个专业的全栈软件工程师。

你的职责是：
1. 根据任务规划编写高质量的代码
2. 遵循最佳实践和设计模式
3. 编写清晰、可维护的代码
4. 添加适当的注释和文档

代码要求：
1. 遵循项目现有的代码风格
2. 使用类型注解（Python）
3. 添加必要的错误处理
4. 代码应该可以直接运行

可用工具：
- write_file(path, content): 写入文件
- read_file(path): 读取文件
- list_files(path): 列出文件

输出格式：
请使用以下格式输出代码：

```python
# 文件路径：path/to/file.py
# 代码内容...
```

或者对于多个文件：

<file path="path/to/file1.py">
# 代码内容...
</file>

<file path="path/to/file2.py">
# 代码内容...
</file>

注意：
1. 确保所有导入都是正确的
2. 确保代码可以运行
3. 如果有依赖，请在 requirements.txt 中添加
"""


class CoderAgent:
    """Coder Agent 类
    
    负责生成代码
    """
    
    def __init__(self, llm: BaseLanguageModel, tools: list[Callable]):
        self.llm = llm
        self.tools = tools
        self.settings = get_settings()
        self._setup_tools()
    
    def _setup_tools(self):
        """设置工具"""
        # 将工具转换为 LLM 可调用的格式
        self.tool_map = {tool.__name__: tool for tool in self.tools}
    
    def generate_code(
        self,
        request: str,
        current_step: str,
        existing_files: list[str],
    ) -> dict[str, Any]:
        """生成代码
        
        Args:
            request: 原始需求
            current_step: 当前步骤描述
            existing_files: 现有文件列表
        
        Returns:
            生成的代码和文件信息
        """
        # 构建提示词
        files_context = ""
        if existing_files:
            files_context = "\n现有文件:\n" + "\n".join(existing_files)
        
        prompt = f"""
{CODER_SYSTEM_PROMPT}

用户需求：{request}

当前任务：{current_step}
{files_context}

请开始编写代码。
"""
        
        messages = [
            SystemMessage(content=CODER_SYSTEM_PROMPT),
            HumanMessage(content=prompt),
        ]
        
        response = self.llm.invoke(messages)
        
        return {
            "code": response.content,
            "files": self._parse_files(response.content),
        }
    
    def _parse_files(self, content: str) -> list[dict[str, str]]:
        """解析生成的文件内容

        支持多种格式：
        1. ```python # 文件路径：xxx ... ```
        2. <file path="xxx">...</file>
        3. ```python/path/to/file.py ... ```
        4. 直接提取代码块
        """
        import re

        files = []

        # 格式 1: ```python # 文件路径：xxx
        pattern1 = r"```(?:python)?\s*#?\s*文件路径：([^\n]+)\n(.*?)```"
        for match in re.finditer(pattern1, content, re.DOTALL):
            path = match.group(1).strip()
            code = match.group(2).strip()
            files.append({"path": path, "content": code})

        # 格式 2: <file path="xxx">
        pattern2 = r'<file\s+path="([^"]+)">\s*(.*?)\s*</file>'
        for match in re.finditer(pattern2, content, re.DOTALL):
            path = match.group(1).strip()
            code = match.group(2).strip()
            files.append({"path": path, "content": code})

        # 格式 3: ```python path/to/file.py 或 ```path/to/file.py
        pattern3 = r"```(?:python)?\s*([a-zA-Z0-9_./\\]+\.(py|js|ts|json|md|txt|yaml|yml))\s*\n(.*?)```"
        for match in re.finditer(pattern3, content, re.DOTALL | re.IGNORECASE):
            path = match.group(1).strip()
            code = match.group(3).strip()
            if not any(f["path"] == path for f in files):
                files.append({"path": path, "content": code})

        # 格式 4: 如果没有任何匹配，尝试提取单个代码块作为默认文件
        if not files:
            pattern4 = r"```(?:python)?\s*\n(.*?)```"
            match = re.search(pattern4, content, re.DOTALL)
            if match:
                code = match.group(1).strip()
                # 尝试从上下文中推断文件名
                path_match = re.search(r'([a-zA-Z0-9_]+\.py)', content[:content.find("```")])
                path = path_match.group(1) if path_match else "output.py"
                files.append({"path": path, "content": code})

        return files


def coder_node(
    state: DeepAgentState,
    llm: BaseLanguageModel,
    tools: list[Callable],
) -> dict[str, Any]:
    """Coder 节点函数
    
    Args:
        state: 当前状态
        llm: 语言模型
        tools: 工具列表
    
    Returns:
        状态更新
    """
    logger.info("=== Coder 节点执行 ===")
    
    if not state.plan:
        logger.warning("没有任务规划，无法执行编码")
        return {}

    try:
        # 获取当前步骤（处理字典和 TaskStep 两种情况）
        current_step = None
        for step in state.plan:
            # 如果是字典，转换为 TaskStep
            if isinstance(step, dict):
                step_obj = TaskStep(
                    id=step.get("id", ""),
                    description=step.get("description", ""),
                    status=step.get("status", "pending"),
                    result=step.get("result"),
                    error=step.get("error"),
                )
            else:
                step_obj = step
            
            if step_obj.status == "pending":
                current_step = step_obj
                break

        if not current_step:
            # 所有步骤都已完成
            logger.info("所有步骤已完成")
            return {}

        # 创建 Coder
        coder = CoderAgent(llm, tools)

        # 获取现有文件列表
        files_result = list_files(".")
        existing_files = [f["path"] for f in files_result.get("files", [])]

        # 生成代码
        result = coder.generate_code(
            request=state.user_request,
            current_step=current_step.description,
            existing_files=existing_files,
        )

        # 写入文件
        written_files = []
        for file_info in result.get("files", []):
            path = file_info["path"]
            content = file_info["content"]
            
            write_result = write_file(path, content)
            if write_result["success"]:
                written_files.append(path)
                state.add_file(path)
                logger.info(f"文件已写入：{path}")
        
        # 更新步骤状态
        if written_files:
            state.update_step_status(
                current_step.id,
                "completed",
                result=f"创建了 {len(written_files)} 个文件",
            )
        else:
            state.update_step_status(
                current_step.id,
                "completed",
                result="代码生成完成",
            )
        
        # 记录执行历史
        state.add_execution_record({
            "node": "coder",
            "action": "generate_code",
            "step_id": current_step.id,
            "files_created": written_files,
        })
        
        # 发送事件
        state._emit_event("code_generated", {
            "step_id": current_step.id,
            "files": written_files,
        })
        
        logger.info(f"代码生成完成，创建了 {len(written_files)} 个文件")
        
        return {
            "generated_files": state.generated_files,
            "messages": state.messages + [
                AIMessage(content=f"代码生成完成：{len(written_files)} 个文件")
            ],
        }
    
    except Exception as e:
        logger.exception(f"Coder 执行失败：{e}")
        state.add_error(f"Coder 执行失败：{e}")
        
        return {
            "errors": state.errors,
        }
