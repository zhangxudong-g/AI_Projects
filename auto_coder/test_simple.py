"""测试 AutoCoder 核心功能"""

import asyncio
from app.core.config import get_settings
from app.api.agent import create_executor

settings = get_settings()

print(f"配置：{settings.model_provider} / {settings.model_name}")
print(f"URL: {settings.model_base_url}")
print()

async def test():
    request = "写一个 Python 加法函数"
    
    print(f"请求：{request}")
    print()
    
    try:
        executor = create_executor(max_iterations=3)
        
        print("开始执行...")
        state = await executor.execute(request=request)
        
        print()
        print(f"状态：{state.status}")
        print(f"文件：{state.generated_files}")
        print(f"错误：{state.errors}")
        print(f"输出：{state.final_output}")
        
    except Exception as e:
        print(f"错误：{e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test())
