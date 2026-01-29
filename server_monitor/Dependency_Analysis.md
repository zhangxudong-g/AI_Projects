# 项目依赖分析报告

## 已安装的依赖 (requirements.txt)

| 库名 | 版本 | 用途 |
|------|------|------|
| fastapi | 0.104.1 | Web框架 |
| uvicorn | 0.24.0 | ASGI服务器 |
| asyncssh | 2.14.0 | 异步SSH客户端 |
| pyyaml | 6.0.1 | YAML解析 |
| jinja2 | 3.1.2 | 模板引擎 |
| aiofiles | 23.2.1 | 异步文件操作 |
| websockets | 12.0 | WebSocket支持 |
| sqlalchemy | 2.0.23 | ORM数据库操作 |
| aiosqlite | 0.19.0 | 异步SQLite支持 |
| numpy | >=1.24.3 | 数值计算 |
| pandas | >=2.0.3 | 数据处理 |
| pydantic | 2.5.0 | 数据验证 |
| aiohttp | 3.9.0 | HTTP客户端 |
| setuptools | >=65.0.0 | Python包管理 |
| bcrypt | 4.0.1 | 密码加密 |
| pyjwt | 2.8.0 | JWT支持 |
| python-multipart | 0.0.6 | 表单解析 |

## 标准库使用情况

以下Python标准库模块已在代码中使用，无需添加到requirements.txt：

- asyncio: 异步编程
- json: JSON处理
- subprocess: 子进程管理
- shlex: Shell词法分析
- logging: 日志记录
- time: 时间处理
- datetime: 日期时间处理
- re: 正则表达式
- ssl: SSL/TLS支持
- email.mime: 邮件处理
- threading: 线程操作
- hashlib: 哈希算法
- base64: Base64编码
- gzip: Gzip压缩
- zlib: Zlib压缩
- pickle: 对象序列化
- os: 操作系统接口
- inspect: 内省功能
- importlib: 模块导入
- pathlib: 路径操作
- enum: 枚举类型
- dataclasses: 数据类
- typing: 类型提示
- collections: 集合类型

## 前端依赖

前端使用了以下CDN资源（在index.html中）：

- Bootstrap 5.3.0: CSS框架
- Font Awesome 6.0.0: 图标库
- Chart.js: 图表库
- Pako 2.1.0: 压缩库

## 总结

requirements.txt文件已完整包含了项目所需的所有第三方Python库。
所有标准库模块均无需添加到requirements.txt中。
前端依赖通过CDN引入，无需在Python环境中安装。