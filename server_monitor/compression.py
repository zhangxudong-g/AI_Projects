import gzip
import json
import zlib
from typing import Union, Dict, Any
import pickle
import base64

class DataCompressor:
    """数据压缩器类，提供多种压缩算法"""
    
    @staticmethod
    def compress_json(data: Dict[str, Any], method: str = 'gzip') -> Union[bytes, str]:
        """
        压缩JSON数据
        :param data: 要压缩的数据
        :param method: 压缩方法 ('gzip', 'zlib', 'pickle_b64')
        :return: 压缩后的数据
        """
        json_str = json.dumps(data, separators=(',', ':'))  # 紧凑格式
        
        if method == 'gzip':
            return gzip.compress(json_str.encode('utf-8'))
        elif method == 'zlib':
            return zlib.compress(json_str.encode('utf-8'))
        elif method == 'pickle_b64':
            pickled = pickle.dumps(data)
            return base64.b64encode(pickled).decode('utf-8')
        else:
            raise ValueError(f"Unsupported compression method: {method}")
    
    @staticmethod
    def decompress_json(compressed_data: Union[bytes, str], method: str = 'gzip') -> Dict[str, Any]:
        """
        解压JSON数据
        :param compressed_data: 压缩后的数据
        :param method: 压缩方法 ('gzip', 'zlib', 'pickle_b64')
        :return: 解压后的数据
        """
        if method == 'gzip':
            decompressed = gzip.decompress(compressed_data)
            return json.loads(decompressed.decode('utf-8'))
        elif method == 'zlib':
            decompressed = zlib.decompress(compressed_data)
            return json.loads(decompressed.decode('utf-8'))
        elif method == 'pickle_b64':
            pickled = base64.b64decode(compressed_data.encode('utf-8'))
            return pickle.loads(pickled)
        else:
            raise ValueError(f"Unsupported compression method: {method}")
    
    @staticmethod
    def get_compression_ratio(original_data: Dict[str, Any], method: str = 'gzip') -> float:
        """
        计算压缩比率
        :param original_data: 原始数据
        :param method: 压缩方法
        :return: 压缩比率 (压缩后大小 / 原始大小)
        """
        original_size = len(json.dumps(original_data).encode('utf-8'))
        compressed_data = DataCompressor.compress_json(original_data, method)
        compressed_size = len(compressed_data)
        return compressed_size / original_size if original_size > 0 else 0
    
    @staticmethod
    def compress_with_best_method(data: Dict[str, Any]) -> tuple:
        """
        使用最佳方法压缩数据
        :param data: 要压缩的数据
        :param return_method: 是否返回使用的压缩方法
        :return: (压缩数据, 压缩方法, 压缩比率)
        """
        methods = ['gzip', 'zlib']
        best_method = 'gzip'
        best_compressed = DataCompressor.compress_json(data, 'gzip')
        best_ratio = len(best_compressed) / len(json.dumps(data).encode('utf-8'))
        
        for method in methods[1:]:
            try:
                compressed = DataCompressor.compress_json(data, method)
                ratio = len(compressed) / len(json.dumps(data).encode('utf-8'))
                if ratio < best_ratio:
                    best_method = method
                    best_compressed = compressed
                    best_ratio = ratio
            except:
                continue
        
        return best_compressed, best_method, best_ratio


# 全局压缩器实例
compressor = DataCompressor()