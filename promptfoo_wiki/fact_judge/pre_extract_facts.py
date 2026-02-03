"""
前置提取事实功能（工程wiki级别）
用于在详细评估之前对整个工程项目进行高层次的事实提取和分析
"""

import os
import json
from pathlib import Path
from typing import Dict, List, Any
import argparse


def extract_project_structure(project_path: str) -> Dict[str, Any]:
    """
    提取项目结构信息
    """
    structure = {
        "root_path": project_path,
        "modules": [],
        "dependencies": []
    }
    
    # 遍历项目目录，提取模块信息
    for root, dirs, files in os.walk(project_path):
        print(f"扫描目录: {root}")
        print(f"包含子目录: {dirs}")
        print(f"包含文件: {files}")
        # 过滤隐藏目录
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        
        for file in files:
            if file.endswith(('.py', '.js', '.java', '.ts', '.jsx', '.tsx', '.cpp', '.c', '.h')):
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, project_path)
                print(f"发现模块: {rel_path}")
                module_info = {
                    "name": file,
                    "path": rel_path,
                    "type": "file",
                    "language": _get_language_from_extension(file),
                    "size": os.path.getsize(file_path)
                }
                
                structure["modules"].append(module_info)
    
    return structure


def _get_language_from_extension(filename: str) -> str:
    """根据文件扩展名确定编程语言"""
    ext = os.path.splitext(filename)[1].lower()
    lang_map = {
        '.py': 'python',
        '.js': 'javascript',
        '.ts': 'typescript',
        '.jsx': 'javascript',
        '.tsx': 'typescript',
        '.java': 'java',
        '.cpp': 'cpp',
        '.c': 'c',
        '.h': 'c',
        '.go': 'go',
        '.rb': 'ruby',
        '.php': 'php',
        '.sql': 'sql'
    }
    return lang_map.get(ext, 'unknown')


def extract_dependencies(modules: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    提取模块间的依赖关系（简化版）
    """
    dependencies = []
    
    # 这里应该实现真正的依赖分析逻辑
    # 为演示目的，我们生成一些模拟的依赖关系
    for i, module in enumerate(modules[:10]):  # 限制数量以避免过多输出
        if i > 0:
            dependencies.append({
                "source": module["name"],
                "target": modules[i-1]["name"],
                "type": "import",
                "strength": 0.7
            })
    
    return dependencies


def identify_design_patterns(project_path: str) -> List[Dict[str, Any]]:
    """
    识别项目中的设计模式（简化版）
    """
    # 这里应该实现真正的设计模式识别逻辑
    # 为演示目的，返回一些模拟的模式
    return [
        {
            "pattern": "Singleton",
            "location": "some_module.py",
            "confidence": 0.85
        },
        {
            "pattern": "Factory",
            "location": "another_module.js",
            "confidence": 0.78
        }
    ]


def extract_architecture_features(project_path: str) -> Dict[str, Any]:
    """
    提取架构特征
    """
    return {
        "patterns_identified": identify_design_patterns(project_path),
        "layers": [
            {
                "name": "data_layer",
                "components": ["db", "models"],
                "responsibilities": ["data_access", "persistence"]
            },
            {
                "name": "business_logic",
                "components": ["services", "controllers"],
                "responsibilities": ["business_rules", "validation"]
            }
        ]
    }


def analyze_project_context(project_path: str) -> Dict[str, Any]:
    """
    分析项目上下文
    """
    # 简单分析项目类型
    project_files = os.listdir(project_path)
    
    if any(f.endswith('requirements.txt') or f.endswith('package.json') for f in project_files):
        project_type = "web_application"
    elif any(f.endswith('.sln') or f.endswith('.csproj') for f in project_files):
        project_type = "enterprise_app"
    else:
        project_type = "library"
    
    # 估算复杂度
    total_size = sum(os.path.getsize(os.path.join(project_path, f)) 
                     for f in os.listdir(project_path) 
                     if os.path.isfile(os.path.join(project_path, f)))
    
    if total_size < 10000:  # Less than 10KB
        complexity = "simple"
    elif total_size < 100000:  # Less than 100KB
        complexity = "medium"
    else:
        complexity = "complex"
    
    return {
        "project_type": project_type,
        "primary_language": "python",  # 这里应该通过分析确定
        "estimated_complexity": complexity,
        "key_components": ["auth", "database", "api"]  # 模拟值
    }


def extract_project_facts(project_path: str, output_dir: str = "output/pre_extraction") -> Dict[str, Any]:
    """
    提取工程项目的所有事实
    """
    print(f"开始分析项目: {project_path}")
    
    # 提取项目结构
    project_structure = extract_project_structure(project_path)
    
    # 提取依赖关系
    dependencies = extract_dependencies(project_structure["modules"])
    project_structure["dependencies"] = dependencies
    
    # 提取架构特征
    architecture_features = extract_architecture_features(project_path)
    
    # 分析项目上下文
    context_summary = analyze_project_context(project_path)
    
    # 组合所有信息
    result = {
        "project_structure": project_structure,
        "architecture_features": architecture_features,
        "context_summary": context_summary
    }
    
    # 确保输出目录存在
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    # 保存结果
    output_file = os.path.join(output_dir, "project_facts.json")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    
    print(f"项目事实提取完成，结果保存至: {output_file}")
    print(f"共提取了 {len(project_structure['modules'])} 个模块")
    
    return result


def main():
    parser = argparse.ArgumentParser(description='前置提取事实功能（工程wiki级别）')
    parser.add_argument('--project-path', required=True, help='项目路径')
    parser.add_argument('--output-dir', default='output/pre_extraction', help='输出目录')
    parser.add_argument('--max-depth', type=int, default=5, help='分析最大深度')
    parser.add_argument('--include-tests', action='store_true', help='包含测试文件')
    
    args = parser.parse_args()
    
    extract_project_facts(args.project_path, args.output_dir)


if __name__ == "__main__":
    main()