"""
main.py - PL/SQL Wiki 生成器主入口

使用 plsql_extractor 提取结构化信息，生成 Markdown 文档。
支持规则模板生成和可选的 LLM 增强生成。
"""

import json
import os
import sys
from plsql_extractor import parse_plsql_file


def generate_simple_wiki(data: dict) -> str:
    """
    生成简易 Wiki（规则模板）
    
    Args:
        data: 结构化数据（来自 parse_plsql_file）
    
    Returns:
        Markdown 格式的文档
    """
    if 'error' in data:
        return f"❌ 解析错误: {data['error']}"
    
    md = ["# 📄 PL/SQL 文档\n"]
    
    # 摘要
    summary = data.get('summary', {})
    md.append(f"> 📦 包: {summary.get('packages', 0)} | ⚙️ 过程: {summary.get('procedures', 0)} | 🔧 函数: {summary.get('functions', 0)}\n")
    
    for obj in data.get('source_objects', []):
        # 包标题
        if obj['type'] == 'PACKAGE':
            md.append(f"\n## 📦 包: `{obj['name']}`")
            if obj.get('comment'):
                md.append(f"\n> {obj['comment']}\n")
            
            # 成员列表
            if obj.get('members'):
                md.append("\n### 成员列表\n")
                for member in obj['members']:
                    # 参数格式化
                    params_str = ", ".join([
                        f"{p['mode']} {p['name']}: {p['datatype']}" 
                        for p in member.get('params', [])
                    ])
                    
                    if member['type'] == 'FUNCTION':
                        return_str = f" → `{member['return_type']}`"
                        md.append(f"#### 🔧 `{member['name']}({params_str})`{return_str}")
                    else:
                        md.append(f"#### ⚙️ `{member['name']}({params_str})`")
                    
                    if member.get('comment'):
                        md.append(f"\n> {member['comment']}\n")
                    
                    md.append("")  # 空行
        
        # 独立过程/函数
        elif obj['type'] in ['FUNCTION', 'PROCEDURE']:
            icon = "🔧" if obj['type'] == 'FUNCTION' else "⚙️"
            md.append(f"\n## {icon} {obj['type']}: `{obj['name']}`")
            if obj.get('comment'):
                md.append(f"\n> {obj['comment']}\n")
            
            params_str = ", ".join([
                f"{p['mode']} {p['name']}: {p['datatype']}" 
                for p in obj.get('params', [])
            ])
            if params_str:
                md.append(f"\n**参数**: {params_str}\n")
            
            if obj.get('return_type'):
                md.append(f"\n**返回**: `{obj['return_type']}`\n")
    
    return "\n".join(md)


def generate_wiki_with_llm(structured_data: dict, api_key: str = None) -> str:
    """
    使用 LLM 生成增强版 Wiki（可选）
    
    Args:
        structured_data: 结构化数据
        api_key: OpenAI API 密钥（或从环境变量 OPENAI_API_KEY 读取）
    
    Returns:
        LLM 生成的 Markdown 文档
    """
    try:
        from openai import OpenAI
    except ImportError:
        print("⚠️ openai 包未安装。跳过 LLM 生成。")
        print("   安装: pip install openai")
        return ""
    
    api_key = api_key or os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print("⚠️ 未提供 OpenAI API 密钥。跳过 LLM 生成。")
        print("   设置: export OPENAI_API_KEY=your-key")
        return ""
    
    client = OpenAI(api_key=api_key)
    
    prompt = f"""你是一个技术文档专家。请根据以下 PL/SQL 结构生成详细 Wiki 文档：

## 要求
- Markdown 格式，中文描述，术语保留英文
- 包含：功能概述、参数表格、异常说明、使用示例
- 不编造代码中不存在的信息，不确定处标注"待补充"
- 格式美观，使用表格和代码块

## 结构化数据
```json
{json.dumps(structured_data, ensure_ascii=False, indent=2)}
```

请生成文档：
"""
    
    print("🤖 调用 LLM 生成文档...")
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.2
    )
    
    return response.choices[0].message.content


def main():
    """主入口"""
    # 设置控制台编码为 UTF-8（Windows）
    import sys
    if sys.platform == 'win32':
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    
    # 解析命令行参数
    if len(sys.argv) > 1:
        sql_file = sys.argv[1]
    else:
        sql_file = "test_sample.sql"
    
    if not os.path.exists(sql_file):
        print(f"❌ 文件不存在: {sql_file}")
        sys.exit(1)
    
    print(f"📖 解析 PL/SQL 文件: {sql_file}")
    
    # 执行解析
    result = parse_plsql_file(sql_file, verbose=True)
    
    # 创建输出目录
    os.makedirs("output", exist_ok=True)
    
    # 保存结构化数据
    output_json = os.path.join("output", "structured.json")
    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    print(f"💾 结构化数据: {output_json}")
    
    # 生成简易 Wiki
    wiki_md = generate_simple_wiki(result)
    output_wiki = os.path.join("output", "wiki.md")
    with open(output_wiki, "w", encoding="utf-8") as f:
        f.write(wiki_md)
    print(f"📝 Wiki 文档: {output_wiki}")
    
    # 可选：LLM 生成
    if "--llm" in sys.argv:
        llm_wiki = generate_wiki_with_llm(result)
        if llm_wiki:
            output_llm = os.path.join("output", "wiki_llm.md")
            with open(output_llm, "w", encoding="utf-8") as f:
                f.write(llm_wiki)
            print(f"🤖 LLM Wiki: {output_llm}")
    
    # 打印预览
    print("\n" + "="*60)
    print("📋 Wiki 预览:")
    print("="*60)
    print(wiki_md)


if __name__ == "__main__":
    main()
