#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
从 test 目录自动导入测试数据到 case 中

目录结构:
test/
├─code/           # 源代码目录
│  ├─java/
│  └─plsql/
└─wiki/           # Wiki 文档目录
   ├─java/
   └─plsql/

该脚本会:
1. 扫描 test/code 和 test/wiki 目录 (包括子目录)
2. 根据文件名匹配代码和对应的 wiki 文档
3. 自动创建 case 记录到数据库
"""

import os
import sys
from pathlib import Path
from datetime import datetime
import shutil

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from backend.database import SessionLocal, TestCase, create_tables
from backend.schemas import TestCaseCreate
from backend.services import case_service
import uuid


# 支持的语言/类型
SUPPORTED_LANGUAGES = ['java', 'plsql', 'py', 'js', 'ts', 'sql']


def scan_directory(base_dir: Path, include_non_md: bool = False):
    """
    扫描目录，获取所有文件及其子目录信息
    
    Args:
        base_dir: 基础目录路径
        include_non_md: 是否包含非 .md 文件 (用于 code 目录)
        
    Returns:
        dict: {文件名：{'path': 文件路径，'subdir': 子目录名}}
    """
    files = {}
    
    if not base_dir.exists():
        return files
    
    for root, _, filenames in os.walk(base_dir):
        for filename in filenames:
            # 判断是否处理该文件
            is_md = filename.endswith('.md')
            if not is_md and not include_non_md:
                continue
            
            # 提取文件名
            if is_md:
                # 去掉 .md 扩展名
                name = filename[:-3]
            else:
                name = filename
            
            rel_path = Path(root).relative_to(base_dir)
            subdir = rel_path.parts[0] if rel_path.parts else ''
            
            files[name] = {
                'path': Path(root) / filename,
                'subdir': subdir,
                'rel_path': rel_path,
                'is_md': is_md
            }
    
    return files


def find_matching_files(code_dir: Path, wiki_dir: Path):
    """
    查找匹配的代码和 wiki 文件对
    
    Args:
        code_dir: 代码目录路径
        wiki_dir: wiki 文档目录路径
        
    Returns:
        list: 匹配的文件对列表
    """
    matches = []
    
    # 扫描代码文件和 wiki 文件
    # code 目录包含非 .md 文件，wiki 目录只包含 .md 文件
    code_files = scan_directory(code_dir, include_non_md=True)
    wiki_files = scan_directory(wiki_dir, include_non_md=False)
    
    print(f"  扫描 code 目录：找到 {len(code_files)} 个代码文件")
    print(f"  扫描 wiki 目录：找到 {len(wiki_files)} 个 wiki 文件")
    
    # 查找匹配的文件对
    for name, code_info in code_files.items():
        if name in wiki_files:
            wiki_info = wiki_files[name]
            
            # 检查子目录是否匹配 (java 匹配 java, plsql 匹配 plsql)
            if code_info['subdir'] == wiki_info['subdir']:
                matches.append({
                    'name': name,
                    'code_path': code_info['path'],
                    'code_subdir': code_info['subdir'],
                    'wiki_path': wiki_info['path'],
                    'wiki_subdir': wiki_info['subdir']
                })
    
    return matches


def detect_language_from_filename(filename: str, subdir: str = '') -> str:
    """
    从文件名或子目录名检测编程语言
    
    Args:
        filename: 文件名 (如：Controller_xxx.java.md 或 GKBFKGZSHNT.SQL)
        subdir: 子目录名 (如：java, plsql)
        
    Returns:
        str: 语言名称 (java, plsql 等)
    """
    # 首先检查子目录名
    if subdir:
        subdir_lower = subdir.lower()
        if subdir_lower in SUPPORTED_LANGUAGES:
            return subdir_lower
        # 特殊处理：plsql 目录
        if 'plsql' in subdir_lower or 'sql' in subdir_lower:
            return 'plsql'
    
    # 去掉 .md 扩展名
    name = filename[:-3] if filename.endswith('.md') else filename
    
    # 检查文件扩展名
    parts = name.split('.')
    if len(parts) > 1:
        ext = parts[-1].lower()
        if ext in SUPPORTED_LANGUAGES:
            return ext
        # 特殊处理 SQL 扩展名
        if ext == 'sql':
            return 'plsql'
    
    return 'unknown'


def copy_file_to_cases_dir(source_path: Path, case_dir: Path, file_type: str, language: str = 'unknown') -> str:
    """
    复制文件到 cases 目录
    
    Args:
        source_path: 源文件路径
        case_dir: 目标 case 目录
        file_type: 文件类型 ('source_code', 'wiki', 'yaml')
        language: 编程语言
        
    Returns:
        str: 相对于项目根目录的路径
    """
    filename = source_path.name
    
    if file_type == 'source_code':
        # 源码文件：根据语言和原文件扩展名确定目标文件名
        if language == 'java':
            target_name = 'source_code.java'
        elif language == 'plsql':
            target_name = 'source_code.sql'
        elif language == 'py':
            target_name = 'source_code.py'
        elif language == 'js':
            target_name = 'source_code.js'
        elif language == 'ts':
            target_name = 'source_code.ts'
        elif language == 'sql':
            target_name = 'source_code.sql'
        else:
            # 默认使用 source_code.md
            target_name = 'source_code.md'
    elif file_type == 'wiki':
        # wiki 文档：统一为 wiki.md
        target_name = 'wiki.md'
    elif file_type == 'yaml':
        # yaml 配置：yaml.yaml
        target_name = 'yaml.yaml'
    else:
        target_name = filename
    
    # 目标路径
    target_path = case_dir / target_name
    
    # 复制文件
    shutil.copy2(source_path, target_path)
    
    # 返回相对路径 (相对于项目根目录)
    rel_path = target_path.relative_to(project_root)
    return str(rel_path)


def import_test_data(dry_run: bool = False):
    """
    导入测试数据
    
    Args:
        dry_run: 如果为 True，只显示不实际导入
    """
    # 目录路径
    test_dir = project_root / "test"
    code_dir = test_dir / "code"
    wiki_dir = test_dir / "wiki"
    data_dir = project_root / "data" / "cases"
    
    # 确保目录存在
    data_dir.mkdir(parents=True, exist_ok=True)
    
    # 检查目录是否存在
    if not code_dir.exists():
        print(f"错误：代码目录不存在：{code_dir}")
        return
    
    if not wiki_dir.exists():
        print(f"错误：Wiki 目录不存在：{wiki_dir}")
        return
    
    # 查找匹配的文件
    print(f"\n正在扫描 test 目录...")
    matches = find_matching_files(code_dir, wiki_dir)
    
    if not matches:
        print("\n未找到匹配的代码和 wiki 文件对")
        return
    
    # 按语言分类统计
    lang_stats = {}
    for match in matches:
        lang = detect_language_from_filename(match['name'] + '.md')
        lang_stats[lang] = lang_stats.get(lang, 0) + 1
    
    print(f"\n找到 {len(matches)} 对匹配的文件:")
    for lang, count in sorted(lang_stats.items()):
        print(f"  - {lang}: {count} 个")
    print()
    
    # 创建数据库会话
    db = SessionLocal()
    
    try:
        imported_count = 0
        skipped_count = 0
        lang_imported = {}
        
        for i, match in enumerate(matches, 1):
            name = match['name']
            code_path = match['code_path']
            wiki_path = match['wiki_path']
            code_subdir = match['code_subdir']
            
            # 使用子目录名检测语言
            language = detect_language_from_filename(name, code_subdir)
            
            # 生成 case_id
            case_id = f"case_{uuid.uuid4().hex[:8]}"
            case_dir = data_dir / case_id
            
            print(f"[{i}/{len(matches)}] 处理：{name} [{language}]")
            print(f"  子目录：{code_subdir}")
            print(f"  代码：{code_path}")
            print(f"  Wiki: {wiki_path}")
            
            if dry_run:
                print(f"  [DRY RUN] 将创建 case_id: {case_id}\n")
                imported_count += 1
                lang_imported[language] = lang_imported.get(language, 0) + 1
                continue
            
            # 创建 case 目录
            case_dir.mkdir(parents=True, exist_ok=True)
            
            # 复制文件
            try:
                source_code_rel_path = copy_file_to_cases_dir(code_path, case_dir, 'source_code', language)
                wiki_rel_path = copy_file_to_cases_dir(wiki_path, case_dir, 'wiki')
                
                # 创建数据库记录
                case_data = TestCaseCreate(
                    case_id=case_id,
                    name=name,
                    source_code_path=source_code_rel_path,
                    wiki_path=wiki_rel_path,
                    yaml_path=None
                )
                
                db_case = case_service.create_case(db, case_data)
                print(f"  [OK] 已创建 case_id: {case_id}")
                print(f"    名称：{name}")
                print(f"    语言：{language}")
                print(f"    代码路径：{source_code_rel_path}")
                print(f"    Wiki 路径：{wiki_rel_path}\n")
                
                imported_count += 1
                lang_imported[language] = lang_imported.get(language, 0) + 1
                
            except Exception as e:
                print(f"  [FAIL] 导入失败：{str(e)}\n")
                skipped_count += 1
        
        # 打印统计
        print("\n" + "="*60)
        print(f"导入完成！")
        print(f"  找到匹配文件：{len(matches)} 对")
        print(f"  成功导入：{imported_count} 个 case")
        if skipped_count > 0:
            print(f"  跳过/失败：{skipped_count} 个 case")
        
        if lang_imported:
            print(f"\n  按语言统计:")
            for lang, count in sorted(lang_imported.items()):
                print(f"    - {lang}: {count} 个")
        
        print("="*60)
        
    finally:
        db.close()


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='从 test 目录自动导入测试数据到 case 中'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='试运行模式，只显示不实际导入'
    )
    parser.add_argument(
        '--language',
        type=str,
        choices=SUPPORTED_LANGUAGES + ['all'],
        default='all',
        help=f'只导入指定语言的文件 (默认：all, 支持：{", ".join(SUPPORTED_LANGUAGES)})'
    )
    
    args = parser.parse_args()
    
    print("="*60)
    print("测试数据导入工具")
    print("="*60)
    print(f"项目根目录：{project_root}")
    print(f"测试数据目录：{project_root / 'test'}")
    print(f"目标目录：{project_root / 'data' / 'cases'}")
    print(f"支持的语言：{', '.join(SUPPORTED_LANGUAGES)}")
    print()
    
    if args.dry_run:
        print("【试运行模式】- 不会实际导入数据\n")
    else:
        print("准备导入数据...\n")
    
    import_test_data(dry_run=args.dry_run)


if __name__ == "__main__":
    main()
