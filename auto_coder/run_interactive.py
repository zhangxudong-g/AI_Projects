"""AutoCoder 交互式使用脚本 - 最简单的方式"""

import sys
from pathlib import Path

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent))

print("=" * 60)
print("  AutoCoder - 自动代码生成")
print("=" * 60)
print()

# 导入必要的模块
from app.core.config import get_settings
from app.api.agent import create_executor
import asyncio

settings = get_settings()

print(f"✅ 配置已加载")
print(f"   模型：{settings.model_provider} / {settings.model_name}")
print(f"   地址：{settings.model_base_url}")
print()

async def generate():
    """交互式生成代码"""
    
    print("💡 使用说明:")
    print("   - 输入代码需求，按 Enter 生成")
    print("   - 输入 'q' 退出")
    print()
    
    while True:
        request = input("🔹 请输入需求：").strip()
        
        if not request:
            continue
        
        if request.lower() == 'q':
            print("👋 再见！")
            break
        
        print()
        print("⏳ 正在生成代码，请稍候...")
        print()
        
        try:
            # 创建执行器
            executor = create_executor()
            
            # 执行生成
            state = await executor.execute(request=request)
            
            # 显示结果
            if state.generated_files:
                print(f"✅ 生成了 {len(state.generated_files)} 个文件:")
                for f in state.generated_files:
                    print(f"   📄 {f}")
                
                # 读取并显示第一个文件
                if state.generated_files:
                    first_file = state.generated_files[0]
                    from app.tools.file_tools import read_file
                    result = read_file(first_file)
                    if result["success"]:
                        print()
                        print(f"📄 {first_file} 内容预览:")
                        print("-" * 60)
                        content = result["content"]
                        lines = content.split("\n")
                        for i, line in enumerate(lines[:30], 1):
                            print(f"{i:3d} | {line}")
                        if len(lines) > 30:
                            print(f"... 还有 {len(lines) - 30} 行")
                        print("-" * 60)
            else:
                print("⚠️  没有生成文件")
            
            if state.errors:
                print()
                print("❌ 错误:")
                for err in state.errors:
                    print(f"   - {err}")
            
            print()
        
        except Exception as e:
            print(f"❌ 错误：{e}")
            print()


if __name__ == "__main__":
    asyncio.run(generate())
