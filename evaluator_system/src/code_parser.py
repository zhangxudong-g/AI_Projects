"""
代码解析器 - 从源代码文件提取事实
"""

import ast
import re
from typing import List, Dict, Any


class CodeParser:
    """代码解析器，用于从源代码中提取事实"""
    
    def __init__(self):
        pass
    
    def parse_python_file(self, file_path: str) -> List[Dict[str, Any]]:
        """
        解析Python文件并提取事实
        
        Args:
            file_path: Python文件路径
            
        Returns:
            事实列表
        """
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        return self.extract_facts_from_python(content)
    
    def extract_facts_from_python(self, code: str) -> List[Dict[str, Any]]:
        """
        从Python代码中提取事实
        
        Args:
            code: Python代码字符串
            
        Returns:
            事实列表
        """
        facts = []
        
        try:
            tree = ast.parse(code)
        except SyntaxError:
            print(f"语法错误：无法解析代码")
            return facts
        
        # 遍历AST节点
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                fact = self.extract_function_fact(node, code)
                if fact:
                    facts.append(fact)
            elif isinstance(node, ast.ClassDef):
                facts.extend(self.extract_class_facts(node, code))
        
        return facts
    
    def extract_function_fact(self, func_node: ast.FunctionDef, code: str) -> Dict[str, Any]:
        """
        从函数定义中提取事实
        
        Args:
            func_node: AST函数节点
            code: 源代码
            
        Returns:
            函数相关的事实
        """
        fact = {
            "id": f"method:{func_node.name}",
            "kind": "method",
            "name": func_node.name,
            "calls": [],
            "writes": [],
            "annotations": [],
            "conditions": []
        }
        
        # 提取函数内的调用
        for child_node in ast.walk(func_node):
            if isinstance(child_node, ast.Call):
                call_name = self.get_call_name(child_node)
                if call_name and call_name not in fact["calls"]:
                    fact["calls"].append(call_name)
        
        # 提取注解
        if func_node.decorator_list:
            for decorator in func_node.decorator_list:
                if isinstance(decorator, ast.Name):
                    fact["annotations"].append(f"@{decorator.id}")
                elif isinstance(decorator, ast.Attribute):
                    fact["annotations"].append(f"@{decorator.attr}")
        
        # 提取条件
        for child_node in ast.walk(func_node):
            if isinstance(child_node, (ast.If, ast.While)):
                condition = ast.unparse(child_node.test)
                if condition not in fact["conditions"]:
                    fact["conditions"].append(condition)
        
        # 提取赋值（可能涉及写入）
        for child_node in ast.walk(func_node):
            if isinstance(child_node, ast.Assign):
                for target in child_node.targets:
                    if isinstance(target, ast.Subscript):
                        # 处理数组/字典赋值
                        var_name = ast.unparse(target)
                    elif isinstance(target, ast.Attribute):
                        # 处理对象属性赋值
                        var_name = f"{target.value.id}.{target.attr}"
                    elif isinstance(target, ast.Name):
                        # 处理变量赋值
                        var_name = target.id
                    else:
                        continue
                    
                    if var_name not in fact["writes"]:
                        fact["writes"].append(var_name)
        
        return fact
    
    def extract_class_facts(self, class_node: ast.ClassDef, code: str) -> List[Dict[str, Any]]:
        """
        从类定义中提取事实
        
        Args:
            class_node: AST类节点
            code: 源代码
            
        Returns:
            类相关的事实列表
        """
        facts = []
        
        for item in class_node.body:
            if isinstance(item, ast.FunctionDef):
                fact = self.extract_function_fact(item, code)
                if fact:
                    facts.append(fact)
        
        return facts
    
    def get_call_name(self, call_node: ast.Call) -> str:
        """
        获取调用节点的名称
        
        Args:
            call_node: AST调用节点
            
        Returns:
            调用名称
        """
        if isinstance(call_node.func, ast.Name):
            return call_node.func.id
        elif isinstance(call_node.func, ast.Attribute):
            attr_chain = []
            current = call_node.func
            while isinstance(current, ast.Attribute):
                attr_chain.insert(0, current.attr)
                current = current.value
            if isinstance(current, ast.Name):
                attr_chain.insert(0, current.id)
            elif isinstance(current, ast.Call):
                # 处理链式调用
                base = self.get_call_name(current)
                if base:
                    attr_chain.insert(0, base)
            return ".".join(attr_chain)
        return ""
    
    def parse_java_file(self, file_path: str) -> List[Dict[str, Any]]:
        """
        解析Java文件并提取事实（简化版，仅作示例）
        
        Args:
            file_path: Java文件路径
            
        Returns:
            事实列表
        """
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        return self.extract_facts_from_java(content)
    
    def extract_facts_from_java(self, code: str) -> List[Dict[str, Any]]:
        """
        从Java代码中提取事实（简化版，仅作示例）
        
        Args:
            code: Java代码字符串
            
        Returns:
            事实列表
        """
        facts = []
        
        # 使用正则表达式提取方法定义
        method_pattern = r'(public|private|protected)?\s*(static)?\s*\w+\s+(\w+)\s*\([^)]*\)\s*\{'
        methods = re.finditer(method_pattern, code, re.MULTILINE)
        
        for method_match in methods:
            method_name = method_match.group(3)
            fact = {
                "id": f"method:{method_name}",
                "kind": "method",
                "name": method_name,
                "calls": [],
                "writes": [],
                "annotations": [],
                "conditions": []
            }
            
            # 提取方法体内容
            method_start = method_match.start()
            brace_count = 0
            method_end = -1
            
            for i, char in enumerate(code[method_start:], method_start):
                if char == '{':
                    brace_count += 1
                elif char == '}':
                    brace_count -= 1
                    if brace_count == 0:
                        method_end = i
                        break
            
            if method_end != -1:
                method_body = code[method_start:method_end+1]
                
                # 提取方法调用
                call_pattern = r'(\w+(?:\.\w+)*)\s*\('
                calls = re.findall(call_pattern, method_body)
                for call in calls:
                    if call != method_name and call not in fact["calls"]:  # 避免自调用
                        fact["calls"].append(call)
                
                # 提取注解
                annotation_pattern = r'@(\w+)'
                annotations = re.findall(annotation_pattern, method_body)
                for annotation in annotations:
                    if f"@{annotation}" not in fact["annotations"]:
                        fact["annotations"].append(f"@{annotation}")
                
                # 提取条件语句
                condition_pattern = r'(if|while|for)\s*\(([^)]+)\)'
                conditions = re.findall(condition_pattern, method_body)
                for cond_type, condition in conditions:
                    full_condition = f"{cond_type}({condition})"
                    if full_condition not in fact["conditions"]:
                        fact["conditions"].append(full_condition)
                
                # 提取赋值语句（可能涉及写入）
                assignment_pattern = r'(\w+(?:\.\w+)*)\s*=\s*'
                assignments = re.findall(assignment_pattern, method_body)
                for assignment in assignments:
                    if assignment not in fact["writes"]:
                        fact["writes"].append(assignment)
            
            facts.append(fact)
        
        return facts


def main():
    """主函数，用于从代码文件提取事实"""
    import argparse
    import json
    
    parser = argparse.ArgumentParser(description='从源代码文件提取事实')
    parser.add_argument('--input', required=True, help='源代码文件路径')
    parser.add_argument('--output', required=True, help='输出JSON文件路径')
    parser.add_argument('--lang', choices=['python', 'java'], default='python', help='代码语言')
    
    args = parser.parse_args()
    
    parser = CodeParser()
    
    if args.lang == 'python':
        facts = parser.parse_python_file(args.input)
    elif args.lang == 'java':
        facts = parser.parse_java_file(args.input)
    else:
        print(f"不支持的语言: {args.lang}")
        return
    
    output = {"facts": facts}
    
    with open(args.output, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print(f"成功从 {args.input} 提取了 {len(facts)} 个事实，已保存到 {args.output}")


if __name__ == "__main__":
    main()