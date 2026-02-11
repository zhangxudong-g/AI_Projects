"""
Engineering Judge v3 - 统一测试案例运行器

此模块提供三种运行模式：
1. all 模式: 运行所有测试案例，从头开始
2. resume 模式 (默认): 支持断点续传，跳过已完成的案例
3. retry 模式: 仅重跑失败的案例
"""
import datetime
import time
import yaml
import json
import argparse
from pathlib import Path
from run_single_case_pipeline import run_single_case
from utils import format_results_with_llm, format_results_to_html


class ResumeRunner:
    def __init__(self, base_output: str):
        self.base_output = Path(base_output)
        self.status_file = self.base_output / "execution_status.json"
        self.completed_cases = {}
        self.failed_cases = {}
        self.start_time = None
        self.end_time = None
        self.load_status()
    
    def load_status(self):
        """加载执行状态"""
        if self.status_file.exists():
            try:
                with open(self.status_file, 'r', encoding='utf-8') as f:
                    status = json.load(f)
                    self.completed_cases = status.get('completed', {})
                    self.failed_cases = status.get('failed', {})
                print(f"已加载执行状态: {len(self.completed_cases)} 个完成, {len(self.failed_cases)} 个失败")
            except Exception as e:
                print(f"加载状态文件失败: {e}, 将重新开始")
                self.completed_cases = {}
                self.failed_cases = {}
        else:
            print("未找到状态文件，将从头开始")
    
    def save_status(self):
        """保存执行状态"""
        self.base_output.mkdir(parents=True, exist_ok=True)
        status = {
            'completed': self.completed_cases,
            'failed': self.failed_cases,
            'timestamp': datetime.datetime.now().isoformat()
        }
        with open(self.status_file, 'w', encoding='utf-8') as f:
            json.dump(status, f, ensure_ascii=False, indent=2)
    
    def get_remaining_cases(self, all_cases):
        """获取剩余待执行的 case（排除已完成的，包含失败的）"""
        completed_ids = set(self.completed_cases.keys())
        all_ids = {case['id']: case for case in all_cases}

        remaining_cases = []
        for case in all_cases:
            case_id = case['id']
            if case_id not in completed_ids:
                remaining_cases.append(case)

        failed_ids = set(self.failed_cases.keys())

        return remaining_cases, completed_ids, failed_ids

    def get_unfinished_cases(self, all_cases):
        """获取所有未完成的 cases（包括失败的）用于继续执行"""
        completed_ids = set(self.completed_cases.keys())
        
        unfinished_cases = []
        for case in all_cases:
            case_id = case['id']
            if case_id not in completed_ids:
                unfinished_cases.append(case)
                
        return unfinished_cases

    def get_failed_cases(self, all_cases):
        """仅获取失败的 cases 用于重试"""
        failed_ids = set(self.failed_cases.keys())
        all_ids = {case['id']: case for case in all_cases}
        
        failed_cases = []
        for case in all_cases:
            case_id = case['id']
            if case_id in failed_ids:
                failed_cases.append(case)
                
        return failed_cases
    
    def run_single_case_with_tracking(self, case, base_output):
        """运行单个 case 并跟踪状态"""
        case_id = case["id"]
        vars_cfg = case["vars"]
        
        print(f"\n[START] Running {case_id}")
        
        try:
            result = run_single_case(
                case_id=case_id,
                vars_cfg=vars_cfg,
                output_dir=Path(base_output) / case_id,
                base_output=base_output,
            )
            
            # 记录成功完成的 case
            self.completed_cases[case_id] = {
                "final_score": result["final_score"],
                "result": result["result"],
                "status": "completed",
                "timestamp": datetime.datetime.now().isoformat()
            }
            
            print(f"[SUCCESS] {case_id}: Final Score = {result['final_score']}, Result = {result['result']}")
            
            return {
                "case_id": case_id,
                "final_score": result["final_score"],
                "result": result["result"],
            }
        
        except KeyboardInterrupt:
            print(f"\n[INTERRUPTED] {case_id}: 用户中断")
            self.failed_cases[case_id] = {
                "status": "interrupted",
                "error": "KeyboardInterrupt",
                "timestamp": datetime.datetime.now().isoformat()
            }
            self.save_status()
            raise  # 重新抛出中断异常
        
        except Exception as e:
            print(f"[FAILED] {case_id}: {str(e)}")
            self.failed_cases[case_id] = {
                "status": "failed",
                "error": str(e),
                "timestamp": datetime.datetime.now().isoformat()
            }
            # 继续执行下一个 case，不中断整个流程
            return None
    
    def run_all_cases_with_resume(self, cases_yaml: str, base_output: str = "output"):
        """
        支持断续执行的批量运行函数
        """
        self.start_time = time.time()
        cfg = yaml.safe_load(open(cases_yaml, encoding="utf-8"))

        # 获取剩余待执行的 cases
        remaining_cases, completed_ids, failed_ids = self.get_remaining_cases(cfg["cases"])

        print(f"总共 {len(cfg['cases'])} 个测试案例")
        print(f"已完成: {len(completed_ids)} 个")
        print(f"失败: {len(failed_ids)} 个")
        print(f"剩余待执行: {len(remaining_cases)} 个")

        if not remaining_cases:
            print("所有案例都已处理完毕！")
            # 按照原始配置顺序返回所有结果
            all_results = []
            for case in cfg["cases"]:  # 按原始配置顺序遍历
                case_id = case["id"]
                if case_id in self.completed_cases:
                    result = self.completed_cases[case_id]
                    all_results.append({
                        "case_id": case_id,
                        "final_score": result["final_score"],
                        "result": result["result"],
                    })
                elif case_id in self.failed_cases:
                    all_results.append({
                        "case_id": case_id,
                        "final_score": 0,  # 失败案例分数为0
                        "result": "ERROR",
                    })
            
            # 计算总执行时间
            self.end_time = time.time()
            total_duration = self.end_time - self.start_time
            print(f"\n总执行时间: {total_duration:.2f} 秒")
            
            return all_results

        # 按原始配置顺序构建结果
        results_map = {}

        # 先添加已完成的案例到结果映射中
        for case_id, result in self.completed_cases.items():
            results_map[case_id] = {
                "case_id": case_id,
                "final_score": result["final_score"],
                "result": result["result"],
            }

        # 执行剩余的案例
        for i, case in enumerate(remaining_cases, 1):
            print(f"\n[{i}/{len(remaining_cases)}] 处理剩余案例: {case['id']}")

            result = self.run_single_case_with_tracking(case, base_output)
            if result:
                results_map[case['id']] = result

            # 定期保存状态
            if i % 5 == 0:  # 每5个案例保存一次状态
                self.save_status()
                print(f"  -> 已保存执行状态")

        # 按原始配置顺序构建最终结果列表
        results = []
        for case in cfg["cases"]:
            case_id = case["id"]
            if case_id in results_map:
                results.append(results_map[case_id])

        # 最后保存状态
        self.save_status()

        # 处理最终结果
        print("\n=== 最终结果 ===")
        for r in results:
            print(f"Case {r['case_id']}: Final Score = {r['final_score']} Result = {r['result']}")

        # 使用LLM整理结果并输出为Markdown表格
        format_results_with_llm(results, cfg, base_output)
        # 也输出为HTML表格
        format_results_to_html(results, cfg, base_output)

        # 保存最终结果到文件
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"final_results-{timestamp}.yaml"
        final_results_path = Path(base_output) / filename
        with open(final_results_path, "w", encoding="utf-8") as f:
            yaml.dump({"results": results}, f, allow_unicode=True)

        # 计算总执行时间
        self.end_time = time.time()
        total_duration = self.end_time - self.start_time
        print(f"\n状态文件保存至: {self.status_file}")
        print(f"最终结果保存至: {final_results_path}")
        print(f"总执行时间: {total_duration:.2f} 秒")
        print(f"平均每案例耗时: {total_duration/len(remaining_cases):.2f} 秒" if remaining_cases else "无新案例执行")

        return results

    def run_failed_cases_only(self, cases_yaml: str, base_output: str = "output"):
        """
        仅运行失败的测试案例
        """
        self.start_time = time.time()
        cfg = yaml.safe_load(open(cases_yaml, encoding="utf-8"))

        # 获取失败的 cases
        failed_cases = self.get_failed_cases(cfg["cases"])

        print(f"总共 {len(cfg['cases'])} 个测试案例")
        print(f"失败案例数量: {len(failed_cases)} 个")

        if not failed_cases:
            print("没有失败的案例需要重跑！")
            # 按照原始配置顺序返回所有结果
            all_results = []
            for case in cfg["cases"]:  # 按原始配置顺序遍历
                case_id = case["id"]
                if case_id in self.completed_cases:
                    result = self.completed_cases[case_id]
                    all_results.append({
                        "case_id": case_id,
                        "final_score": result["final_score"],
                        "result": result["result"],
                    })
                elif case_id in self.failed_cases:
                    all_results.append({
                        "case_id": case_id,
                        "final_score": 0,  # 失败案例分数为0
                        "result": "ERROR",
                    })
            
            # 计算总执行时间
            self.end_time = time.time()
            total_duration = self.end_time - self.start_time
            print(f"\n总执行时间: {total_duration:.2f} 秒")
            
            return all_results

        # 按原始配置顺序构建结果
        results_map = {}

        # 先添加已完成的案例到结果映射中
        for case_id, result in self.completed_cases.items():
            results_map[case_id] = {
                "case_id": case_id,
                "final_score": result["final_score"],
                "result": result["result"],
            }

        # 重新执行失败的案例
        for i, case in enumerate(failed_cases, 1):
            print(f"\n[{i}/{len(failed_cases)}] 重跑失败案例: {case['id']}")

            # 从失败案例列表中移除当前案例，以便重新尝试
            if case['id'] in self.failed_cases:
                del self.failed_cases[case['id']]

            result = self.run_single_case_with_tracking(case, base_output)
            if result:
                results_map[case['id']] = result

            # 定期保存状态
            if i % 5 == 0:  # 每5个案例保存一次状态
                self.save_status()
                print(f"  -> 已保存执行状态")

        # 按原始配置顺序构建最终结果列表
        results = []
        for case in cfg["cases"]:
            case_id = case["id"]
            if case_id in results_map:
                results.append(results_map[case_id])

        # 最后保存状态
        self.save_status()

        # 处理最终结果
        print("\n=== 重跑后的最终结果 ===")
        for r in results:
            print(f"Case {r['case_id']}: Final Score = {r['final_score']} Result = {r['result']}")

        # 使用LLM整理结果并输出为Markdown表格
        format_results_with_llm(results, cfg, base_output)

        # 保存最终结果到文件
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"final_results_retry-{timestamp}.yaml"
        final_results_path = Path(base_output) / filename
        with open(final_results_path, "w", encoding="utf-8") as f:
            yaml.dump({"results": results}, f, allow_unicode=True)

        # 计算总执行时间
        self.end_time = time.time()
        total_duration = self.end_time - self.start_time
        print(f"\n状态文件保存至: {self.status_file}")
        print(f"重跑结果保存至: {final_results_path}")
        print(f"总执行时间: {total_duration:.2f} 秒")
        print(f"平均每案例耗时: {total_duration/len(failed_cases):.2f} 秒" if failed_cases else "无失败案例重跑")

        return results


