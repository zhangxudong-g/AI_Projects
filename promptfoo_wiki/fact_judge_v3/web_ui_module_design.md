# Engineering Judge v3 Web UI 模块设计文档

## 1. 项目概述

### 1.1 项目背景
Engineering Judge v3 是一个基于 promptfoo 框架构建的工程导向 Wiki 质量评估系统。本项目旨在为其添加现代化的 Web UI，以提升用户体验和协作能力，同时保持现有命令行功能的完整性。

### 1.2 设计目标
- 提供直观的图形化界面
- 实现所有核心功能的 Web 化
- 保持与现有 CLI 的完全兼容
- 支持实时监控和可视化报告
- 提供友好的用户体验和无障碍访问
- 支持多语言国际化 (i18n)

### 1.3 设计原则
- **用户中心设计**: 以用户需求为核心，简化复杂操作流程
- **响应式设计**: 适配桌面端、平板和移动端设备
- **渐进式增强**: 在基本功能基础上逐步添加高级特性
- **可访问性**: 遵循 WCAG 2.1 AA 标准，确保所有用户都能使用
- **性能优先**: 优化加载速度和交互响应时间

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

#### 2.2.1 前端技术栈
- **框架**: React 18 + TypeScript
- **UI 库**: Ant Design 5.x + 自定义主题
- **状态管理**: Redux Toolkit 或 Zustand
- **路由**: React Router v6
- **HTTP 客户端**: Axios 或 SWR
- **表单处理**: React Hook Form + Zod 验证
- **国际化**: react-i18next
- **图表库**: Recharts / ECharts
- **代码编辑器**: Monaco Editor
- **样式**: Tailwind CSS + CSS Modules

#### 2.2.2 后端技术栈
- **Web 框架**: FastAPI (Python 3.9+)
- **数据库**: SQLite 3 (主库) + 内存缓存 (会话/临时数据)
- **ORM**: SQLAlchemy 2.x
- **异步任务**: Celery + RabbitMQ 或内置任务队列
- **实时通信**: WebSocket + Starlette
- **API 文档**: 自动生成 OpenAPI/Swagger
- **认证授权**: JWT + OAuth2
- **日志系统**: Structlog + Loguru

#### 2.2.3 部署与运维
- **容器化**: Docker + Docker Compose
- **反向代理**: Nginx
- **监控**: Prometheus + Grafana (可选)
- **日志收集**: 简单日志文件 + 可选 ELK Stack
- **CI/CD**: GitHub Actions

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
- 使用标准 HTTP 方法 (GET, POST, PUT, PATCH, DELETE)
- 使用名词复数形式表示资源
- 使用 HTTP 状态码表示操作结果
- 返回 JSON 格式数据
- 遵循 HATEOAS 原则提供资源链接
- 使用版本控制 (如 /api/v1/)

### 4.2 请求/响应格式

#### 4.2.1 成功响应格式
```typescript
interface SuccessResponse<T> {
  success: boolean;
  data: T;
  message?: string;
  timestamp: string;
  requestId: string;
}
```

#### 4.2.2 错误响应格式
```typescript
interface ErrorResponse {
  success: boolean;
  error: {
    code: string;        // 如: VALIDATION_ERROR, AUTH_FAILED
    message: string;     // 人类可读的错误信息
    details?: any;       // 具体错误详情
    timestamp: string;   // 错误发生时间
    requestId: string;   // 请求ID，用于调试
  };
}

// 验证错误特殊格式
interface ValidationError {
  field: string;
  message: string;
  value?: any;
}
```

### 4.3 分页和过滤
- 支持标准分页参数 (page, size)
- 支持排序参数 (sort, order)
- 支持过滤参数 (filter, search)
- 使用统一的分页响应格式：

```typescript
interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    size: number;
    total: number;
    totalPages: number;
    hasNext: boolean;
    hasPrev: boolean;
  };
}
```

### 4.4 API 版本控制
- 使用 URL 路径版本控制: `/api/v1/resource`
- 支持向后兼容性
- 提供版本迁移指南

### 4.5 速率限制
- 实现基于 IP 和用户的身份的速率限制
- 使用 HTTP 响应头返回速率限制信息
- 提供清晰的错误信息告知用户何时可以重试

## 5. 安全设计

### 5.1 认证机制
- JWT (JSON Web Token) 认证
- 令牌刷新机制
- 会话管理

### 5.2 授权机制
- 基于角色的访问控制 (RBAC)
- 细粒度权限控制
- 基于令牌的 API 速率限制

### 5.3 数据安全
- 敏感数据加密存储
- 输入验证和清理
- 防止常见 Web 攻击 (XSS, CSRF, SQL注入)

## 6. 数据库设计

