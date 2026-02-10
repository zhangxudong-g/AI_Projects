# Engineering Judge v3 Web UI 模块设计文档

## 1. 项目概述

### 1.1 项目背景
Engineering Judge v3 是一个基于 promptfoo 框架构建的工程导向 Wiki 质量评估系统。本项目旨在为其添加现代化的 Web UI，以提升用户体验和协作能力，同时保持现有命令行功能的完整性。

### 1.2 设计目标
- 提供直观的图形化界面
- 实现所有核心功能的 Web 化
- 保持与现有 CLI 的完全兼容
- 支持实时监控和可视化报告

## 2. 系统架构

### 2.1 整体架构
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web UI        │    │   API Server    │    │  CLI Engine     │
│  (React/FastAPI)│ ←→ │  (FastAPI)      │ ←→ │  (Existing)     │
│                 │    │                 │    │                 │
│ - Dashboard     │    │ - REST API      │    │ - run_single_   │
│ - Case Manager  │    │ - WebSocket     │    │   case_pipeline │
│ - Execution     │    │ - Job Queue     │    │ - run_multi_    │
│   Monitor       │    │ - Authentication│    │   cases_unified │
│ - Reports       │    │ - Data Storage  │    │ - utils         │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### 2.2 技术栈
- **前端**: React 18 + TypeScript + Ant Design
- **后端**: FastAPI + PostgreSQL + Redis
- **任务队列**: Celery
- **实时通信**: WebSocket

## 3. 功能模块设计

### 3.1 仪表盘模块 (Dashboard Module)

#### 3.1.1 功能描述
仪表盘模块提供系统概览信息，包括统计数据、趋势图和最近活动。

#### 3.1.2 组件结构
```
Dashboard/
├── index.tsx              # 仪表盘主页面
├── components/
│   ├── StatsCard.tsx      # 统计卡片组件
│   ├── TrendChart.tsx     # 趋势图表组件
│   ├── RecentActivity.tsx # 最近活动组件
│   └── QuickActions.tsx   # 快捷操作组件
└── hooks/
    └── useDashboardData.ts # 仪表盘数据获取Hook
```

#### 3.1.3 API 接口
- `GET /api/v1/dashboard/stats`: 获取统计信息
- `GET /api/v1/dashboard/trends`: 获取趋势数据
- `GET /api/v1/dashboard/recent`: 获取最近活动

#### 3.1.4 数据模型
```typescript
interface DashboardStats {
  totalExecutions: number;
  successRate: number;
  averageScore: number;
  recentFailures: number;
}

interface TrendData {
  date: string;
  executions: number;
  avgScore: number;
}
```

#### 3.1.5 实现要点
- 使用 ECharts 或 Recharts 进行数据可视化
- 实现实时数据更新
- 响应式设计适配不同屏幕尺寸

### 3.2 案例管理模块 (Case Management Module)

#### 3.2.1 功能描述
案例管理模块提供对测试案例的完整生命周期管理，包括创建、编辑、删除和批量操作。

#### 3.2.2 组件结构
```
CaseManagement/
├── index.tsx              # 案例管理主页面
├── components/
│   ├── CaseTable.tsx      # 案例表格组件
│   ├── CaseModal.tsx      # 案例编辑模态框
│   ├── CaseEditor.tsx     # YAML编辑器组件
│   ├── ImportModal.tsx    # 批量导入模态框
│   └── TemplateSelector.tsx # 模板选择组件
└── hooks/
    ├── useCaseData.ts     # 案例数据获取Hook
    └── useCaseOperations.ts # 案例操作Hook
```

#### 3.2.3 API 接口
- `GET /api/v1/cases`: 获取案例列表
- `POST /api/v1/cases`: 创建新案例
- `PUT /api/v1/cases/{id}`: 更新案例
- `DELETE /api/v1/cases/{id}`: 删除案例
- `POST /api/v1/cases/import`: 批量导入案例
- `GET /api/v1/cases/templates`: 获取模板列表

