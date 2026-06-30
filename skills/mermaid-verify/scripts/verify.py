import re
import subprocess
import sys
import os

def verify_mermaid_in_md(md_file_path):
    if not os.path.exists(md_file_path):
        print(f"❌ 文件不存在: {md_file_path}")
        return False

    with open(md_file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 使用正则匹配 ```mermaid 和 ``` 之间的内容 (支持多行)
    pattern = re.compile(r'```mermaid\s*(.*?)```', re.DOTALL)
    matches = pattern.findall(content)

    if not matches:
        print(f"ℹ️ 在 {md_file_path} 中未找到 mermaid 代码块。")
        return True

    print(f"🔍 找到 {len(matches)} 个 Mermaid 图表，开始验证...\n")
    has_error = False

    for i, code in enumerate(matches):
        temp_mmd = f"_temp_verify_{i}.mmd"
        temp_out = f"_temp_verify_{i}.svg"
        
        # 1. 写入临时 .mmd 文件
        with open(temp_mmd, 'w', encoding='utf-8') as f:
            f.write(code.strip())

        # 2. 调用 mmdc 进行验证 (输出为 svg 格式速度较快)
        # 使用 capture_output=True 捕获标准输出和错误
        mmdc_cmd = 'mmdc.cmd' if os.name == 'nt' else 'mmdc'
        result = subprocess.run(
            [mmdc_cmd, '-i', temp_mmd, '-o', temp_out, '-b', 'transparent'], 
            capture_output=True, 
            text=True,
            encoding='utf-8'
        )

        # 3. 检查返回状态码
        if result.returncode != 0:
            print(f"❌ 第 {i+1} 个图表验证失败！")
            # 打印 mmdc 的具体报错信息，帮助定位语法错误
            print("-" * 30)
            print(result.stderr.strip() if result.stderr else result.stdout.strip())
            print("-" * 30)
            has_error = True
        else:
            print(f"✅ 第 {i+1} 个图表验证通过。")

        # 4. 清理临时文件
        for temp_file in [temp_mmd, temp_out]:
            if os.path.exists(temp_file):
                os.remove(temp_file)

    print("\n" + "="*30)
    if has_error:
        print("⚠️ 验证结束：存在语法错误，请检查上述报错！")
        return False
    else:
        print("🎉 验证结束：所有 Mermaid 图表语法均正确！")
        return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python verify_mermaid.py <你的wiki文件.md>")
        sys.exit(1)
    
    success = verify_mermaid_in_md(sys.argv[1])
    # 根据验证结果返回不同的退出码，方便 CI/CD 判断
    sys.exit(0 if success else 1) 