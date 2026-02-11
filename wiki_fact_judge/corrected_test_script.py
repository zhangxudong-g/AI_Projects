import requests
import json
import time
import os
from pathlib import Path

# API base URL
BASE_URL = "http://localhost:8000"

def test_case_management():
    """测试案例管理功能"""
    print("=== 开始测试案例管理功能 ===")

    # 1. 创建测试案例 - 使用 form-data 格式
    print("\n1. 创建测试案例...")
    case_data = {
        "name": "Test Case 1"
    }
    
    # 创建一个临时文件用于上传
    temp_source_file = "temp_source.txt"
    temp_wiki_file = "temp_wiki.md"
    temp_yaml_file = "temp_config.yaml"
    
    with open(temp_source_file, 'w') as f:
        f.write("# Sample Source Code\nprint('hello world')")
    
    with open(temp_wiki_file, 'w') as f:
        f.write("# Sample Wiki Document\nThis is a sample wiki document.")
        
    with open(temp_yaml_file, 'w') as f:
        f.write("# Sample Config\nconfig_value: 123")

    with open(temp_source_file, 'rb') as source_f, \
         open(temp_wiki_file, 'rb') as wiki_f, \
         open(temp_yaml_file, 'rb') as yaml_f:
        
        files = {
            'source_code': source_f,
            'wiki': wiki_f,
            'yaml_file': yaml_f
        }
        data = {
            'name': 'Test Case 1'
        }
        
        response = requests.post(f"{BASE_URL}/cases/", files=files, data=data)

    # 删除临时文件
    os.remove(temp_source_file)
    os.remove(temp_wiki_file)
    os.remove(temp_yaml_file)

    if response.status_code == 200:
        created_case = response.json()
        print(f"[PASS] 成功创建测试案例: {created_case['name']} (ID: {created_case['case_id']})")
        case_id = created_case['case_id']
    else:
        print(f"[FAIL] 创建测试案例失败: {response.status_code}, {response.text}")
        return False

    # 2. 获取测试案例列表
    print("\n2. 获取测试案例列表...")
    response = requests.get(f"{BASE_URL}/cases/")
    if response.status_code == 200:
        cases = response.json()
        print(f"[PASS] 成功获取测试案例列表，共 {len(cases)} 个案例")
    else:
        print(f"[FAIL] 获取测试案例列表失败: {response.status_code}, {response.text}")
        return False

    # 3. 获取单个测试案例
    print(f"\n3. 获取单个测试案例 (ID: {case_id})...")
    response = requests.get(f"{BASE_URL}/cases/{case_id}")
    if response.status_code == 200:
        case = response.json()
        print(f"[PASS] 成功获取测试案例: {case['name']}")
    else:
        print(f"[FAIL] 获取测试案例失败: {response.status_code}, {response.text}")
        return False

    print("\n=== 案例管理功能测试完成 ===")
    return True


def test_plan_management():
    """测试计划管理功能"""
    print("\n=== 开始测试计划管理功能 ===")

    # 1. 创建测试计划
    print("\n1. 创建测试计划...")
    plan_data = {
        "name": "Test Plan 1",
        "description": "A sample test plan",
        "case_ids": []
    }

    response = requests.post(f"{BASE_URL}/plans/", json=plan_data)
    if response.status_code == 200:
        created_plan = response.json()
        print(f"[PASS] 成功创建测试计划: {created_plan['name']} (ID: {created_plan['id']})")
        plan_id = created_plan['id']
    else:
        print(f"[FAIL] 创建测试计划失败: {response.status_code}, {response.text}")
        return False

    # 2. 获取测试计划列表
    print("\n2. 获取测试计划列表...")
    response = requests.get(f"{BASE_URL}/plans/")
    if response.status_code == 200:
        plans = response.json()
        print(f"[PASS] 成功获取测试计划列表，共 {len(plans)} 个计划")
    else:
        print(f"[FAIL] 获取测试计划列表失败: {response.status_code}, {response.text}")
        return False

    # 3. 获取单个测试计划
    print(f"\n3. 获取单个测试计划 (ID: {plan_id})...")
    response = requests.get(f"{BASE_URL}/plans/{plan_id}")
    if response.status_code == 200:
        plan = response.json()
        print(f"[PASS] 成功获取测试计划: {plan['name']}")
    else:
        print(f"[FAIL] 获取测试计划失败: {response.status_code}, {response.text}")
        return False

    # 4. 更新测试计划
    print(f"\n4. 更新测试计划 (ID: {plan_id})...")
    update_data = {
        "name": "Updated Test Plan 1",
        "description": "An updated sample test plan",
        "case_ids": []
    }

    response = requests.put(f"{BASE_URL}/plans/{plan_id}", json=update_data)
    if response.status_code == 200:
        updated_plan = response.json()
        print(f"[PASS] 成功更新测试计划: {updated_plan['name']}")
    else:
        print(f"[FAIL] 更新测试计划失败: {response.status_code}, {response.text}")
        return False

    # 5. 删除测试计划
    print(f"\n5. 删除测试计划 (ID: {plan_id})...")
    response = requests.delete(f"{BASE_URL}/plans/{plan_id}")
    if response.status_code == 200:
        deleted_plan = response.json()
        print(f"[PASS] 成功删除测试计划: {deleted_plan['name']}")
    else:
        print(f"[FAIL] 删除测试计划失败: {response.status_code}, {response.text}")
        return False

    print("\n=== 测试计划管理功能测试完成 ===")
    return True


