"""
测试修复后的API端点和功能
"""
import requests
import json
import os
from pathlib import Path

# API base URL
BASE_URL = "http://localhost:8000"

def test_api_endpoints():
    """测试API端点是否正常工作"""
    print("Testing API endpoints...")
    
    # 测试健康检查
    try:
        response = requests.get(f"{BASE_URL}/health")
        if response.status_code == 200:
            print("[OK] Health check passed")
        else:
            print(f"[ERROR] Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"[ERROR] Cannot connect to API: {e}")
        print("Make sure the backend service is running on http://localhost:8000")
        return False
    
    # 测试获取案例列表（应该返回空数组，如果没有数据的话）
    try:
        response = requests.get(f"{BASE_URL}/cases/")
        if response.status_code == 200:
            cases = response.json()
            print(f"[OK] GET /cases/ successful, returned {len(cases)} cases")
        else:
            print(f"[ERROR] GET /cases/ failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"[ERROR] Error getting cases: {e}")
        return False
    
    # 测试获取计划列表
    try:
        response = requests.get(f"{BASE_URL}/plans/")
        if response.status_code == 200:
            plans = response.json()
            print(f"[OK] GET /plans/ successful, returned {len(plans)} plans")
        else:
            print(f"[ERROR] GET /plans/ failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"[ERROR] Error getting plans: {e}")
        return False
    
    return True

def test_create_case():
    """测试创建案例功能"""
    print("\nTesting case creation...")
    
    # 创建临时文件用于上传
    temp_dir = Path("data/test_temp")
    temp_dir.mkdir(exist_ok=True)

    source_file = temp_dir / "source_code.txt"
    wiki_file = temp_dir / "wiki_doc.md"
    yaml_file = temp_dir / "config.yaml"

    source_file.write_text("# Test Source Code\nThis is a test source code file.")
    wiki_file.write_text("# Test Wiki Doc\nThis is a test wiki documentation.")
    yaml_file.write_text("test: true\nvalue: 123")

    try:
        with open(source_file, 'rb') as sf, open(wiki_file, 'rb') as wf, open(yaml_file, 'rb') as yf:
            files = {
                'source_code': sf,
                'wiki': wf,
                'yaml_file': yf
            }
            data = {
                'name': 'Test Case Created via Script'
            }

            response = requests.post(f"{BASE_URL}/cases/", files=files, data=data)

        if response.status_code == 200:
            created_case = response.json()
            print(f"[OK] Successfully created case: {created_case['name']} (ID: {created_case['case_id']})")
            return created_case['case_id']
        else:
            print(f"[ERROR] Failed to create case: {response.status_code}, {response.text}")
            return None
    except Exception as e:
        print(f"[ERROR] Error creating case: {e}")
        return None
    finally:
        # 清理临时文件
        try:
            os.remove(source_file)
            os.remove(wiki_file)
            os.remove(yaml_file)
            os.rmdir(temp_dir)
        except:
            pass

def test_create_plan():
    """测试创建计划功能"""
    print("\nTesting plan creation...")
    
    plan_data = {
        "name": "Test Plan Created via Script",
        "description": "A sample test plan created for testing purposes",
        "case_ids": []
    }

    try:
        response = requests.post(f"{BASE_URL}/plans/", json=plan_data)
        if response.status_code == 200:
            created_plan = response.json()
            print(f"[OK] Successfully created plan: {created_plan['name']} (ID: {created_plan['id']})")
            return created_plan['id']
        else:
            print(f"[ERROR] Failed to create plan: {response.status_code}, {response.text}")
            return None
    except Exception as e:
        print(f"[ERROR] Error creating plan: {e}")
        return None

def main():
    print("Running fix verification tests...\n")
    
    # 首先测试API端点
    if not test_api_endpoints():
        print("\nAPI endpoints are not accessible. Please start the backend service:")
        print("cd D:/AI_Projects/wiki_fact_judge && uvicorn backend.main:app --reload --port 8000")
        return
    
    # 测试创建功能
    case_id = test_create_case()
    plan_id = test_create_plan()
    
    # 再次测试获取列表，确认数据已创建
    if case_id:
        try:
            response = requests.get(f"{BASE_URL}/cases/")
            if response.status_code == 200:
                cases = response.json()
                print(f"[OK] After creation, GET /cases/ now returns {len(cases)} cases")
        except Exception as e:
            print(f"[ERROR] Error checking cases after creation: {e}")
    
    if plan_id:
        try:
            response = requests.get(f"{BASE_URL}/plans/")
            if response.status_code == 200:
                plans = response.json()
                print(f"[OK] After creation, GET /plans/ now returns {len(plans)} plans")
        except Exception as e:
            print(f"[ERROR] Error checking plans after creation: {e}")
    
    print("\nFix verification tests completed.")

if __name__ == "__main__":
    main()