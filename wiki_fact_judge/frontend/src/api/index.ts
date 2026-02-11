import axios from 'axios';

// 创建 axios 实例
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 请求拦截器
api.interceptors.request.use(
  (config) => {
    // 可以在这里添加认证 token
    // const token = localStorage.getItem('token');
    // if (token) {
    //   config.headers.Authorization = `Bearer ${token}`;
    // }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// 响应拦截器
api.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    // 统一错误处理
    console.error('API Error:', error);
    return Promise.reject(error);
  }
);

export default api;

// 测试案例相关的 API
export const caseApi = {
  // 获取所有测试案例
  getAllCases: () => api.get('/cases'),
  
  // 获取单个测试案例
  getCaseById: (id: string) => api.get(`/cases/${id}`),
  
  // 创建测试案例
  createCase: (data: FormData) => api.post('/cases/', data, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  }),
  
  // 更新测试案例
  updateCase: (id: string, data: any) => api.put(`/cases/${id}`, data),
  
  // 删除测试案例
  deleteCase: (id: string) => api.delete(`/cases/${id}`),
  
  // 运行测试案例
  runCase: (id: string) => api.post(`/cases/${id}/run`),
};

// 测试计划相关的 API
export const planApi = {
  // 获取所有测试计划
  getAllPlans: () => api.get('/plans'),
  
  // 获取单个测试计划
  getPlanById: (id: number) => api.get(`/plans/${id}`),
  
  // 创建测试计划
  createPlan: (data: any) => api.post('/plans/', data),
  
  // 更新测试计划
  updatePlan: (id: number, data: any) => api.put(`/plans/${id}`, data),
  
  // 删除测试计划
  deletePlan: (id: number) => api.delete(`/plans/${id}`),
  
  // 运行测试计划
  runPlan: (id: number) => api.post(`/plans/${id}/run`),
};

// 测试报告相关的 API
export const reportApi = {
  // 获取所有测试报告
  getAllReports: () => api.get('/reports'),
  
  // 获取单个测试报告
  getReportById: (id: number) => api.get(`/reports/${id}`),
  
  // 创建测试报告
  createReport: (data: any) => api.post('/reports/', data),
  
  // 更新测试报告
  updateReport: (id: number, data: any) => api.put(`/reports/${id}`, data),
  
  // 删除测试报告
  deleteReport: (id: number) => api.delete(`/reports/${id}`),
};