### 6.1 设计原则
- **简约设计**: 只包含必要实体，避免过度设计
- **轻量化**: 使用 SQLite 作为主要数据库，减少运维复杂度
- **嵌入式**: 无需独立数据库服务器，简化部署
- **扩展性**: 预留扩展字段，支持未来功能扩展

### 6.2 核心实体设计

#### 6.2.1 用户表 (users)
```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY, -- 使用UUID字符串
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT DEFAULT 'user', -- admin, user, viewer
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### 6.2.2 案例表 (cases)
```sql
CREATE TABLE cases (
    id TEXT PRIMARY KEY, -- 使用UUID字符串
    name TEXT NOT NULL,
    description TEXT,
    config_yaml TEXT NOT NULL, -- 存储YAML配置
    created_by TEXT, -- 外键引用users.id
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### 6.2.3 执行记录表 (executions)
```sql
CREATE TABLE executions (
    id TEXT PRIMARY KEY, -- 使用UUID字符串
    case_id TEXT, -- 外键引用cases.id
    user_id TEXT, -- 外键引用users.id
    status TEXT DEFAULT 'queued', -- queued, running, completed, failed, stopped
    progress INTEGER DEFAULT 0, -- 执行进度百分比
    start_time DATETIME,
    end_time DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### 6.2.4 报告表 (reports)
```sql
CREATE TABLE reports (
    id TEXT PRIMARY KEY, -- 使用UUID字符串
    execution_id TEXT UNIQUE, -- 外键引用executions.id
    case_id TEXT, -- 外键引用cases.id
    final_score INTEGER,
    result TEXT, -- PASS, FAIL
    details TEXT, -- JSON字符串存储详细的评估结果
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### 6.2.5 系统配置表 (system_configs)
```sql
CREATE TABLE system_configs (
    id TEXT PRIMARY KEY, -- 使用UUID字符串
    config_key TEXT UNIQUE NOT NULL,
    config_value TEXT,
    description TEXT,
    updated_by TEXT, -- 外键引用users.id
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### 6.3 索引策略
- 为主键自动创建索引
- 在经常查询的字段上创建索引 (如 users.username, cases.created_at)
- 为外键关系创建索引以提高JOIN性能

### 6.4 缓存策略
- **应用层缓存**: 使用内存缓存 (如 Python 的 functools.lru_cache 或 cachetools)
- **会话管理**: 基于 JWT 的无状态会话，减少服务器端存储需求
- **静态数据缓存**: 缓存配置信息和常用查询结果
- **实现示例**: 
  - 使用 FastAPI 的内置依赖注入系统管理缓存实例
  - 采用内存字典或第三方库 (如 diskcache) 实现跨进程缓存
  - 为不同类型的缓存数据设置合适的过期时间

### 6.5 SQLite 优化
- 使用 WAL 模式提高并发性能
- 合理设置缓存大小
- 定期执行 VACUUM 清理碎片
- 使用 PRAGMA 设置优化性能参数

## 7. 测试策略

### 7.1 前端测试
- **单元测试**: 使用 Jest + React Testing Library
- **集成测试**: 测试组件间交互
- **端到端测试**: 使用 Playwright 或 Cypress
- **视觉回归测试**: 确保 UI 一致性
- **可访问性测试**: 使用 axe-core 进行自动化检查

### 7.2 后端测试
- **单元测试**: 使用 pytest 进行函数和类测试
- **集成测试**: 测试 API 端点和数据库交互
- **契约测试**: 确保 API 向后兼容性
- **性能测试**: 使用 Locust 进行负载测试
- **安全测试**: 自动化漏洞扫描

### 7.3 测试覆盖率
- 目标: 前端和后端均达到 85% 以上覆盖率
- 集成到 CI/CD 流水线
- 生成测试报告和覆盖率报告

## 8. 性能优化

### 8.1 前端优化
- 代码分割和懒加载
- 组件虚拟化
- 数据缓存策略
- 图片优化
- 预加载和预获取策略
- 减少第三方库依赖

### 8.2 后端优化
- 数据库查询优化
- 应用层缓存策略 (内存缓存)
- 异步处理
- 连接池管理
- API 响应压缩
- 数据库索引优化

### 8.3 网络优化
- HTTP/2 支持
- 静态资源压缩
- CDN 加速
- 请求合并和批处理

## 9. Windows 兼容性与部署

### 9.1 Windows 环境适配
- **Python 环境**: 使用 Python 3.9+ 和虚拟环境
- **路径处理**: 使用 pathlib 处理跨平台路径差异
- **进程管理**: 使用 Windows 服务或任务计划程序管理后台任务
- **文件编码**: 统一使用 UTF-8 编码

### 9.2 Windows 服务部署
- **服务创建**: 使用 NSSM (Non-Sucking Service Manager) 或 winsw 创建 Windows 服务
- **进程守护**: 实现自动重启和错误恢复机制
- **日志管理**: 配置 Windows 事件日志或文件日志

### 9.3 任务队列在 Windows 上的实现
- **Celery 替代**: 使用 APScheduler 或直接使用 asyncio 实现定时任务
- **后台任务**: 利用 Windows 任务计划程序执行周期性任务
- **异步处理**: 采用 Python 内置的 asyncio 或 concurrent.futures

### 9.4 性能考虑
- **内存管理**: Windows 环境下的内存使用优化
- **并发处理**: 适应 Windows 的异步 I/O 模型

## 10. 国际化与本地化

### 10.1 国际化策略
- 使用 react-i18next 进行前端国际化
- 支持动态语言切换
- 提供 RTL (Right-to-Left) 语言支持
- 日期、数字、货币格式本地化

### 10.2 语言包管理
- 统一的语言包结构
- 支持嵌套命名空间
- 提供翻译记忆库
- 支持复数形式和上下文翻译

### 10.3 本地化内容
- 日期时间格式本地化
- 数字和货币格式本地化
- 文本方向 (LTR/RTL) 支持
- 文化特定内容展示

## 11. 部署架构

### 11.1 部署选项
- **容器化部署**:
  - Docker 容器化 (适用于 Linux 环境)
  - Docker Compose 编排
  - 环境变量管理
  - 多阶段构建优化镜像大小
- **Windows 原生部署**:
  - Python 虚拟环境
  - 直接运行 FastAPI 应用
  - Windows 服务或任务计划程序管理后台任务

### 11.2 CI/CD 流水线
- 自动化测试 (单元测试、集成测试、E2E测试)
- 自动化构建和部署
- 金丝雀发布策略
- 回滚机制

### 11.3 监控和日志
- 应用性能监控
- 错误追踪
- 日志聚合
- 健康检查
- 自定义业务指标监控

## 12. 已实现功能总结

### 12.1 WebSocket 实时通信
- **实时执行监控**: 通过 `/ws/execution/{execution_id}` 端点实现实时执行状态更新
- **双向通信**: 支持服务器向客户端推送执行进度和状态变化
- **连接管理**: 实现了连接池和断开重连机制

### 12.2 调度执行功能
- **定时执行**: 通过 `/api/v1/executions/schedule` 端点支持定时执行任务
- **任务队列**: 集成 APScheduler 实现任务调度
- **延迟执行**: 支持在未来某个时间点执行评估任务

### 12.3 批量导入功能
- **多格式支持**: 支持 JSON 和 YAML 格式的批量导入
- **批量处理**: 通过 `/api/v1/cases/import` 端点实现批量案例导入
- **数据验证**: 导入过程中进行数据格式和完整性验证

### 12.4 报告过滤、排序和导出
- **前端过滤**: 支持按状态、分数范围、日期等条件过滤
- **多维排序**: 支持按分数、日期、状态等字段排序
- **多格式导出**: 支持 JSON、CSV 等多种格式导出
- **批量导出**: 支持批量报告导出功能

### 12.5 用户个人资料和偏好设置
- **个人资料管理**: 通过 `/api/v1/users/profile` 端点管理用户个人资料
- **偏好设置**: 支持主题、语言、通知等个性化设置
- **资料更新**: 支持用户自主更新个人资料信息

### 12.6 活动日志功能
- **操作记录**: 记录用户的关键操作和系统事件
- **日志查询**: 通过 `/api/v1/users/activity-log` 端点查询活动日志
- **审计追踪**: 支持按时间范围和操作类型筛选日志

### 12.7 案例模板功能
- **预设模板**: 提供常用的案例模板
- **模板管理**: 通过 `/api/v1/cases/templates` 端点管理模板
- **快速创建**: 支持基于模板快速创建新案例

### 12.8 安全和权限控制
- **JWT 认证**: 基于 JWT 的无状态认证机制
- **RBAC 权限**: 基于角色的访问控制
- **细粒度权限**: 不同角色拥有不同操作权限

### 12.9 性能优化
- **应用层缓存**: 使用内存缓存提高数据访问速度
- **数据库优化**: 索引优化和查询优化
- **前端优化**: 代码分割和懒加载

### 12.10 国际化支持
- **多语言**: 支持中英文界面切换
- **本地化**: 日期、数字、货币格式本地化
- **RTL 支持**: 支持从右到左的语言显示

---

**文档版本**: 1.6  
**创建日期**: 2026年2月9日  
**最后更新**: 2026年2月10日  
**作者**: System Assistant