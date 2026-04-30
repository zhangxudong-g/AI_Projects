#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PLSQL 结构化提取工具 V2.0
将 PLSQL 代码文件提取为结构化 JSON - 完整细节版
目标：提取所有逻辑细节，作为LLM生成wiki的唯一证据
"""

import json
import re
import os
import sys
from pathlib import Path
from typing import Dict, List, Any, Optional


# 支持的编码列表
SUPPORTED_ENCODINGS = [
    "utf-8",
    "cp932",  # Windows / Oracle / 日方项目最常见
    "shift_jis",
    "gb2312",
    "gbk",
    "latin-1",
]


def read_file_with_detection(file_path: str) -> str:
    """使用自动检测编码读取文件"""
    for encoding in SUPPORTED_ENCODINGS:
        try:
            with open(file_path, "r", encoding=encoding) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    raise IOError(f"Could not read file: {file_path}")


class PLSQLExtractor:
    """PLSQL 结构化提取器 V2.0 - 完整细节版"""

    def __init__(self):
        self.output = {
            # 基本信息
            "file_name": "",
            "file_type": "",
            "identifier": {"name": "", "type": "", "description": ""},
            # 参数信息
            "parameters": [],
            "parameter_descriptions": {},  # 参数名 -> 描述
            # 结构信息
            "constants": [],
            "variables": [],
            "type_members": [],
            "select_fields": [],
            # 子程序信息
            "subprograms": [],  # 外部调用的子程序
            "internal_functions": [],  # 内部定义的函数/过程
            # SQL语句
            "sql_statements": {
                "SELECT": [],
                "INSERT": [],
                "UPDATE": [],
                "DELETE": [],
                "MERGE": [],
                "CREATE": [],
            },
            # Cursor声明和使用
            "cursors": {
                "declarations": [],  # CURSOR声明
                "usages": [],  # OPEN/FETCH/CLOSE使用
            },
            # 执行流程
            "execution_flow": [],  # 主执行流程步骤
            # 异常处理
            "exception_handling": {},  # EXCEPTION 块内容
            # 注释描述
            "header_comments": "",  # 文件头部注释
            "parameter_comments": [],  # 参数详细说明
            "change_history": [],  # 变更历史
        }

    def extract(self, file_path: str) -> Dict[str, Any]:
        """提取 PLSQL 文件"""
        path = Path(file_path)

        if not path.exists():
            raise FileNotFoundError(f"文件不存在: {file_path}")

        # 使用自动检测编码读取文件
        content = read_file_with_detection(file_path)
        self.output["file_name"] = path.name

        # 判断文件类型
        file_type = self._detect_file_type(path.name, content)
        self.output["file_type"] = file_type

        # 提取头部注释和变更历史
        self._extract_header_comments(content)

        # 根据类型提取
        if file_type == "TABLE":
            self._extract_table(content)
        elif file_type == "FUNCTION":
            self._extract_function(content)
        elif file_type == "PROCEDURE":
            self._extract_procedure(content)
        elif file_type == "VIEW":
            self._extract_view(content)
        elif file_type == "TYPE":
            self._extract_type(content)
        elif file_type == "PACKAGE":
            self._extract_package(content)
        elif file_type == "PACKAGE_BODY":
            self._extract_package_body(content)

        return self.output

    def _detect_file_type(self, file_name: str, content: str) -> str:
        """检测文件类型"""
        content_upper = content.upper()

        # 检查文件内容
        if "CREATE TABLE" in content_upper:
            return "TABLE"
        elif "CREATE OR REPLACE FORCE VIEW" in content_upper:
            return "VIEW"
        elif "CREATE OR REPLACE TYPE" in content_upper:
            return "TYPE"
        elif "CREATE OR REPLACE FUNCTION" in content_upper:
            return "FUNCTION"
        elif "CREATE OR REPLACE PROCEDURE" in content_upper:
            return "PROCEDURE"
        elif "CREATE OR REPLACE PACKAGE BODY" in content_upper:
            return "PACKAGE_BODY"
        elif "CREATE OR REPLACE PACKAGE" in content_upper:
            return "PACKAGE"
        else:
            return "UNKNOWN"

    def _extract_header_comments(self, content: str):
        """提取头部注释和变更历史"""
        # 提取文件头部注释（从文件开始到 IS 或 BEGIN 之前）
        header_match = re.search(
            r"^CREATE\s+OR\s+REPLACE\s+\w+\s+\w+.*?--.*?$(.*?)^(?:IS|BEGIN|DECLARE)",
            content,
            re.IGNORECASE | re.MULTILINE | re.DOTALL,
        )

        if header_match:
            header_text = header_match.group(1)
            # 清理注释
            lines = []
            for line in header_text.split("\n"):
                # 移除 -- 之后的注释内容
                if "--" in line:
                    line = line.split("--")[0]
                line = line.strip()
                if line:
                    lines.append(line)
            self.output["header_comments"] = "\n".join(lines)

        # 提取变更历史
        change_pattern = r"--\s*(\d{4}/\d{2}/\d{2})\s+([\w.]+)\s+(UPDATE|ADD|DELETE|FIX)\s+([\w.]+):\s*(.+?)$"
        for match in re.finditer(change_pattern, content, re.IGNORECASE | re.MULTILINE):
            self.output["change_history"].append(
                {
                    "date": match.group(1),
                    "author": match.group(2),
                    "action": match.group(3),
                    "version": match.group(4),
                    "description": match.group(5).strip(),
                }
            )

        # 提取参数详细说明
        # 匹配格式: --               i_xxx       说明
        param_desc_pattern = r"--\s+([i_o]_?\w+)\s+(.+?)$"
        for match in re.finditer(
            param_desc_pattern, content, re.IGNORECASE | re.MULTILINE
        ):
            param_name = match.group(1).strip()
            param_desc = match.group(2).strip()
            if param_name and param_desc:
                self.output["parameter_comments"].append(
                    {
                        "parameter": param_name,
                        "description": param_desc,
                    }
                )
                self.output["parameter_descriptions"][param_name] = param_desc

    def _extract_table(self, content: str):
        """提取表结构"""
        # 提取表名
        table_match = re.search(r"CREATE\s+TABLE\s+(\w+)", content, re.IGNORECASE)
        if table_match:
            self.output["identifier"]["name"] = table_match.group(1)
            self.output["identifier"]["type"] = "TABLE"

        # 提取表 COMMENT
        table_comment_match = re.search(
            r"COMMENT\s+ON\s+TABLE\s+\w+\s+IS\s+'([^']*)'", content, re.IGNORECASE
        )
        if table_comment_match:
            self.output["identifier"]["description"] = table_comment_match.group(1)

        # 提取列定义
        columns = re.findall(
            r"(\w+)\s+(NVARCHAR2|NUMBER|VARCHAR2|CHAR|DATE|CLOB|BLOB|FLOAT|INTEGER)\(?(\d+(?:,\d+)?)?\)?",
            content,
            re.IGNORECASE,
        )

        # 提取列 COMMENT
        column_comments = {}
        for match in re.finditer(
            r"COMMENT\s+ON\s+COLUMN\s+\w+\.(\w+)\s+IS\s+'([^']*)'",
            content,
            re.IGNORECASE,
        ):
            column_comments[match.group(1)] = match.group(2)

        # 构建列信息
        for col_name, col_type, col_size in columns:
            col_info = {
                "name": col_name,
                "type": f"{col_type}({col_size})" if col_size else col_type,
                "description": column_comments.get(col_name, ""),
            }
            self.output["columns"].append(col_info)

    def _extract_function(self, content: str):
        """提取函数定义 - 完整细节版"""
        # 提取函数名
        func_match = re.search(
            r"CREATE\s+OR\s+REPLACE\s+FUNCTION\s+(\w+)", content, re.IGNORECASE
        )
        if func_match:
            self.output["identifier"]["name"] = func_match.group(1)
            self.output["identifier"]["type"] = "FUNCTION"

        # 提取 RETURN 类型
        return_match = re.search(r"\)\s*RETURN\s+(\w+)", content, re.IGNORECASE)
        if return_match:
            self.output["identifier"]["description"] = f"RETURN {return_match.group(1)}"

        # 提取参数
        param_section = re.search(
            r"FUNCTION\s+\w+\s*\((.*?)\)\s*RETURN", content, re.IGNORECASE | re.DOTALL
        )
        if param_section:
            params_text = param_section.group(1)
            self._parse_parameters(params_text)

        # 提取常量声明
        self._extract_constants(content)

        # 提取变量声明
        self._extract_variables(content)

        # 提取内部函数/过程定义
        self._extract_internal_subprograms(content)

        # 提取SQL语句
        self._extract_sql_statements(content)

        # 提取执行流程
        self._extract_execution_flow(content)

        # 提取异常处理
        self._extract_exception_handling(content)

        # 提取子程序调用
        self._extract_subprograms(content)

        # 提取Cursor
        self._extract_cursors(content)

    def _extract_procedure(self, content: str):
        """提取存储过程定义 - 完整细节版"""
        # 提取过程名
        proc_match = re.search(
            r"CREATE\s+OR\s+REPLACE\s+PROCEDURE\s+(\w+)", content, re.IGNORECASE
        )
        if proc_match:
            self.output["identifier"]["name"] = proc_match.group(1)
            self.output["identifier"]["type"] = "PROCEDURE"

        # 提取参数
        param_section = re.search(
            r"PROCEDURE\s+\w+\s*\((.*?)\)", content, re.IGNORECASE | re.DOTALL
        )
        if param_section:
            params_text = param_section.group(1)
            self._parse_parameters(params_text)

        # 提取常量声明
        self._extract_constants(content)

        # 提取变量声明
        self._extract_variables(content)

        # 提取内部函数/过程定义
        self._extract_internal_subprograms(content)

        # 提取SQL语句
        self._extract_sql_statements(content)

        # 提取执行流程
        self._extract_execution_flow(content)

        # 提取异常处理
        self._extract_exception_handling(content)

        # 提取子程序调用
        self._extract_subprograms(content)

        # 提取Cursor
        self._extract_cursors(content)

    def _extract_constants(self, content: str):
        """提取常量声明"""
        # 匹配格式: c_xxx CONSTANT type := value;
        constant_pattern = r"(\w+)\s+CONSTANT\s+(\w+(?:\([^)]*\))?)\s*:=\s*([^;]+);"

        for match in re.finditer(constant_pattern, content, re.IGNORECASE):
            const_info = {
                "name": match.group(1),
                "type": match.group(2),
                "value": match.group(3).strip(),
                "description": "",
            }
            self.output["constants"].append(const_info)

    def _extract_internal_subprograms(self, content: str):
        """提取内部函数/过程定义"""
        # 找到参数列表结束后的 IS 之后的内容
        param_end = re.search(r"\)\s*(?:--[^\n]*\n)*\s*IS", content, re.IGNORECASE)
        if not param_end:
            return

        remaining = content[param_end.end() :]

        # 提取内部 FUNCTION - 从 IS 到 BEGIN 之间的内容
        func_pattern = r"FUNCTION\s+(\w+)\s*(?:\((.*?)\))?\s*RETURN\s+(\w+)"
        for match in re.finditer(func_pattern, remaining, re.IGNORECASE):
            func_name = match.group(1)
            return_type = match.group(3)
            params = match.group(2) or ""

            # 查找函数体
            func_body_pattern = rf"FUNCTION\s+{func_name}\s*(?:\([^)]*\))?\s*RETURN\s+\w+\s+IS\s+(.*?)\s*END\s+{func_name}"
            func_body_match = re.search(
                func_body_pattern, content, re.IGNORECASE | re.DOTALL
            )

            func_info = {
                "name": func_name,
                "type": "FUNCTION",
                "return_type": return_type,
                "parameters": params,
                "description": "",
            }

            if func_body_match:
                body_content = func_body_match.group(1)
                # 提取函数内的局部变量 - 支持更多类型
                local_vars = re.findall(
                    r"(\w+)\s+(PLS_INTEGER|NUMBER|NVARCHAR2|VARCHAR2|DATE|CHAR|BOOLEAN|REF\s+CURSOR)\s*(?::=\s*([^;]+))?",
                    body_content,
                    re.IGNORECASE,
                )
                # 也提取 %ROWTYPE 类型
                rowtype_vars = re.findall(
                    r"(\w+)\s+(\w+%ROWTYPE)\s*(?::=\s*([^;]+))?",
                    body_content,
                    re.IGNORECASE,
                )

                all_vars = local_vars + rowtype_vars
                if all_vars:
                    func_info["local_variables"] = [
                        {
                            "name": v[0],
                            "type": v[1],
                            "default": v[2] if v[2] else "",
                            "description": "",
                        }
                        for v in all_vars
                    ]

                # 提取函数内的SQL
                sql_in_func = self._extract_sql_from_section(body_content)
                if any(sql_in_func.values()):
                    func_info["sql_statements"] = sql_in_func

            # 检查函数是否有注释描述
            func_comment = re.search(
                rf"FUNCTION\s+{func_name}.*?--\s*(.+?)$",
                content,
                re.IGNORECASE | re.MULTILINE,
            )
            if func_comment:
                func_info["description"] = func_comment.group(1).strip()

            self.output["internal_functions"].append(func_info)

        # 提取内部 PROCEDURE
        proc_pattern = r"PROCEDURE\s+(\w+)\s*(?:\((.*?)\))?"
        for match in re.finditer(proc_pattern, remaining, re.IGNORECASE):
            proc_name = match.group(1)
            params = match.group(2) or ""

            # 查找过程体
            proc_body_pattern = rf"PROCEDURE\s+{proc_name}\s*(?:\([^)]*\))?\s+IS\s+(.*?)\s*END\s+{proc_name}"
            proc_body_match = re.search(
                proc_body_pattern, content, re.IGNORECASE | re.DOTALL
            )

            proc_info = {
                "name": proc_name,
                "type": "PROCEDURE",
                "parameters": params,
                "description": "",
            }

            if proc_body_match:
                body_content = proc_body_match.group(1)
                local_vars = re.findall(
                    r"(\w+)\s+(PLS_INTEGER|NUMBER|NVARCHAR2|VARCHAR2|DATE|CHAR|BOOLEAN)\s*(?::=\s*([^;]+))?",
                    body_content,
                    re.IGNORECASE,
                )
                rowtype_vars = re.findall(
                    r"(\w+)\s+(\w+%ROWTYPE)\s*(?::=\s*([^;]+))?",
                    body_content,
                    re.IGNORECASE,
                )

                all_vars = local_vars + rowtype_vars
                if all_vars:
                    proc_info["local_variables"] = [
                        {
                            "name": v[0],
                            "type": v[1],
                            "default": v[2] if v[2] else "",
                            "description": "",
                        }
                        for v in all_vars
                    ]

                sql_in_proc = self._extract_sql_from_section(body_content)
                if any(sql_in_proc.values()):
                    proc_info["sql_statements"] = sql_in_proc

            # 检查过程是否有注释描述
            proc_comment = re.search(
                rf"PROCEDURE\s+{proc_name}.*?--\s*(.+?)$",
                content,
                re.IGNORECASE | re.MULTILINE,
            )
            if proc_comment:
                proc_info["description"] = proc_comment.group(1).strip()

            self.output["internal_functions"].append(proc_info)

    def _extract_sql_from_section(self, section_content: str) -> Dict[str, List[str]]:
        """从代码段中提取SQL语句"""
        result = {
            "SELECT": [],
            "INSERT": [],
            "UPDATE": [],
            "DELETE": [],
            "MERGE": [],
            "CREATE": [],
        }

        # 直接按关键字模式提取

        # 静态SELECT - 使用增强的解析器
        for m in re.finditer(
            r"(?:^|\n)(SELECT\s+.*?FROM\s+.*?)(?=\s*[;=]|\n\n|\n/|\Z)",
            section_content,
            re.IGNORECASE | re.DOTALL,
        ):
            sql = m.group(1).strip()
            if len(sql) > 20:
                # 使用增强的解析器提取各部分
                parsed = self._parse_select_sql(sql)
                result["SELECT"].append(parsed)

        # 动态SQL - VSQL := 'SELECT ...'
        for m in re.finditer(
            r"(\w+)\s*:=\s*'SELECT\s+(.*?)'", section_content, re.IGNORECASE | re.DOTALL
        ):
            result["SELECT"].append(
                f"-- Dynamic {m.group(1)}: SELECT {m.group(2)[:100]}"
            )

        # 动态SQL - OPEN CURSOR FOR
        for m in re.finditer(
            r"OPEN\s+(\w+)\s+FOR\s+(SELECT\s+.*?)(?=\s*[;=]|$)",
            section_content,
            re.IGNORECASE | re.DOTALL,
        ):
            result["SELECT"].append(f"-- Cursor {m.group(1)}: {m.group(2)[:100]}")

        # 动态SQL - EXECUTE IMMEDIATE
        for m in re.finditer(
            r"EXECUTE\s+IMMEDIATE\s+'([^']+)'", section_content, re.IGNORECASE
        ):
            result["SELECT"].append(f"-- EXECUTE: {m.group(1)[:100]}")

        # INSERT
        for m in re.finditer(
            r"INSERT\s+INTO\s+(\w+(?:\.\w+)?).*?VALUES\s+.*?;",
            section_content,
            re.IGNORECASE | re.DOTALL,
        ):
            result["INSERT"].append(m.group(0)[:200])

        # UPDATE
        for m in re.finditer(
            r"UPDATE\s+(\w+(?:\.\w+)?)\s+SET\s+.*?;",
            section_content,
            re.IGNORECASE | re.DOTALL,
        ):
            result["UPDATE"].append(m.group(0)[:200])

        # DELETE
        for m in re.finditer(
            r"DELETE\s+FROM\s+(\w+(?:\.\w+)?).*?;",
            section_content,
            re.IGNORECASE | re.DOTALL,
        ):
            result["DELETE"].append(m.group(0)[:200])

        # FETCH
        for m in re.finditer(
            r"FETCH\s+(\w+)\s+INTO\s+(\w+)", section_content, re.IGNORECASE
        ):
            result["SELECT"].append(f"-- Fetch {m.group(1)} -> {m.group(2)}")

        # 去重
        for key in result:
            result[key] = list(dict.fromkeys(result[key]))

        return result

    def _parse_select_sql(self, sql: str) -> Dict[str, Any]:
        """解析SELECT语句，提取各部分"""
        # 首先移除注释
        sql_clean = re.sub(r"--[^\n]*\n", "\n", sql)
        sql_clean = re.sub(r"--[^\n]*", "", sql_clean)

        result = {
            "raw": sql_clean[:500],  # 使用清理后的SQL
            "columns": [],
            "tables": [],
            "joins": [],
            "where": "",
            "group_by": "",
            "order_by": "",
            "having": "",
            "subqueries": [],
        }

        # 提取列 - 完整处理
        columns_match = re.search(
            r"SELECT\s+(.*?)\s+FROM", sql_clean, re.IGNORECASE | re.DOTALL
        )
        if columns_match:
            cols = columns_match.group(1).strip()
            if "*" in cols:
                result["columns"] = ["*"]
            else:
                # 处理列的别名和表达式
                col_list = self._split_by_comma_balanced(cols)
                for c in col_list:
                    c = c.strip()
                    # 提取 AS 别名
                    alias_match = re.search(r"\s+AS\s+(\w+)", c, re.IGNORECASE)
                    if alias_match:
                        result["columns"].append(f"{c} AS {alias_match.group(1)}")
                    else:
                        result["columns"].append(c)

        # 提取表 - 处理多表和子查询 (使用清理后的SQL)
        from_match = re.search(
            r"FROM\s+(.*?)(?:WHERE|GROUP|ORDER|HAVING|UNION|$)",
            sql_clean,
            re.IGNORECASE | re.DOTALL,
        )
        if from_match:
            from_text = from_match.group(1).strip()
            # 检查是否有子查询
            if "(" in from_text and "SELECT" in from_text.upper():
                # 提取子查询
                subqs = re.findall(r"\((.*?)\)", from_text, re.IGNORECASE | re.DOTALL)
                for sq in subqs:
                    if "SELECT" in sq.upper():
                        result["subqueries"].append(sq.strip()[:200])
                # 提取表名
                tables = re.findall(
                    r"(?:FROM\s+)?(\w+(?:\.\w+)?)", from_text, re.IGNORECASE
                )
                result["tables"] = [
                    t for t in tables if t.upper() not in ["SELECT", "FROM"]
                ]
            else:
                # 简单表名提取
                tables = re.findall(r"(\w+(?:\.\w+)?)", from_text)
                result["tables"] = [
                    t for t in tables if t.upper() not in ["SELECT", "FROM"]
                ]

        # 提取JOIN - 完整处理 (使用清理后的SQL)
        # 匹配各种JOIN类型: INNER JOIN, LEFT JOIN, RIGHT JOIN, JOIN等
        # alias可以是可选的
        join_pattern = r"(?:(\w+)\s+)?JOIN\s+(\w+(?:\.\w+)?)(?:\s+(\w+))?\s+ON\s+(.+?)(?=WHERE|GROUP|ORDER|HAVING|;|$)"
        joins = re.findall(join_pattern, sql_clean, re.IGNORECASE | re.DOTALL)
        for j in joins:
            join_type = (j[0].strip() if j[0] else "JOIN").upper()
            if join_type not in ["INNER", "LEFT", "RIGHT", "OUTER", "FULL", "JOIN"]:
                join_type = "JOIN"
            join_table = j[1]
            # j[2] is alias (may be empty), j[3] is ON condition
            join_alias = j[2] if j[2] else ""
            join_on = j[3].strip()[:100]
            result["joins"].append(
                {
                    "type": join_type,
                    "table": join_table,
                    "alias": join_alias,
                    "on": join_on,
                }
            )

        # 提取WHERE - 完整条件
        where_match = re.search(
            r"WHERE\s+(.*?)(?=\s+GROUP|\s+ORDER|\s+HAVING|;|$)",
            sql_clean,
            re.IGNORECASE | re.DOTALL,
        )
        if where_match:
            result["where"] = where_match.group(1).strip()

        # 提取GROUP BY
        group_match = re.search(
            r"GROUP\s+BY\s+(.*?)(?=\s+HAVING|\s+ORDER|;|$)",
            sql_clean,
            re.IGNORECASE,
        )
        if group_match:
            result["group_by"] = group_match.group(1).strip()

        # 提取HAVING
        having_match = re.search(
            r"HAVING\s+(.*?)(?=\s+ORDER|;|$)",
            sql_clean,
            re.IGNORECASE,
        )
        if having_match:
            result["having"] = having_match.group(1).strip()

        # 提取ORDER BY
        order_match = re.search(r"ORDER\s+BY\s+(.*?)(?:;|$)", sql_clean, re.IGNORECASE)
        if order_match:
            result["order_by"] = order_match.group(1).strip()

        return result

    def _split_by_comma_balanced(self, text: str) -> List[str]:
        """智能按逗号分割，忽略括号内的逗号"""
        parts = []
        bracket_depth = 0
        current = ""

        for char in text:
            if char in "([{":
                bracket_depth += 1
                current += char
            elif char in ")]}":
                bracket_depth -= 1
                current += char
            elif char == "," and bracket_depth == 0:
                if current.strip():
                    parts.append(current.strip())
                current = ""
            else:
                current += char

        if current.strip():
            parts.append(current.strip())

        return parts

    def _extract_sql_statements(self, content: str):
        """提取SQL语句"""
        # 找到参数列表结束后的声明区，然后找到主 BEGIN
        param_end = re.search(r"\)\s*(?:--[^\n]*\n)*\s*IS", content, re.IGNORECASE)
        if not param_end:
            return

        remaining = content[param_end.end() :]

        # 找到最后一个内部函数/过程的声明
        subprogram_decls = list(
            re.finditer(r"(?:PROCEDURE|FUNCTION)\s+\w+", remaining, re.IGNORECASE)
        )

        if not subprogram_decls:
            return

        # 找到该声明的结束位置 (END xxx;)
        last_decl = subprogram_decls[-1]
        after_decl = remaining[last_decl.start() :]

        # 在声明之后找 END xxx;
        end_match = re.search(r"END\s+\w+\s*;", after_decl, re.IGNORECASE)
        if not end_match:
            return

        # END 之后就是主代码
        main_section = after_decl[end_match.end() :]

        # 提取到 EXCEPTION 或 END 之前
        main_match = re.search(
            r"(.*?)(?:EXCEPTION|END\s+)", main_section, re.IGNORECASE | re.DOTALL
        )
        if main_match:
            main_content = main_match.group(1)
            sql_result = self._extract_sql_from_section(main_content)

            for stmt_type, statements in sql_result.items():
                self.output["sql_statements"][stmt_type].extend(statements)

    def _extract_execution_flow(self, content: str):
        """提取执行流程 - 增强版，包含IF/LOOP条件分支"""
        param_end = re.search(r"\)\s*(?:--[^\n]*\n)*\s*IS", content, re.IGNORECASE)
        if not param_end:
            return

        remaining = content[param_end.end() :]

        # 找到最后一个内部函数/过程
        subprogram_decls = list(
            re.finditer(r"(?:PROCEDURE|FUNCTION)\s+\w+", remaining, re.IGNORECASE)
        )

        if not subprogram_decls:
            return

        last_decl = subprogram_decls[-1]
        after_decl = remaining[last_decl.start() :]

        # 找 END xxx;
        end_match = re.search(r"END\s+\w+\s*;", after_decl, re.IGNORECASE)
        if not end_match:
            return

        # 主代码在 END 之后
        main_section = after_decl[end_match.end() :]
        main_match = re.search(
            r"(.*?)(?:EXCEPTION|END\s+)", main_section, re.IGNORECASE | re.DOTALL
        )

        if main_match:
            main_flow = main_match.group(1)

            steps = []
            # 提取IF条件分支
            if_pattern = r"(IF|ELSIF)\s+(.*?)\s+THEN"
            for m in re.finditer(if_pattern, main_flow, re.IGNORECASE | re.DOTALL):
                condition = m.group(2).strip()[:100]
                steps.append(
                    {
                        "type": "IF_CONDITION",
                        "condition": condition,
                    }
                )

            # 提取ELSE分支
            for m in re.finditer(r"ELSE", main_flow, re.IGNORECASE):
                steps.append({"type": "ELSE", "content": "ELSE branch"})

            # 提取LOOP循环
            loop_pattern = r"(LOOP|WHILE\s+(.*?)\s+LOOP|FOR\s+(.*?)\s+LOOP)"
            for m in re.finditer(loop_pattern, main_flow, re.IGNORECASE | re.DOTALL):
                loop_text = m.group(0).strip()[:100]
                steps.append(
                    {
                        "type": "LOOP",
                        "content": loop_text,
                    }
                )

            # 提取EXIT WHEN
            for m in re.finditer(
                r"EXIT\s+WHEN\s+(.*?)(?:\s|;|$)", main_flow, re.IGNORECASE
            ):
                steps.append(
                    {
                        "type": "EXIT_WHEN",
                        "condition": m.group(1).strip()[:50],
                    }
                )

            # 提取SELECT语句
            for line in main_flow.split("\n"):
                line = line.strip()
                if not line or line.startswith("--"):
                    continue

                if re.match(r"SELECT\s+", line, re.IGNORECASE):
                    # 使用增强解析器
                    parsed = self._parse_select_sql(line)
                    steps.append({"type": "SELECT", "content": parsed})
                elif "INSERT" in line.upper():
                    steps.append({"type": "INSERT", "content": line[:150]})
                elif "UPDATE" in line.upper():
                    steps.append({"type": "UPDATE", "content": line[:150]})
                elif "DELETE" in line.upper():
                    steps.append({"type": "DELETE", "content": line[:150]})
                elif line.endswith(";") and "(" in line:
                    call_match = re.search(r"(\w+)\s*\(", line, re.IGNORECASE)
                    if call_match:
                        steps.append({"type": "CALL", "content": call_match.group(1)})

            self.output["execution_flow"] = steps

    def _extract_exception_handling(self, content: str):
        """提取 EXCEPTION 处理块"""
        # 策略：找到主过程/函数的 END 之前的 EXCEPTION 块

        # 找到主过程/函数的 END (与过程名相同的 END)
        # 对于 PROCEDURE GKBSBCHKLCSV，找到 END GKBSBCHKLCSV;
        proc_match = re.search(
            r"CREATE\s+OR\s+REPLACE\s+PROCEDURE\s+(\w+)", content, re.IGNORECASE
        )
        if not proc_match:
            proc_match = re.search(
                r"CREATE\s+OR\s+REPLACE\s+FUNCTION\s+(\w+)", content, re.IGNORECASE
            )

        if not proc_match:
            return

        proc_name = proc_match.group(1)

        # 找到 END proc_name;
        main_end = re.search(rf"END\s+{proc_name}\s*;", content, re.IGNORECASE)
        if not main_end:
            return

        # 找到最后一个内部函数/过程的结束位置
        # 方法：找到最后一个 END xxx; (不是 END IF/LOOP 等)
        before_main = content[: main_end.start()]

        # 找到最后一个有名称的 END (不是 END IF/LOOP/等)
        all_ends = list(re.finditer(r"END\s+(\w+)\s*;", before_main, re.IGNORECASE))
        if not all_ends:
            return

        last_named_end = all_ends[-1]

        # 在最后内部函数结束和主END之间找EXCEPTION
        between = content[last_named_end.end() : main_end.start()]

        exception_match = re.search(
            r"EXCEPTION\s*(.*?)(?:END\s+|$)", between, re.IGNORECASE | re.DOTALL
        )

        if exception_match:
            exception_content = exception_match.group(1)

            exception_info = {
                "has_others": False,
                "actions": [],
            }

            # 提取 WHEN OTHERS 处理
            when_others = re.search(
                r"WHEN\s+OTHERS\s+THEN\s+(.*?)(?:WHEN|END|$)",
                exception_content,
                re.IGNORECASE | re.DOTALL,
            )

            if when_others:
                exception_info["has_others"] = True
                others_content = when_others.group(1).strip()

                # 提取关键操作
                if "SQLERRM" in others_content:
                    exception_info["actions"].append("LOG_SQLERRM")
                if "SQLCODE" in others_content:
                    exception_info["actions"].append("LOG_SQLCODE")
                if "ROLLBACK" in others_content.upper():
                    exception_info["actions"].append("ROLLBACK")

                # 提取日志调用 (包含 ERR 或 LOG 的函数调用)
                log_calls = re.findall(
                    r"(\w+)\s*\([^)]*(?:ERR|LOG|SQL)[^)]*\)",
                    others_content,
                    re.IGNORECASE,
                )
                for call in log_calls:
                    exception_info["actions"].append(f"CALL_{call}")

                # 提取错误消息内容
                err_msg = re.search(
                    r"SUBSTR\s*\(\s*'([^']+)", others_content, re.IGNORECASE
                )
                if err_msg:
                    exception_info["actions"].append(f"ERR_MSG: {err_msg.group(1)}")

            # 提取其他 WHEN 子句
            when_clauses = re.findall(
                r"WHEN\s+(\w+)\s+THEN\s+(.*?)(?:WHEN|END|$)",
                exception_content,
                re.IGNORECASE | re.DOTALL,
            )
            for when_name, when_action in when_clauses:
                exception_info["actions"].append(
                    f"WHEN_{when_name}: {when_action.strip()[:50]}"
                )

            self.output["exception_handling"] = exception_info

    def _extract_cursors(self, content: str):
        """提取Cursor声明和使用"""
        # 提取Cursor声明
        cursor_pattern = r"CURSOR\s+(\w+)\s*\((.*?)\)\s*(?:IS\s+(SELECT.*?))?"
        for match in re.finditer(cursor_pattern, content, re.IGNORECASE | re.DOTALL):
            cursor_name = match.group(1)
            cursor_params = match.group(2) or ""
            cursor_sql = match.group(3) or ""

            cursor_info = {
                "name": cursor_name,
                "parameters": cursor_params.strip(),
                "sql": cursor_sql.strip()[:300] if cursor_sql else "",
            }
            self.output["cursors"]["declarations"].append(cursor_info)

        # 提取Cursor使用 (OPEN/FETCH/CLOSE)
        # OPEN cursor_name FOR SELECT...
        for m in re.finditer(
            r"OPEN\s+(\w+)\s+FOR\s+(SELECT\s+.*?)(?=\s*[;=]|$)",
            content,
            re.IGNORECASE | re.DOTALL,
        ):
            self.output["cursors"]["usages"].append(
                {
                    "type": "OPEN_FOR",
                    "cursor": m.group(1),
                    "sql": m.group(2).strip()[:300],
                }
            )

        # OPEN cursor_name FOR Dynamic_SQL
        for m in re.finditer(
            r"OPEN\s+(\w+)\s+FOR\s+('.*?')", content, re.IGNORECASE | re.DOTALL
        ):
            self.output["cursors"]["usages"].append(
                {
                    "type": "OPEN_DYNAMIC",
                    "cursor": m.group(1),
                    "sql": m.group(2).strip()[:200],
                }
            )

        # FETCH cursor INTO...
        for m in re.finditer(r"FETCH\s+(\w+)\s+INTO\s+(.*?);", content, re.IGNORECASE):
            self.output["cursors"]["usages"].append(
                {
                    "type": "FETCH_INTO",
                    "cursor": m.group(1),
                    "target": m.group(2).strip(),
                }
            )

        # CLOSE cursor
        for m in re.finditer(r"CLOSE\s+(\w+)", content, re.IGNORECASE):
            self.output["cursors"]["usages"].append(
                {
                    "type": "CLOSE",
                    "cursor": m.group(1),
                }
            )

    def _extract_view(self, content: str):
        """提取视图定义 - 完整SQL版"""
        # 提取视图名
        view_match = re.search(
            r"CREATE\s+OR\s+REPLACE\s+FORCE\s+VIEW\s+(\w+)", content, re.IGNORECASE
        )
        if view_match:
            self.output["identifier"]["name"] = view_match.group(1)
            self.output["identifier"]["type"] = "VIEW"

        # 提取完整SELECT语句 - 使用更精确的方法
        # 找到 AS 之后到 From 之前的部分（列），然后找到 Where 之后的部分（条件）

        # 1. 提取列部分 - 从 SELECT 到 FROM
        columns_match = re.search(
            r"AS\s*\n\s*Select\s+(.*?)\n\s*(?:From|FROM)",
            content,
            re.IGNORECASE | re.DOTALL,
        )

        # 2. 提取FROM和表部分 - 从 FROM 到 WHERE
        from_match = re.search(
            r"(?:From|FROM)\s+(.*?)\n\s*(?:Where|WHERE)",
            content,
            re.IGNORECASE | re.DOTALL,
        )

        # 3. 提取WHERE条件
        where_match = re.search(
            r"(?:Where|WHERE)\s+(.*?)(?:\n/\s*|$)",
            content,
            re.IGNORECASE | re.DOTALL,
        )

        # 构建完整的SQL
        full_sql = ""
        if columns_match:
            full_sql = "Select " + columns_match.group(1).strip()
        if from_match:
            full_sql += " From " + from_match.group(1).strip()
        if where_match:
            full_sql += " Where " + where_match.group(1).strip()

        if full_sql:
            # 使用增强解析器解析完整SQL
            parsed = self._parse_select_sql(full_sql)
            self.output["sql_statements"]["SELECT"].append(parsed)

        # 提取 SELECT 字段 - 获取完整的别名.字段名 (保留原有功能)
        select_match = re.search(
            r"AS\s*\n\s*Select\s+(.*?)From", content, re.IGNORECASE | re.DOTALL
        )
        if select_match:
            select_text = select_match.group(1)
            # 直接提取 A.COLUMN_NAME 格式
            for match in re.finditer(r"(\w+)\.(\w+)", select_text):
                table_alias = match.group(1)
                col_name = match.group(2)
                full_name = f"{table_alias}.{col_name}"
                if full_name not in self.output["select_fields"]:
                    self.output["select_fields"].append(full_name)

    def _extract_type(self, content: str):
        """提取类型定义"""
        # 提取类型名
        type_match = re.search(
            r"CREATE\s+OR\s+REPLACE\s+TYPE\s+\w+\s+FORCE\s+AS\s+OBJECT",
            content,
            re.IGNORECASE,
        )
        if type_match:
            type_name_match = re.search(
                r"CREATE\s+OR\s+REPLACE\s+TYPE\s+(\w+)", content, re.IGNORECASE
            )
            if type_name_match:
                self.output["identifier"]["name"] = type_name_match.group(1)
                self.output["identifier"]["type"] = "TYPE"

            # 提取成员变量 - 直接在对象内查找
            # 找到 AS OBJECT 之后到结束的内容
            obj_start = content.find("AS OBJECT")
            if obj_start >= 0:
                # AS OBJECT 是10个字符
                obj_content = content[obj_start + 10 :]  # 跳过 "AS OBJECT "
                # 找到配对的括号
                depth = 0
                members_end = 0
                for i, c in enumerate(obj_content):
                    if c == "(":
                        depth += 1
                    elif c == ")":
                        depth -= 1
                        if depth == 0:
                            members_end = i
                            break

                members_text = (
                    obj_content[1:members_end] if members_end > 0 else obj_content
                ).strip()

                # 移除所有注释 (-- 之后的行，直到换行)
                # 先按换行分割，处理每行中的注释
                lines_with_comments = members_text.split("\n")
                cleaned_lines = []
                for line in lines_with_comments:
                    if "--" in line:
                        line = line.split("--")[0]  # 移除 -- 之后的注释
                    cleaned_lines.append(line.strip())

                # 重新合并清理后的行
                members_text = "\n".join(cleaned_lines)

                # 智能分割成员（忽略括号内的逗号）
                member_lines = []
                bracket_depth = 0
                current_line = ""

                for char in members_text:
                    if char == "(":
                        bracket_depth += 1
                        current_line += char
                    elif char == ")":
                        bracket_depth -= 1
                        current_line += char
                    elif char == "," and bracket_depth == 0:
                        if current_line.strip():
                            member_lines.append(current_line.strip())
                        current_line = ""
                    else:
                        current_line += char

                if current_line.strip():
                    member_lines.append(current_line.strip())

                for line in member_lines:
                    # 匹配: 名称 类型, 或 名称 类型(长度)
                    # 类型可能是 NUMBER, NVARCHAR2(1000) 等
                    member_match = re.match(r"(\w+)\s+(\w+(?:\([^)]*\))?)", line)
                    if member_match:
                        member = {
                            "name": member_match.group(1),
                            "type": member_match.group(2),
                            "description": "",
                        }
                        self.output["type_members"].append(member)

    def _extract_package(self, content: str):
        """提取包定义(PACKAGE)"""
        # 提取包名
        pkg_match = re.search(
            r"CREATE\s+OR\s+REPLACE\s+PACKAGE\s+(\w+)", content, re.IGNORECASE
        )
        if pkg_match:
            self.output["identifier"]["name"] = pkg_match.group(1)
            self.output["identifier"]["type"] = "PACKAGE"

        # 从注释中提取功能描述
        # 查找 "--  機能概要    : xxx" 或 "--  @\t@m      : xxx" 格式
        desc_match = re.search(
            r"--\s*[機能概要|機能説明|機能]\s*:\s*(.+?)$",
            content,
            re.IGNORECASE | re.MULTILINE,
        )
        if desc_match:
            self.output["identifier"]["description"] = desc_match.group(1).strip()

        # 提取包中的过程和函数声明 (在 IS ... END 之间的声明部分)
        # 匹配 PROCEDURE/FUNCTION 声明
        proc_func_pattern = r"(PROCEDURE|FUNCTION)\s+(\w+)"
        for match in re.finditer(proc_func_pattern, content, re.IGNORECASE):
            sub_type = match.group(1).upper()
            sub_name = match.group(2)
            # 跳过包名本身
            if sub_name != self.output["identifier"]["name"]:
                sub_info = {
                    "name": sub_name,
                    "type": sub_type,
                    "description": "",
                }
                self.output["subprograms"].append(sub_info)

    def _extract_package_body(self, content: str):
        """提取包体(PACKAGE BODY) - 完整细节版"""
        # 提取包名
        pkg_match = re.search(
            r"CREATE\s+OR\s+REPLACE\s+PACKAGE\s+BODY\s+(\w+)",
            content,
            re.IGNORECASE,
        )
        if pkg_match:
            self.output["identifier"]["name"] = pkg_match.group(1)
            self.output["identifier"]["type"] = "PACKAGE_BODY"

        # 提取常量声明
        self._extract_constants(content)

        # 提取变量声明
        self._extract_variables(content)

        # 提取内部函数/过程定义
        self._extract_internal_subprograms(content)

        # 提取SQL语句
        self._extract_sql_statements(content)

        # 提取执行流程
        self._extract_execution_flow(content)

        # 提取异常处理
        self._extract_exception_handling(content)

        # 提取子程序调用
        self._extract_subprograms(content)

        # 提取Cursor
        self._extract_cursors(content)

    def _parse_parameters(self, params_text: str):
        """解析参数列表"""
        # 清理注释
        params_text = re.sub(r"--.*$", "", params_text, flags=re.MULTILINE)

        # 按逗号分割（但要忽略括号内的逗号）
        params = []
        bracket_depth = 0
        current_param = ""

        for char in params_text:
            if char == "(":
                bracket_depth += 1
                current_param += char
            elif char == ")":
                bracket_depth -= 1
                current_param += char
            elif char == "," and bracket_depth == 0:
                if current_param.strip():
                    params.append(current_param.strip())
                current_param = ""
            else:
                current_param += char

        if current_param.strip():
            params.append(current_param.strip())

        # 解析每个参数
        for param in params:
            param = param.strip()
            if not param:
                continue

            # 匹配参数格式: i_nKOJIN_NO IN NUMBER 或 o_sSHIMEIKANA OUT NVARCHAR2
            match = re.match(
                r"(i_|o_|io_)?(\w+)\s+(IN|OUT|IN\s*OUT)\s+(\w+(?:\(\d+(?:,\d+)?\))?)",
                param,
                re.IGNORECASE,
            )
            if match:
                prefix = match.group(1) or ""
                name = match.group(2)
                direction = match.group(3).replace(" ", " ").upper()
                ptype = match.group(4)

                param_info = {
                    "name": name,
                    "type": ptype,
                    "direction": direction,
                    "description": "",
                }
                self.output["parameters"].append(param_info)

    def _extract_variables(self, content: str):
        """提取变量声明 - 主过程/函数的变量"""
        # 策略：
        # 1. 找到参数列表结束 )
        # 2. 从该位置向后找到主 BEGIN（通常是最后一个非内部函数的 BEGIN）
        # 3. 在 IS 和这个主 BEGIN 之间提取变量

        # 找到参数列表结束位置
        param_end = re.search(r"\)\s*(?:--[^\n]*\n)*\s*IS", content, re.IGNORECASE)

        if not param_end:
            return

        # 找到所有 FUNCTION/PROCEDURE 声明（CREATE OR REPLACE 之后）
        subprogram_decls = list(
            re.finditer(
                r"(?:PROCEDURE|FUNCTION)\s+\w+",
                content[param_end.end() :],
                re.IGNORECASE,
            )
        )

        if not subprogram_decls:
            return

        # 找到最后一个内部声明的结束位置
        # 向前查找 "END xxx;" 模式来定位内部函数的结束
        last_decl = subprogram_decls[-1]
        remaining = content[param_end.end() + last_decl.start() :]

        # 找 END xxx; 模式
        end_match = re.search(r"END\s+\w+\s*;", remaining, re.IGNORECASE)
        if not end_match:
            return

        # 声明区域从参数结束到最后一个内部函数结束之后
        decl_section = content[
            param_end.end() : param_end.end() + last_decl.start() + end_match.end()
        ]

        # 提取变量声明
        var_patterns = [
            r"(\w+)\s+(PLS_INTEGER|NUMBER|NVARCHAR2|VARCHAR2|DATE|CHAR|BOOLEAN)\s*(?::=\s*([^;]+))?",
            r"(\w+)\s+(\w+\.\w+%TYPE)\s*(?::=\s*([^;]+))?",
            r"(\w+)\s+(\w+_(RECORD|TYPE))\s*(?::=\s*([^;]+))?",
            r"(\w+)\s+(\w+%ROWTYPE)\s*(?::=\s*([^;]+))?",
        ]

        for pattern in var_patterns:
            for match in re.finditer(pattern, decl_section, re.IGNORECASE):
                var_name = match.group(1)
                var_type = match.group(2)
                default_val = match.group(3) if match.group(3) else ""

                if var_name not in [
                    "IS",
                    "BEGIN",
                    "END",
                    "LOOP",
                    "IF",
                    "THEN",
                    "ELSE",
                    "ELSIF",
                    "CASE",
                    "WHEN",
                    "RETURN",
                    "OUT",
                    "IN",
                    "TYPE",
                    "CURSOR",
                    "EXCEPTION",
                    "CONSTANT",
                    "REF",
                    "FUNCTION",
                    "PROCEDURE",
                ]:
                    var_info = {
                        "name": var_name,
                        "type": var_type,
                        "default": default_val.strip() if default_val else "",
                        "description": "",
                    }

                    # 尝试提取变量注释 (-- 注释内容)
                    # 在变量声明后查找注释
                    var_pattern_for_comment = (
                        rf"{re.escape(var_name)}\s+{re.escape(var_type)}"
                    )
                    var_match = re.search(
                        var_pattern_for_comment, decl_section, re.IGNORECASE
                    )
                    if var_match:
                        # 在变量声明后查找 -- 注释
                        after_var = decl_section[
                            var_match.end() : var_match.end() + 100
                        ]
                        comment_match = re.search(
                            r"--\s*(.+?)$", after_var, re.MULTILINE
                        )
                        if comment_match:
                            var_info["description"] = comment_match.group(1).strip()

                    self.output["variables"].append(var_info)

    def _extract_subprograms(self, content: str):
        """提取子程序调用"""
        # 提取函数调用 - 更精确的匹配
        # 1. 函数调用: FUNC_NAME(
        # 2. 排除SQL关键字和类型名
        func_calls = re.findall(r"\b(\w+)\s*\(", content)

        # 过滤并去重
        known_funcs = set()
        sql_keywords = {
            "SELECT",
            "FROM",
            "WHERE",
            "AND",
            "OR",
            "IF",
            "LOOP",
            "END",
            "BEGIN",
            "RETURN",
            "IS",
            "THEN",
            "ELSE",
            "ELSIF",
            "CASE",
            "WHEN",
            "ORDER",
            "BY",
            "GROUP",
            "HAVING",
            "UNION",
            "INSERT",
            "UPDATE",
            "DELETE",
            "CREATE",
            "DROP",
            "ALTER",
            "EXEC",
            "EXECUTE",
            "FETCH",
            "OPEN",
            "CLOSE",
            "COMMIT",
            "ROLLBACK",
            "NOT",
            "INTO",
            "VALUES",
            "SET",
            "DECLARE",
            "FOR",
            "WHILE",
            "EXIT",
            "CONTINUE",
            "RAISE",
            "GOTO",
            "SQL",
            "NULL",
        }
        # PL/SQL类型名
        type_names = {
            "VARCHAR2",
            "NVARCHAR2",
            "NUMBER",
            "INTEGER",
            "PLS_INTEGER",
            "DATE",
            "CHAR",
            "CLOB",
            "BLOB",
            "BOOLEAN",
            "RAW",
            "LONG",
            "RECORD",
            "REF",
            "CURSOR",
            "TYPE",
            "TABLE",
            "VARRAY",
            "BINARY_INTEGER",
            "TIMESTAMP",
            "INTERVAL",
        }

        for func_name in func_calls:
            upper_name = func_name.upper()
            if upper_name not in sql_keywords and upper_name not in type_names:
                if len(func_name) > 2:  # 过滤过短的
                    known_funcs.add(func_name)

        for func_name in sorted(known_funcs):
            sub_info = {"name": func_name, "type": "FUNCTION", "description": ""}
            self.output["subprograms"].append(sub_info)


def extract_file(file_path: str) -> Dict[str, Any]:
    """提取单个文件"""
    extractor = PLSQLExtractor()
    return extractor.extract(file_path)


def extract_directory(dir_path: str, output_dir: str = "output"):
    """提取目录下的所有SQL文件"""
    # results = []
    path = Path(dir_path)

    # 创建输出目录
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)

    for sql_file in path.rglob("*.sql"):
        # 跳过已生成的JSON文件
        if sql_file.suffix == ".json":
            continue
        try:
            result = extract_file(str(sql_file))
            # results.append(result)

            # 保存单个文件JSON到输出目录
            json_path = output_path / f"{sql_file.stem}.json"
            with open(json_path, "w", encoding="utf-8") as f:
                json.dump(result, f, ensure_ascii=False, indent=2)

            # 同时保存源码副本
            # src_path = output_path / f"{sql_file.name}"
            # with open(src_path, "w", encoding="utf-8") as f:
            #     f.write(result.get("source_code", ""))

            print(f"✓ 提取完成: {sql_file.name}")
        except Exception as e:
            print(f"✗ 提取失败: {sql_file.name} - {e}")

    # # 写入汇总JSON
    # summary_file = output_path / "summary.json"
    # with open(summary_file, "w", encoding="utf-8") as f:
    #     json.dump(results, f, ensure_ascii=False, indent=2)

    # print(f"\n共提取 {len(results)} 个文件，已保存到 {output_dir}/")
    print(f"  - JSON文件: {output_dir}/*.json")
    print(f"  - 源码副本: {output_dir}/*.sql")
    # print(f"  - 汇总文件: {output_dir}/summary.json")
    # return results


if __name__ == "__main__":
    import io

    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

    if len(sys.argv) < 2:
        print("用法:")
        print("  python plsql_extractor.py <文件路径>")
        print("  python plsql_extractor.py <目录路径> [--output <输出文件>]")
        sys.exit(1)

    input_path = sys.argv[1]

    if os.path.isfile(input_path):
        # 提取单个文件
        result = extract_file(input_path)
        # 写入文件而不是打印
        output_json = input_path + ".json"
        with open(output_json, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        print(f"已保存到: {output_json}")
    elif os.path.isdir(input_path):
        # 提取目录
        output_dir = "output"
        for i, arg in enumerate(sys.argv):
            if arg == "--output" and i + 1 < len(sys.argv):
                output_dir = sys.argv[i + 1]
        extract_directory(input_path, output_dir)
    else:
        print(f"路径不存在: {input_path}")
        sys.exit(1)