#### 3.2.4 数据模型
```typescript
interface CaseItem {
  id: string;
  name: string;
  configYaml: string;
  createdAt: Date;
  updatedAt: Date;
  status: 'active' | 'inactive';
}

interface CaseTemplate {
  id: string;
  name: string;
  description: string;
  configYaml: string;
}
```

#### 3.2.5 实现要点
- 集成 Monaco Editor 作为 YAML 编辑器
- 实现语法验证和错误提示
- 支持批量导入/导出功能
- 提供案例模板管理

### 3.3 执行控制模块 (Execution Control Module)

#### 3.3.1 功能描述
执行控制模块负责管理测试执行过程，包括启动、监控、暂停和终止执行任务。

#### 3.3.2 组件结构
```
ExecutionControl/
├── index.tsx              # 执行控制主页面
├── components/
│   ├── ExecutionQueue.tsx # 执行队列组件
│   ├── ExecutionMonitor.tsx # 执行监控组件
│   ├── ExecutionLog.tsx   # 执行日志组件
│   ├── ExecutionControls.tsx # 执行控制按钮组件
│   └── ScheduleModal.tsx  # 调度设置模态框
└── hooks/
    ├── useExecutionData.ts # 执行数据获取Hook
    └── useExecutionControl.ts # 执行控制Hook
```

#### 3.3.3 API 接口
- `POST /api/v1/executions`: 启动新执行
- `GET /api/v1/executions`: 获取执行列表
- `GET /api/v1/executions/{id}`: 获取执行详情
- `PUT /api/v1/executions/{id}/stop`: 停止执行
- `PUT /api/v1/executions/{id}/pause`: 暂停执行
- `POST /api/v1/executions/schedule`: 设置调度执行

#### 3.3.4 WebSocket 接口
- `ws://host/ws/execution/{id}`: 实时执行状态更新

#### 3.3.5 数据模型
```typescript
interface ExecutionItem {
  id: string;
  caseId: string;
  caseName: string;
  status: 'queued' | 'running' | 'completed' | 'failed' | 'stopped';
  startTime?: Date;
  endTime?: Date;
  progress: number;
  logs: ExecutionLog[];
}

interface ExecutionLog {
  timestamp: Date;
  level: 'info' | 'warning' | 'error';
  message: string;
}
```

#### 3.3.6 实现要点
- 实现实时进度监控
- 集成 WebSocket 进行实时通信
- 提供详细的执行日志查看
- 支持调度执行功能

### 3.4 报告系统模块 (Reporting Module)

#### 3.4.1 功能描述
报告系统模块提供执行结果的可视化展示和报告生成功能。

#### 3.4.2 组件结构
```
Reporting/
├── index.tsx              # 报告主页面
├── components/
│   ├── ReportTable.tsx    # 报告表格组件
│   ├── ScoreDistribution.tsx # 分数分布图表
│   ├── SuccessRateChart.tsx # 成功率图表
│   ├── ExportControls.tsx # 导出控制组件
│   └── FilterPanel.tsx    # 过滤面板组件
└── hooks/
    ├── useReportData.ts   # 报告数据获取Hook
    └── useExport.ts       # 导出功能Hook
```

#### 3.4.3 API 接口
- `GET /api/v1/reports`: 获取报告列表
- `GET /api/v1/reports/{id}`: 获取详细报告
- `GET /api/v1/reports/export`: 导出报告
- `GET /api/v1/reports/charts`: 获取图表数据

#### 3.4.4 数据模型
```typescript
interface ReportItem {
  id: string;
  executionId: string;
  caseId: string;
  caseName: string;
  finalScore: number;
  result: string;
  details: ReportDetails;
  createdAt: Date;
}

interface ReportDetails {
  summary: string;
  details: {
    comprehensionSupport: string;
    engineeringUsefulness: string;
    explanationReasonableness: string;
    abstractionQuality: string;
    fabricationRisk: string;
  };
  engineeringAction: {
    level: string;
    description: string;
    recommendedAction: string;
  };
}
```

