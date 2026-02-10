# Engineering Judge v3 前端使用手册 (Windows)

## 目录
1. [系统要求](#系统要求)
2. [环境准备](#环境准备)
3. [安装步骤](#安装步骤)
4. [开发模式运行](#开发模式运行)
5. [生产构建](#生产构建)
6. [功能使用指南](#功能使用指南)
7. [常见问题](#常见问题)

## 系统要求

- **操作系统**: Windows 10/11 (推荐)
- **Node.js**: 16.x 或更高版本
- **内存**: 至少 4GB RAM (推荐 8GB)
- **硬盘**: 至少 1GB 可用空间
- **浏览器**: Chrome 90+, Firefox 88+, Edge 90+, Safari 14+

## 环境准备

### 1. 安装 Node.js
1. 访问 [Node.js 官网](https://nodejs.org/)
2. 下载 LTS 版本 (推荐)
3. 安装时勾选 "Add to PATH"
4. 验证安装：打开命令提示符，输入 `node --version` 和 `npm --version`

### 2. 安装 Git (如果尚未安装)
- 下载并安装 [Git for Windows](https://git-scm.com/download/win)
- 验证安装：打开命令提示符，输入 `git --version`

## 安装步骤

### 1. 克取项目代码
```cmd
git clone <repository-url>
cd promptfoo_wiki\fact_judge_v3\frontend
```

### 2. 安装依赖包
```cmd
npm install
```

如果使用 yarn：
```cmd
yarn install
```

### 3. 配置环境变量
创建 `.env` 文件（位于 frontend 目录下）：

```env
# 开发环境配置
REACT_APP_API_BASE_URL=http://localhost:8000
REACT_APP_ENVIRONMENT=development

# 生产环境配置
GENERATE_SOURCEMAP=false
```

## 开发模式运行

### 1. 启动开发服务器
```cmd
npm run dev
```

或使用 yarn：
```cmd
yarn dev
```

### 2. 访问应用
- 应用将在 `http://localhost:3000` 启动
- 自动在默认浏览器中打开
- 代码更改时自动热重载

### 3. 开发工具
- **React Developer Tools**: Chrome 扩展，用于调试 React 组件
- **Redux DevTools**: 如果使用 Redux，用于状态管理调试

## 生产构建

### 1. 构建生产版本
```cmd
npm run build
```

或使用 yarn：
```cmd
yarn build
```

### 2. 构建产物
- 构建结果位于 `build` 目录
- 包含优化后的静态文件
- 可以部署到任何静态文件服务器

### 3. 本地预览生产构建
```cmd
npm run serve
```

## 功能使用指南

### 1. 登录和认证
1. 打开应用后，如果需要登录，将跳转到登录页面
2. 输入用户名和密码
3. 登录成功后，JWT 令牌将存储在浏览器本地存储中

### 2. 仪表盘 (Dashboard)
- **功能**: 显示系统概览信息
- **内容**: 
  - 统计卡片 (总执行数、成功率、平均分数、最近失败数)
  - 趋势图表 (周执行数和平均分数)
  - 快捷操作按钮
  - 最近活动列表

### 3. 测试案例管理 (Test Cases)
- **功能**: 管理测试案例
- **操作**:
  - **查看案例**: 在案例表格中查看所有案例
  - **添加案例**: 点击 "Add Case" 按钮
  - **编辑案例**: 点击 "Edit" 按钮
  - **删除案例**: 点击 "Delete" 按钮
  - **批量导入**: 点击 "Import Cases" 按钮，支持 JSON/YAML 格式

### 4. 执行控制 (Executions)
- **功能**: 管理执行任务
- **操作**:
  - **启动执行**: 点击 "Start New Execution" 按钮
  - **调度执行**: 点击 "Schedule Execution" 按钮设置定时执行
  - **监控执行**: 查看执行进度和状态
  - **暂停执行**: 点击 "Pause" 按钮
  - **停止执行**: 点击 "Stop" 按钮

### 5. 报告系统 (Reports)
- **功能**: 查看和管理评估报告
- **操作**:
  - **查看报告**: 在报告表格中查看所有报告
  - **过滤报告**: 使用表格过滤功能
  - **排序报告**: 点击列标题进行排序
  - **导出报告**: 
    - 单个导出: 点击操作列的下拉菜单选择导出格式
    - 批量导出: 点击 "Export Reports" 下拉菜单
  - **图表查看**: 查看分数分布和成功率图表

### 6. 用户管理 (Users)
- **功能**: 管理系统用户
- **操作**:
  - **查看用户**: 在用户表格中查看所有用户
  - **添加用户**: 点击 "Add User" 按钮
  - **编辑用户**: 点击 "Edit" 按钮
  - **删除用户**: 点击 "Delete" 按钮
  - **个人资料**: 点击 "My Profile" 按钮管理个人资料
  - **活动日志**: 点击 "Activity Log" 按钮查看活动记录

### 7. 个人资料管理
- **功能**: 管理个人资料和偏好设置
- **内容**:
  - **个人资料**: 编辑用户名、邮箱等基本信息
  - **偏好设置**: 
    - 主题选择 (浅色/深色)
    - 语言设置 (英语/中文)
    - 通知设置 (邮件/应用内通知)

### 8. 案例模板
- **功能**: 使用预设模板快速创建案例
- **使用**: 在创建案例时选择合适的模板

## 常见问题

### 1. 依赖安装失败
如果 `npm install` 失败，尝试：
```cmd
npm cache clean --force
npm install --registry https://registry.npmmirror.com
```

### 2. 端口被占用
如果 3000 端口被占用，开发服务器会自动询问是否使用其他端口。

### 3. API 连接失败
确保后端服务正在运行且 URL 配置正确：
- 检查 `.env` 文件中的 `REACT_APP_API_BASE_URL`
- 确认后端服务在 `http://localhost:8000` 运行

### 4. 构建失败
如果 `npm run build` 失败：
- 检查是否有 JavaScript 错误
- 确保所有依赖都已正确安装
- 尝试清理缓存：`npm cache clean --force`

### 5. 热重载不工作
- 检查防火墙设置
- 确保没有其他应用占用相关端口
- 重启开发服务器

### 6. 性能问题
如果应用运行缓慢：
- 关闭不必要的浏览器扩展
- 确保有足够的内存
- 检查网络连接

## 自定义配置

### 1. 主题定制
项目使用 Ant Design，可以通过以下方式定制主题：
- 修改 `src/styles/theme.js`
- 重新编译应用

### 2. 环境变量
- **开发环境**: `.env.development`
- **生产环境**: `.env.production`
- **通用配置**: `.env`

### 3. 代理配置
开发模式下的 API 代理配置在 `package.json` 中：
```json
"proxy": "http://localhost:8000"
```

## 故障排除

### 1. 登录问题
- 检查用户名和密码是否正确
- 确认后端认证服务正常运行
- 清除浏览器缓存和本地存储

### 2. 数据加载失败
- 检查网络连接
- 确认后端 API 服务正常
- 查看浏览器开发者工具的网络标签页

### 3. 权限问题
- 确认用户角色和权限设置
- 检查后端权限控制配置

## 更新和维护

### 1. 代码更新
```cmd
git pull origin main
npm install
npm start
```

### 2. 依赖更新
```cmd
npm update
# 或更新特定包
npm update package-name
```

### 3. 清理缓存
```cmd
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
```

---
**文档版本**: 1.0  
**最后更新**: 2026年2月10日