// 定义应用中使用的类型

export interface TestCase {
  id: number;
  case_id: string;
  name: string;
  source_code_path?: string;
  wiki_path?: string;
  yaml_path?: string;
  created_at: string; // ISO date string
  updated_at: string; // ISO date string
}

export interface TestPlan {
  id: number;
  name: string;
  description?: string;
  case_ids?: string[]; // IDs of associated test cases
  created_at: string; // ISO date string
}

export interface PlanSummary {
  plan_id: number;
  total_reports: number;
  completed_reports: number;
  failed_reports: number;
  average_score: number | null;
  max_score: number | null;
  min_score: number | null;
  summary: string;
}

export interface ExtendedTestPlan extends TestPlan {
  summary?: PlanSummary;
}

export interface TestReport {
  id: number;
  report_name: string;
  plan_id?: number;
  case_id?: string;
  status: string; // RUNNING / FINISHED / FAILED / PENDING
  final_score?: number;
  result?: string;
  output_path?: string;
  created_at: string; // ISO date string
}

export interface PlanCase {
  id: number;
  plan_id: number;
  case_id: string;
}

export interface ApiResponse<T = any> {
  success: boolean;
  message: string;
  data?: T;
}