def run_all_cases_simple(cases_yaml: str, base_output: str = "output"):
    """
    运行所有测试案例，使用Engineering Judge v3系统进行评估（简单模式，无断点续传）
    """
    start_time = time.time()
    cfg = yaml.safe_load(open(cases_yaml, encoding="utf-8"))
    results = []

    for case in cfg["cases"]:
        case_id = case["id"]
        vars_cfg = case["vars"]
        print(f"\n[START] Running {case_id}")

        result = run_single_case(
            case_id=case_id,
            vars_cfg=vars_cfg,
            output_dir=Path(base_output) / case_id,
            base_output=base_output,
        )

        results.append({
            "case_id": case_id,
            "final_score": result["final_score"],
            "result": result["result"],
        })

    # 处理最终结果
    for r in results:
        print(f"Case {r['case_id']}: Final Score = {r['final_score']} Result = {r['result']}")

    # 使用LLM整理结果并输出为Markdown表格
    format_results_with_llm(results, cfg, base_output)

    # 保存最终结果到文件
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"final_results-{timestamp}.yaml"
    final_results_path = Path(base_output) / filename
    with open(final_results_path, "w", encoding="utf-8") as f:
        yaml.dump({"results": results}, f, allow_unicode=True)

    # 计算总执行时间
    end_time = time.time()
    total_duration = end_time - start_time
    print(f"\n总执行时间: {total_duration:.2f} 秒")
    print(f"平均每案例耗时: {total_duration/len(results):.2f} 秒" if results else "无案例执行")

    return results


