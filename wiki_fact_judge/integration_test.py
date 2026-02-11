import requests
import json
import time
import os
from pathlib import Path

# API base URL
BASE_URL = "http://localhost:8000"

def test_frontend_backend_integration():
    """测试前端后端集成"""
    print("开始测试前端后端集成...")

    # 1. 测试健康检查
    print("\n1. 测试健康检查...")
    try:
        response = requests.get(f"{BASE_URL}/health")
        if response.status_code == 200:
            print(f"   [PASS] Health check passed: {response.json()}")
        else:
            print(f"   [FAIL] Health check failed: {response.status_code}, {response.text}")
            return False
    except Exception as e:
        print(f"   [FAIL] Health check exception: {str(e)}")
        return False

    # 2. 测试案例上传功能
    print("\n2. 测试案例上传功能...")
    try:
        # 创建临时文件
        temp_source_file = "temp_source.txt"
        temp_wiki_file = "temp_wiki.md"
        temp_yaml_file = "temp_config.yaml"
        
        with open(temp_source_file, 'w') as f:
            f.write("# Sample Source Code\nprint('hello world')")
        
        with open(temp_wiki_file, 'w') as f:
            f.write("# Sample Wiki Document\nThis is a sample wiki document.")
            
        with open(temp_yaml_file, 'w') as f:
            f.write("# Sample Config\nconfig_value: 123")

        # 发送 multipart/form-data 请求
        with open(temp_source_file, 'rb') as source_f, \
             open(temp_wiki_file, 'rb') as wiki_f, \
             open(temp_yaml_file, 'rb') as yaml_f:
            
            files = {
                'source_code': source_f,
                'wiki': wiki_f,
                'yaml_file': yaml_f
            }
            data = {
                'name': 'Integration Test Case'
            }
            
            response = requests.post(f"{BASE_URL}/cases/", files=files, data=data)

        # 删除临时文件
        os.remove(temp_source_file)
        os.remove(temp_wiki_file)
        os.remove(temp_yaml_file)

        if response.status_code == 200:
            created_case = response.json()
            case_id = created_case['case_id']
            print(f"   [PASS] Successfully uploaded case: {created_case['name']} (ID: {case_id})")
        else:
            print(f"   [FAIL] Case upload failed: {response.status_code}, {response.text}")
            return False
    except Exception as e:
        print(f"   [FAIL] Case upload exception: {str(e)}")
        return False

    # 3. 测试计划创建功能
    print("\n3. Testing plan creation functionality...")
    try:
        plan_data = {
            "name": "Integration Test Plan",
            "description": "A test plan for integration testing",
            "case_ids": [case_id]  # 使用上面创建的案例ID
        }

        response = requests.post(f"{BASE_URL}/plans/", json=plan_data)
        if response.status_code == 200:
            created_plan = response.json()
            plan_id = created_plan['id']
            print(f"   [PASS] Successfully created plan: {created_plan['name']} (ID: {plan_id})")
        else:
            print(f"   [FAIL] Plan creation failed: {response.status_code}, {response.text}")
            return False
    except Exception as e:
        print(f"   [FAIL] Plan creation exception: {str(e)}")
        return False

    # 4. 测试获取案例列表
    print("\n4. Testing get cases list...")
    try:
        response = requests.get(f"{BASE_URL}/cases/")
        if response.status_code == 200:
            cases = response.json()
            print(f"   [PASS] Successfully retrieved cases list, total {len(cases)} cases")
        else:
            print(f"   [FAIL] Failed to get cases list: {response.status_code}, {response.text}")
            return False
    except Exception as e:
        print(f"   [FAIL] Get cases list exception: {str(e)}")
        return False

    # 5. 测试获取计划列表
    print("\n5. Testing get plans list...")
    try:
        response = requests.get(f"{BASE_URL}/plans/")
        if response.status_code == 200:
            plans = response.json()
            print(f"   [PASS] Successfully retrieved plans list, total {len(plans)} plans")
        else:
            print(f"   [FAIL] Failed to get plans list: {response.status_code}, {response.text}")
            return False
    except Exception as e:
        print(f"   [FAIL] Get plans list exception: {str(e)}")
        return False

    # 6. 清理测试数据
    print("\n6. Cleaning up test data...")
    try:
        response = requests.delete(f"{BASE_URL}/cases/{case_id}")
        if response.status_code == 200:
            print(f"   [PASS] Successfully deleted test case")
        else:
            print(f"   [FAIL] Failed to delete test case: {response.status_code}, {response.text}")

        response = requests.delete(f"{BASE_URL}/plans/{plan_id}")
        if response.status_code == 200:
            print(f"   [PASS] Successfully deleted test plan")
        else:
            print(f"   [FAIL] Failed to delete test plan: {response.status_code}, {response.text}")
    except Exception as e:
        print(f"   [FAIL] Cleanup test data exception: {str(e)}")

    print("\n[COMPLETE] Frontend-backend integration test completed!")
    return True


def main():
    """主函数"""
    print("开始对 Wiki Fact Judge 系统进行前端后端集成测试...")
    print(f"测试目标: {BASE_URL}")

    success = test_frontend_backend_integration()

    print("\n" + "="*50)
    if success:
        print("[PASS] 前端后端集成测试通过！")
    else:
        print("[FAIL] 前端后端集成测试失败！")
    print("="*50)


if __name__ == "__main__":
    main()