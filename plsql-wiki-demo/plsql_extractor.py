"""
plsql_extractor.py - PL/SQL 文档提取器（纯 Python 实现）

使用正则表达式和状态机提取 PL/SQL 包、过程、函数的结构化信息。
相比 ANTLR 方案，这个版本：
- 不需要 Java
- 不需要 ANTLR 工具链
- 更轻量，适合文档提取场景
- 支持注释捕获
"""

import re
import json
from typing import List, Dict, Optional
from dataclasses import dataclass, field, asdict


@dataclass
class ParamInfo:
    """参数信息"""
    name: str = ""
    mode: str = "IN"  # IN, OUT, IN OUT
    datatype: str = ""


@dataclass
class RoutineInfo:
    """过程/函数信息"""
    type: str = ""  # FUNCTION or PROCEDURE
    name: str = ""
    line: int = 0
    comment: str = ""
    params: List[ParamInfo] = field(default_factory=list)
    return_type: str = ""


@dataclass
class PackageInfo:
    """包信息"""
    type: str = "PACKAGE"
    name: str = ""
    line: int = 0
    comment: str = ""
    members: List[RoutineInfo] = field(default_factory=list)


class PLSQLDocExtractor:
    """
    PL/SQL 文档提取器
    
    使用正则匹配提取:
    - 包规范 (PACKAGE spec)
    - 包体 (PACKAGE BODY)  
    - 函数 (FUNCTION)
    - 过程 (PROCEDURE)
    - 注释 (Comments)
    - 参数列表
    """
    
    def __init__(self):
        self.objects: List[PackageInfo | RoutineInfo] = []
        self.comment_buffer = ""
        self.last_comment_line = -1
    
    def parse_file(self, filepath: str, verbose=False) -> dict:
        """解析 PL/SQL 文件"""
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            return self.parse_content(content, verbose)
        except Exception as e:
            print(f"❌ 解析失败 {filepath}: {e}")
            return {'error': str(e)}
    
    def parse_content(self, content: str, verbose=False) -> dict:
        """解析 PL/SQL 内容"""
        lines = content.split('\n')
        
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            line_num = i + 1
            
            # 捕获注释
            if line.startswith('--') or line.startswith('/*'):
                self._capture_comment(line, line_num)
                i += 1
                continue
            
            # 匹配 PACKAGE 规范
            pkg_match = re.match(
                r'CREATE\s+(OR\s+REPLACE\s+)?PACKAGE\s+(\w+)\s+(IS|AS)',
                line, re.IGNORECASE
            )
            if pkg_match:
                pkg_name = pkg_match.group(2)
                pkg = PackageInfo(
                    name=pkg_name,
                    line=line_num,
                    comment=self._consume_comment()
                )
                self.objects.append(pkg)
                
                # 解析包成员
                i = self._parse_package_members(lines, i + 1, pkg)
                continue
            
            # 匹配 PACKAGE BODY
            body_match = re.match(
                r'CREATE\s+(OR\s+REPLACE\s+)?PACKAGE\s+BODY\s+(\w+)\s+(IS|AS)',
                line, re.IGNORECASE
            )
            if body_match:
                # 包体解析（跳过实现细节）
                i = self._skip_to_end_block(lines, i + 1)
                continue
            
            # 匹配独立 FUNCTION
            func_match = re.match(
                r'CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\s+(\w+)',
                line, re.IGNORECASE
            )
            if func_match:
                func = self._parse_function(lines, i, line_num)
                if func:
                    self.objects.append(func)
                    i = self._skip_to_end_block(lines, i + 1)
                    continue
            
            # 匹配独立 PROCEDURE
            proc_match = re.match(
                r'CREATE\s+(OR\s+REPLACE\s+)?PROCEDURE\s+(\w+)',
                line, re.IGNORECASE
            )
            if proc_match:
                proc = self._parse_procedure(lines, i, line_num)
                if proc:
                    self.objects.append(proc)
                    i = self._skip_to_end_block(lines, i + 1)
                    continue
            
            i += 1
        
        result = {
            'source_objects': [asdict(obj) for obj in self.objects],
            'summary': {
                'packages': len([o for o in self.objects if isinstance(o, PackageInfo)]),
                'procedures': self._count_routines('PROCEDURE'),
                'functions': self._count_routines('FUNCTION')
            }
        }
        
        if verbose:
            print(f"✅ 解析成功")
            print(f"📊 提取对象: {len(self.objects)}")
        
        return result
    
    def _capture_comment(self, line: str, line_num: int):
        """捕获注释"""
        # 单行注释
        if line.startswith('--'):
            comment = line[2:].strip()
            if self.comment_buffer:
                self.comment_buffer += "\n" + comment
            else:
                self.comment_buffer = comment
        
        # 块注释开始
        elif line.startswith('/*'):
            self.comment_buffer = line
        
        self.last_comment_line = line_num
    
    def _consume_comment(self) -> str:
        """消费并清空注释缓冲区"""
        comment = self.comment_buffer
        self.comment_buffer = ""
        return comment
    
    def _parse_package_members(self, lines: List[str], start: int, pkg: PackageInfo) -> int:
        """解析包成员（在 PACKAGE ... IS ... END 之间）"""
        i = start
        while i < len(lines):
            line = lines[i].strip()
            line_num = i + 1
            
            # 捕获注释
            if line.startswith('--') or line.startswith('/*'):
                self._capture_comment(line, line_num)
                i += 1
                continue
            
            # 匹配 END PACKAGE
            if re.match(r'END\s+(\w+)?\s*;', line, re.IGNORECASE):
                return i + 1
            
            # 匹配 FUNCTION（跨行）
            if re.match(r'FUNCTION\s+\w+', line, re.IGNORECASE):
                func = self._parse_function(lines, i, line_num)
                if func:
                    func.comment = self._consume_comment()
                    pkg.members.append(func)
                    # 跳过函数定义的剩余行
                    i = self._skip_to_semicolon(lines, i)
                    continue
            
            # 匹配 PROCEDURE（跨行）
            if re.match(r'PROCEDURE\s+\w+', line, re.IGNORECASE):
                proc = self._parse_procedure(lines, i, line_num)
                if proc:
                    proc.comment = self._consume_comment()
                    pkg.members.append(proc)
                    # 跳过过程定义的剩余行
                    i = self._skip_to_semicolon(lines, i)
                    continue
            
            i += 1
        
        return i
    
    def _parse_function(self, lines: List[str], start: int, line_num: int) -> Optional[RoutineInfo]:
        """解析函数定义"""
        # 合并多行直到找到 RETURN
        combined = ""
        for i in range(start, min(start + 10, len(lines))):
            combined += " " + lines[i].strip()
            if "RETURN" in combined.upper():
                break
        
        func_match = re.match(
            r'.*?FUNCTION\s+(\w+)\s*\(([^)]*)\)\s*RETURN\s+(\w+)',
            combined, re.IGNORECASE | re.DOTALL
        )

        if not func_match:
            return None

        name = func_match.group(1)
        params_str = func_match.group(2).strip()
        return_type = func_match.group(3)
        
        params = self._parse_params(params_str)
        
        return RoutineInfo(
            type='FUNCTION',
            name=name,
            line=line_num,
            comment=self._consume_comment(),
            params=params,
            return_type=return_type
        )
    
    def _parse_procedure(self, lines: List[str], start: int, line_num: int) -> Optional[RoutineInfo]:
        """解析过程定义"""
        # 合并多行
        combined = ""
        for i in range(start, min(start + 10, len(lines))):
            combined += " " + lines[i].strip()
            if ";" in combined:
                break
        
        proc_match = re.match(
            r'.*?PROCEDURE\s+(\w+)\s*\(([^)]*)\)',
            combined, re.IGNORECASE | re.DOTALL
        )
        
        # 如果没有参数（括号内为空或无括号）
        if not proc_match:
            proc_match = re.match(
                r'.*?PROCEDURE\s+(\w+)',
                combined, re.IGNORECASE
            )
            if not proc_match:
                return None
            name = proc_match.group(1)
            params_str = ""
        else:
            name = proc_match.group(1)
            params_str = proc_match.group(2).strip()
        
        params = self._parse_params(params_str)
        
        return RoutineInfo(
            type='PROCEDURE',
            name=name,
            line=line_num,
            comment=self._consume_comment(),
            params=params
        )
    
    def _parse_params(self, params_str: str) -> List[ParamInfo]:
        """解析参数列表"""
        if not params_str:
            return []
        
        # 清理字符串：去除换行、多余空格
        params_str = re.sub(r'\s+', ' ', params_str).strip()
        if not params_str:
            return []
        
        params = []
        # 按逗号分割
        for param_str in params_str.split(','):
            param_str = param_str.strip()
            if not param_str:
                continue
            
            # 匹配参数: name mode datatype 或 name datatype
            match = re.match(
                r'(\w+)\s+(IN\s+OUT|OUT|IN)?\s*(\w+(?:\s*\([^)]*\))?)?',
                param_str, re.IGNORECASE
            )
            if match:
                params.append(ParamInfo(
                    name=match.group(1),
                    mode=(match.group(2) or 'IN').strip(),
                    datatype=(match.group(3) or '').strip()
                ))
        
        return params
    
    def _skip_to_end_block(self, lines: List[str], start: int) -> int:
        """跳过块内容，找到 END ... ;"""
        i = start
        while i < len(lines):
            line = lines[i].strip()
            if re.match(r'END\s+(\w+)?\s*;', line, re.IGNORECASE):
                return i + 1
            i += 1
        return i
    
    def _skip_to_semicolon(self, lines: List[str], start: int) -> int:
        """跳过内容直到找到分号"""
        i = start
        while i < len(lines):
            if ';' in lines[i]:
                return i + 1
            i += 1
        return i
    
    def _count_routines(self, routine_type: str) -> int:
        """统计过程/函数数量"""
        count = 0
        for obj in self.objects:
            if isinstance(obj, PackageInfo):
                count += len([m for m in obj.members if m.type == routine_type])
            elif isinstance(obj, RoutineInfo) and obj.type == routine_type:
                count += 1
        return count


def parse_plsql_file(filepath: str, verbose=False) -> dict:
    """便捷函数：解析 PL/SQL 文件"""
    extractor = PLSQLDocExtractor()
    return extractor.parse_file(filepath, verbose)


def parse_plsql_content(content: str, verbose=False) -> dict:
    """便捷函数：解析 PL/SQL 内容字符串"""
    extractor = PLSQLDocExtractor()
    return extractor.parse_content(content, verbose)
