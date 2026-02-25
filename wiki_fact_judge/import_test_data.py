#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
从 test 目录自动导入测试数据到 case 中

该脚本会：
1. 扫描 test/code 和 test/wiki 目录
2. 根据文件名匹配代码和对应的 wiki 文档
3. 自动创建 case 记录到数据库
"""

import os
import sys
from pathlib import Path
from datetime import datetime

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from backend.database import SessionLocal, TestCase, create_tables
from backend.schemas import TestCaseCreate
from backend.services import case_service
import uuid


def find_matching_files(code_dir: Path, wiki_dir: Path):
    """
    查找匹配的代码和 wiki 文件对
    
    Args:
        code_dir: 代码目录路径
        wiki_dir: wiki 文档目录路径
        
    Returns:
        list: 匹配的文件对列表 [(code_path, wiki_path, name), ...]
    """
    matches = []
    
    # 获取所有代码文件
    code_files = {}
    for root, _, files in os.walk(code_dir):
        for file in files:
            if file.endswith('.md'):
                # 提取文件名（不含扩展名）
                name = file[:-3]  # 去掉 .md
                rel_path = Path(root).relative_to(code_dir)
                code_files[name] = {
                    'path': Path(root) / file,
                    'rel_path': rel_path
                }
    
    # 查找匹配的 wiki 文件
    for root, _, files in os.walk(wiki_dir):
        for file in files:
            if file.endswith('.md'):
                name = file[:-3]  # 去掉 .md
                rel_path = Path(root).relative_to(wiki_dir)
                
                # 查找是否有匹配的代码文件
                if name in code_files:
                    matches.append({
                        'name': name,
                        'code_path': code_files[name]['path'],
                        'code_rel_path': code_files[name]['rel_path'],
                        'wiki_path': Path(root) / file,
                        'wiki_rel_path': rel_path
                    })
    
    return matches


def copy_file_to_cases_dir(source_path: Path, case_dir: Path, file_type: str) -> str:
    """
    复制文件到 cases 目录
    
    Args:
        source_path: 源文件路径
        case_dir: 目标 case 目录
        file_type: 文件类型（'source_code', 'wiki'）
        
    Returns:
        str: 相对路径
    """
    # 确定目标文件名
    ext = source_path.suffix
    if file_type == 'source_code':
        # 从文件名推断语言
        name_parts = source_path.stem.split('.')
        if len(name_parts) > 1:
            lang = name_parts[-1].lower()
            if lang in ['java', 'py', 'js', 'ts', 'sql', 'plsql']:
                ext = f'.{lang}'
            else:
                ext = '.md'
        else:
            ext = '.md'
        target_name = f'source_code{ext}'
    elif file_type == 'wiki':
        target_name = 'wiki.md'
    else:
        target_name = source_path.name
    
    # 目标路径
    target_path = case_dir / target_name
    
    # 复制文件
    import shutil
    shutil.copy2(source_path, target_path)
    
    # 返回相对路径（相对于项目根目录）
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
    print(f"正在扫描 test 目录...")
    matches = find_matching_files(code_dir, wiki_dir)
    
    if not matches:
        print("未找到匹配的代码和 wiki 文件对")
        return
    
    print(f"找到 {len(matches)} 对匹配的文件：\n")
    
    # 创建数据库会话
    db = SessionLocal()
    
    try:
        imported_count = 0
        skipped_count = 0
        
        for i, match in enumerate(matches, 1):
            name = match['name']
            code_path = match['code_path']
            wiki_path = match['wiki_path']
            
            # 生成 case_id
            case_id = f"case_{uuid.uuid4().hex[:8]}"
            case_dir = data_dir / case_id
            
            print(f"[{i}/{len(matches)}] 处理：{name}")
            print(f"  代码：{code_path}")
            print(f"  Wiki: {wiki_path}")
            
            if dry_run:
                print(f"  [DRY RUN] 将创建 case_id: {case_id}\n")
                imported_count += 1
                continue
            
            # 创建 case 目录
            case_dir.mkdir(parents=True, exist_ok=True)
            
            # 复制文件
            try:
                source_code_rel_path = copy_file_to_cases_dir(code_path, case_dir, 'source_code')
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
                print(f"    代码路径：{source_code_rel_path}")
                print(f"    Wiki 路径：{wiki_rel_path}\n")
                
                imported_count += 1
                
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
    
    args = parser.parse_args()
    
    print("="*60)
    print("测试数据导入工具")
    print("="*60)
    print(f"项目根目录：{project_root}")
    print(f"测试数据目录：{project_root / 'test'}")
    print(f"目标目录：{project_root / 'data' / 'cases'}")
    print()
    
    if args.dry_run:
        print("【试运行模式】- 不会实际导入数据\n")
    else:
        print("准备导入数据...\n")
    
    import_test_data(dry_run=args.dry_run)


if __name__ == "__main__":
    main()
