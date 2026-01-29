"""
输入输出处理模块
负责处理JSON文件的加载、验证和输出
"""

import json
from typing import Dict, Any, Union
import os


class IOHandler:
    """输入输出处理器"""
    
    @staticmethod
    def load_json_file(file_path: str) -> Dict[str, Any]:
        """
        加载JSON文件
        
        Args:
            file_path: JSON文件路径
            
        Returns:
            解析后的字典对象
            
        Raises:
            FileNotFoundError: 文件不存在
            ValueError: JSON格式错误
        """
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"文件不存在: {file_path}")
        
        with open(file_path, 'r', encoding='utf-8') as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError as e:
                raise ValueError(f"JSON格式错误: {e}")
        
        return data
    
    @staticmethod
    def load_json_string(json_str: str) -> Dict[str, Any]:
        """
        从字符串加载JSON
        
        Args:
            json_str: JSON字符串
            
        Returns:
            解析后的字典对象
            
        Raises:
            ValueError: JSON格式错误
        """
        try:
            return json.loads(json_str)
        except json.JSONDecodeError as e:
            raise ValueError(f"JSON格式错误: {e}")
    
    @staticmethod
    def validate_facts_format(facts_data: Dict[str, Any]) -> bool:
        """
        验证facts.json格式
        
        Args:
            facts_data: facts数据
            
        Returns:
            是否符合格式
        """
        if 'facts' not in facts_data:
            return False
        
        facts_list = facts_data['facts']
        if not isinstance(facts_list, list):
            return False
        
        for fact in facts_list:
            if not isinstance(fact, dict):
                return False
            
            # 检查必需字段
            if 'id' not in fact:
                return False
        
        return True
    
    @staticmethod
    def validate_wiki_format(wiki_data: Dict[str, Any]) -> bool:
        """
        验证wiki.json格式
        
        Args:
            wiki_data: wiki数据
            
        Returns:
            是否符合格式
        """
        required_fields = ['method', 'claims']
        for field in required_fields:
            if field not in wiki_data:
                return False
        
        claims = wiki_data['claims']
        if not isinstance(claims, list):
            return False
        
        for claim in claims:
            if not isinstance(claim, dict):
                return False
            
            # 检查claim必需字段
            if 'text' not in claim or 'fact_refs' not in claim:
                return False
        
        return True
    
    @staticmethod
    def save_evaluation_result(result: Dict[str, Any], output_path: str) -> None:
        """
        保存评测结果到文件
        
        Args:
            result: 评测结果
            output_path: 输出文件路径
        """
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
    
    @staticmethod
    def format_violations_for_output(violations: list) -> list:
        """
        格式化违规信息以便输出
        
        Args:
            violations: 违规列表
            
        Returns:
            格式化后的违规列表
        """
        formatted_violations = []
        for violation in violations:
            # 如果violation是对象，转换为字典格式
            if hasattr(violation, '__dict__'):
                formatted_violations.append({
                    "claim": getattr(violation, 'claim', ''),
                    "reason": getattr(violation, 'reason', ''),
                    "violation_type": getattr(violation, 'violation_type', '').value if hasattr(getattr(violation, 'violation_type', ''), 'value') else str(getattr(violation, 'violation_type', ''))
                })
            else:
                formatted_violations.append(violation)
        
        return formatted_violations