def test_report_management():
    """测试报告管理功能"""
    print("\n=== 开始测试报告管理功能 ===")

    # 1. 创建测试报告
    print("\n1. 创建测试报告...")
    report_data = {
        "report_name": "Test Report 1",
        "case_id": "test_case_1",
        "status": "FINISHED",
        "final_score": 85.5,
        "result": "Test passed successfully",
        "output_path": "output/test_report_1.json"
    }

    response = requests.post(f"{BASE_URL}/reports/", json=report_data)
    if response.status_code == 200:
        created_report = response.json()
        print(f"[PASS] 成功创建测试报告: {created_report['report_name']} (ID: {created_report['id']})")
        report_id = created_report['id']
    else:
        print(f"[FAIL] 创建测试报告失败: {response.status_code}, {response.text}")
        return False

    # 2. 获取测试报告列表
    print("\n2. 获取测试报告列表...")
    response = requests.get(f"{BASE_URL}/reports/")
    if response.status_code == 200:
        reports = response.json()
        print(f"[PASS] 成功获取测试报告列表，共 {len(reports)} 个报告")
    else:
        print(f"[FAIL] 获取测试报告列表失败: {response.status_code}, {response.text}")
        return False

    # 3. 获取单个测试报告
    print(f"\n3. 获取单个测试报告 (ID: {report_id})...")
    response = requests.get(f"{BASE_URL}/reports/{report_id}")
    if response.status_code == 200:
        report = response.json()
        print(f"[PASS] 成功获取测试报告: {report['report_name']}")
    else:
        print(f"[FAIL] 获取测试报告失败: {response.status_code}, {response.text}")
        return False

    # 4. 更新测试报告
    print(f"\n4. 更新测试报告 (ID: {report_id})...")
    update_data = {
        "report_name": "Updated Test Report 1",
        "case_id": "test_case_1",
        "status": "REVIEWED",
        "final_score": 87.0,
        "result": "Test passed with minor issues",
        "output_path": "output/updated_test_report_1.json"
    }

    response = requests.put(f"{BASE_URL}/reports/{report_id}", json=update_data)
    if response.status_code == 200:
        updated_report = response.json()
        print(f"[PASS] 成功更新测试报告: {updated_report['report_name']}")
    else:
        print(f"[FAIL] 更新测试报告失败: {response.status_code}, {response.text}")
        return False

    # 5. 删除测试报告
    print(f"\n5. 删除测试报告 (ID: {report_id})...")
    response = requests.delete(f"{BASE_URL}/reports/{report_id}")
    if response.status_code == 200:
        deleted_report = response.json()
        print(f"[PASS] 成功删除测试报告: {deleted_report['report_name']}")
    else:
        print(f"[FAIL] 删除测试报告失败: {response.status_code}, {response.text}")
        return False

    print("\n=== 报告管理功能测试完成 ===")
    return True


def test_health_check():
    """测试健康检查端点"""
    print("\n=== 测试健康检查端点 ===")
    response = requests.get(f"{BASE_URL}/health")
    if response.status_code == 200:
        health_info = response.json()
        print(f"[PASS] 健康检查通过: {health_info}")
        return True
    else:
        print(f"[FAIL] 健康检查失败: {response.status_code}, {response.text}")
        return False


def main():
    """主测试函数"""
    print("开始对 Wiki Fact Judge 系统进行全面的功能验证...")
    print(f"测试目标: {BASE_URL}")

    # 测试健康检查
    if not test_health_check():
        print("\n[FAIL] 健康检查失败，终止测试")
        return

    # 测试各项功能
    all_tests_passed = True

    # 测试案例管理功能
    if not test_case_management():
        all_tests_passed = False

    # 测试计划管理功能
    if not test_plan_management():
        all_tests_passed = False

    # 测试报告管理功能
    if not test_report_management():
        all_tests_passed = False

    print("\n" + "="*50)
    if all_tests_passed:
        print("[PASS] 所有测试通过！Wiki Fact Judge 系统功能正常")
    else:
        print("[FAIL] 部分测试失败，请检查系统状态")
    print("="*50)


if __name__ == "__main__":
    main()