#### 3.4.5 实现要点
- 使用 ECharts 进行多种图表展示
- 支持多种格式导出 (PDF, Excel, JSON)
- 提供灵活的过滤和排序功能
- 实现历史对比分析

### 3.5 用户管理模块 (User Management Module)

#### 3.5.1 功能描述
用户管理模块提供多用户支持、权限管理和个人配置功能。

#### 3.5.2 组件结构
```
UserManagement/
├── index.tsx              # 用户管理主页面
├── components/
│   ├── UserTable.tsx      # 用户表格组件
│   ├── UserModal.tsx      # 用户编辑模态框
│   ├── ProfileSettings.tsx # 个人设置组件
│   ├── PermissionMatrix.tsx # 权限矩阵组件
│   └── ActivityLog.tsx    # 活动日志组件
└── hooks/
    ├── useUserData.ts     # 用户数据获取Hook
    └── useAuth.ts         # 认证相关Hook
```

#### 3.5.3 API 接口
- `GET /api/v1/users`: 获取用户列表
- `POST /api/v1/users`: 创建用户
- `PUT /api/v1/users/{id}`: 更新用户信息
- `DELETE /api/v1/users/{id}`: 删除用户
- `GET /api/v1/users/profile`: 获取个人资料
- `PUT /api/v1/users/profile`: 更新个人资料

#### 3.5.4 数据模型
```typescript
interface User {
  id: string;
  username: string;
  email: string;
  role: 'admin' | 'user' | 'viewer';
  createdAt: Date;
  lastLoginAt?: Date;
  isActive: boolean;
}

interface UserProfile {
  id: string;
  firstName: string;
  lastName: string;
  preferences: UserPreferences;
}

interface UserPreferences {
  theme: 'light' | 'dark';
  language: string;
  notifications: {
    email: boolean;
    inApp: boolean;
  };
}
```

#### 3.5.5 实现要点
- 实现基于角色的权限控制 (RBAC)
- 提供用户认证和会话管理
- 支持个人偏好设置
- 记录用户活动日志

## 4. API 设计规范

### 4.1 RESTful API 设计
- 使用标准 HTTP 方法 (GET, POST, PUT, DELETE)
- 使用名词复数形式表示资源
- 使用 HTTP 状态码表示操作结果
- 返回 JSON 格式数据

### 4.2 错误处理
```typescript
interface ErrorResponse {
  error: {
    code: string;
    message: string;
    details?: any;
  };
}
```

### 4.3 分页和过滤
- 支持标准分页参数 (page, size)
- 支持排序参数 (sort, order)
- 支持过滤参数 (filter)

## 5. 安全设计

### 5.1 认证机制
- JWT (JSON Web Token) 认证
- 令牌刷新机制
- 会话管理

### 5.2 授权机制
- 基于角色的访问控制 (RBAC)
- 细粒度权限控制
- API 速率限制

### 5.3 数据安全
- 敏感数据加密存储
- 输入验证和清理
- 防止常见 Web 攻击 (XSS, CSRF, SQL注入)

## 6. 性能优化

### 6.1 前端优化
- 代码分割和懒加载
- 组件虚拟化
- 数据缓存策略
- 图片优化

### 6.2 后端优化
- 数据库查询优化
- 缓存策略 (Redis)
- 异步处理
- 连接池管理

### 6.3 网络优化
- HTTP/2 支持
- 静态资源压缩
- CDN 加速

## 7. 部署架构

### 7.1 容器化部署
- Docker 容器化
- Docker Compose 编排
- 环境变量管理

### 7.2 监控和日志
- 应用性能监控
- 错误追踪
- 日志聚合
- 健康检查

---

**文档版本**: 1.0  
**创建日期**: 2026年2月9日  
**最后更新**: 2026年2月9日  
**作者**: System Assistant