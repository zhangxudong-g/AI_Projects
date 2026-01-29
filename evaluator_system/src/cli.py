"""
CLI命令行接口模块
提供命令行工具入口和高级功能
"""

import argparse
import sys
import os
from pathlib import Path

# 添加src目录到Python路径，以便导入模块
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.v1_evaluator import V1Evaluator
from src.io_handler import IOHandler


def create_parser():
    """创建命令行参数解析器"""
    parser = argparse.ArgumentParser(
        description='V1 评测系统 - 验证 Wiki 是否忠实转述已解析事实',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用示例:
  %(prog)s --facts facts.json --wiki wiki.json --out result.json
  %(prog)s --facts facts.json --wiki wiki.json --out result.json --verbose
        """
    )
    
    parser.add_argument(
        '--facts',
        required=True,
        help='facts.json 文件路径'
    )
    
    parser.add_argument(
        '--wiki',
        required=True,
        help='wiki.json 文件路径'
    )
    
    parser.add_argument(
        '--out',
        required=True,
        help='输出结果文件路径'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='显示详细输出'
    )
    
    parser.add_argument(
        '--threshold-faithfulness',
        type=float,
        default=0.95,
        help='信仰度阈值 (默认: 0.95)'
    )
    
    parser.add_argument(
        '--threshold-hallucination',
        type=float,
        default=0.0,
        help='幻觉率阈值 (默认: 0.0)'
    )
    
    parser.add_argument(
        '--threshold-recall',
        type=float,
        default=0.85,
        help='关键事实召回率阈值 (默认: 0.85)'
    )
    
    parser.add_argument(
        '--threshold-redundancy',
        type=float,
        default=0.15,
        help='冗余率阈值 (默认: 0.15)'
    )
    
    return parser


def validate_inputs(args):
    """验证输入参数"""
    if not os.path.exists(args.facts):
        raise FileNotFoundError(f"facts文件不存在: {args.facts}")
    
    if not os.path.exists(args.wiki):
        raise FileNotFoundError(f"wiki文件不存在: {args.wiki}")
    
    # 验证阈值范围
    if not 0 <= args.threshold_faithfulness <= 1:
        raise ValueError("faithfulness阈值必须在0-1之间")
    
    if not 0 <= args.threshold_hallucination <= 1:
        raise ValueError("hallucination阈值必须在0-1之间")
    
    if not 0 <= args.threshold_recall <= 1:
        raise ValueError("recall阈值必须在0-1之间")
    
    if not 0 <= args.threshold_redundancy <= 1:
        raise ValueError("redundancy阈值必须在0-1之间")


def run_evaluation(args):
    """执行评测"""
    evaluator = V1Evaluator()
    
    if args.verbose:
        print(f"正在加载facts文件: {args.facts}")
        print(f"正在加载wiki文件: {args.wiki}")
    
    # 执行评测
    result = evaluator.evaluate_from_files(args.facts, args.wiki)
    
    # 应用自定义阈值
    custom_pass = (
        result.metrics["faithfulness"] >= args.threshold_faithfulness and
        result.metrics["hallucination_rate"] <= args.threshold_hallucination and
        result.metrics["key_fact_recall"] >= args.threshold_recall and
        result.metrics["redundancy_rate"] <= args.threshold_redundancy
    )
    
    # 更新结果中的pass状态
    result.pass_evaluation = custom_pass
    
    # 准备输出结果
    output = {
        "metrics": result.metrics,
        "violations": [
            {
                "claim": v.claim,
                "reason": v.reason,
                "violation_type": v.violation_type.value
            } for v in result.violations
        ],
        "pass": result.pass_evaluation,
        "thresholds": {
            "faithfulness": args.threshold_faithfulness,
            "hallucination_rate": args.threshold_hallucination,
            "key_fact_recall": args.threshold_recall,
            "redundancy_rate": args.threshold_redundancy
        }
    }
    
    # 保存结果
    io_handler = IOHandler()
    io_handler.save_evaluation_result(output, args.out)
    
    if args.verbose:
        print(f"评测完成。结果已保存至: {args.out}")
        print(f"评测通过: {result.pass_evaluation}")
        print(f"信仰度: {result.metrics['faithfulness']:.2f}")
        print(f"幻觉率: {result.metrics['hallucination_rate']:.2f}")
        print(f"关键事实召回率: {result.metrics['key_fact_recall']:.2f}")
        print(f"冗余率: {result.metrics['redundancy_rate']:.2f}")
        
        if result.violations:
            print(f"\n发现 {len(result.violations)} 个违规:")
            for i, violation in enumerate(result.violations[:5]):  # 只显示前5个
                print(f"  {i+1}. '{violation.claim}' - {violation.reason}")
            if len(result.violations) > 5:
                print(f"  ... 还有 {len(result.violations) - 5} 个违规未显示")
    
    return result


def main():
    """CLI主入口"""
    parser = create_parser()
    args = parser.parse_args()
    
    try:
        validate_inputs(args)
        result = run_evaluation(args)
        
        # 根据评测结果设置退出码
        sys.exit(0 if result.pass_evaluation else 1)
        
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()