def run_all_cases(cases_yaml: str, base_output: str = "output"):
    """
    运行所有测试案例，使用Engineering Judge v3系统进行评估（支持断续执行）
    """
    runner = ResumeRunner(base_output)
    return runner.run_all_cases_with_resume(cases_yaml, base_output)


def run_failed_cases_only(cases_yaml: str, base_output: str = "output"):
    """
    仅运行失败的测试案例
    """
    runner = ResumeRunner(base_output)
    return runner.run_failed_cases_only(cases_yaml, base_output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run Engineering Judge v3 test cases")
    parser.add_argument(
        "mode",
        nargs='?',
        choices=['all', 'resume', 'retry'],
        default='resume',
        help="Execution mode: 'all' (run all from scratch), 'resume' (skip completed, run remaining), 'retry' (only retry failed)"
    )
    parser.add_argument(
        "--cases",
        "-c",
        type=str,
        default="cases_jip.yaml",
        help="Cases YAML file path (default: cases_jip.yaml)",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=str,
        default="results_output",
        help="Output directory (default: results_output)",
    )

    args = parser.parse_args()

    if args.mode == 'all':
        run_all_cases_simple(args.cases, args.output)
    elif args.mode == 'retry':
        run_failed_cases_only(args.cases, args.output)
    else:  # resume mode (default)
        run_all_cases(args.cases, args.output)