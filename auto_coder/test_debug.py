"""测试 AutoCoder 核心功能 - 详细调试版"""

import sys
print("1. 导入模块...")
import asyncio
from app.core.config import get_settings
print("2. 加载配置...")

settings = get_settings()
print(f"   模型：{settings.model_provider} / {settings.model_name}")
print(f"   URL: {settings.model_base_url}")
print()

print("3. 导入执行器...")
from app.api.agent import create_executor
print("   OK")
print()

async def test():
    print("4. 创建执行器...")
    request = "写一个 Python 加法函数"
    
    print(f"   请求：{request}")
    
    try:
        executor = create_executor(max_iterations=3)
        print("   执行器创建成功")
        print()
        
        print("5. 执行任务...")
        state = await executor.execute(request=request)
        
        print()
        print("6. 结果:")
        print(f"   状态：{state.status}")
        print(f"   文件：{len(state.generated_files)} 个")
        print(f"   错误：{len(state.errors)} 个")
        if state.final_output:
            print(f"   输出：{state.final_output[:100]}")
        
    except Exception as e:
        print(f"   错误：{e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    print()
    asyncio.run(test())
