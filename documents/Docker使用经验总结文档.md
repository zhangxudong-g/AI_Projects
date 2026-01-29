# Docker使用经验总结文档

## 1. 概述

本文档总结了Docker容器化技术的使用经验和最佳实践。Docker是一个开源的容器化平台，可以帮助开发者打包应用及其依赖项到一个可移植的容器中，并在任何支持Docker的环境中运行。

## 2. Dockerfile最佳实践

### 2.1 多阶段构建

使用多阶段构建可以显著减小最终镜像的大小，同时保持构建过程的完整性：

```dockerfile
# 构建阶段
FROM node:18-alpine AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN npm config set registry https://registry.npmmirror.com/ && \
    npm install -g pnpm && \
    pnpm config set registry https://registry.npmmirror.com/ && \
    pnpm install
COPY . .
RUN node_modules/.bin/next build --no-lint

# 生产阶段
FROM node:18-alpine
WORKDIR /app
ENV NODE_ENV production
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/public ./public

EXPOSE 3000
CMD ["node_modules/.bin/next", "start"]
```

### 2.2 镜像标签策略

- 使用特定版本标签而不是`latest`，例如`node:18-alpine`而不是`node:latest`
- 避免频繁更改基础镜像，以充分利用构建缓存
- 为不同的环境构建不同的标签

### 2.3 层级优化

合理安排Dockerfile指令顺序，将变化较少的指令放在前面，以充分利用Docker的构建缓存：

```dockerfile
# 先复制依赖文件
COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install

# 再复制源代码
COPY . .
```

### 2.4 安全性

- 以非root用户运行容器
- 使用`.dockerignore`文件排除不必要的文件
- 避免在镜像中包含敏感信息

## 3. Docker Compose配置

### 3.1 基本配置

Docker Compose用于定义和运行多容器Docker应用程序：

```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    volumes:
      - ./data:/app/data
    depends_on:
      - db
    restart: unless-stopped

  db:
    image: postgres:13
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  postgres_data:
```

### 3.2 资源限制

配置适当的资源限制以防止容器消耗过多系统资源：

```yaml
services:
  app:
    # ...
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'
```

### 3.3 健康检查

配置健康检查确保服务正常运行：

```yaml
services:
  app:
    # ...
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## 4. Docker服务配置

### 4.1 服务管理

Docker服务配置通常位于`/usr/lib/systemd/system/docker.service`，可以进行以下配置：

- 配置TCP端口以支持远程管理（谨慎使用）
- 调整存储驱动和日志配置
- 配置镜像仓库镜像加速

示例配置：
```bash
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 --containerd=/run/containerd/containerd.sock
```

### 4.2 存储配置

- 选择合适的存储驱动（overlay2推荐）
- 配置日志轮转策略
- 定期清理未使用的数据

## 5. 镜像管理

### 5.1 镜像构建

- 使用`.dockerignore`文件排除不必要的文件
- 合理使用构建参数（build args）
- 利用构建缓存优化构建速度

### 5.2 镜像分发

- 使用`docker save`和`docker load`进行离线部署
- 压缩镜像以减小传输大小：
  ```bash
  docker save 镜像名:标签 | gzip > 镜像名.tar.gz
  gunzip -c 镜像名.tar.gz | docker load
  ```
- 定期清理未使用的镜像：
  ```bash
  docker image prune -a
  ```

## 6. 容器操作

### 6.1 基本操作

- 运行容器：`docker run -d --name mycontainer image:tag`
- 查看容器：`docker ps -a`
- 进入容器：`docker exec -it container_name bash`
- 查看日志：`docker logs container_name`
- 停止容器：`docker stop container_name`

### 6.2 监控和调试

- 查看资源使用情况：`docker stats`
- 查看容器详细信息：`docker inspect container_name`
- 查看镜像层信息：`docker history image_name`

## 7. 网络配置

### 7.1 网络类型

- Bridge（默认）：适用于单主机上的容器通信
- Host：容器直接使用宿主机网络
- Overlay：适用于多主机集群
- Macvlan：为容器分配MAC地址

### 7.2 自定义网络

创建自定义网络以更好地管理容器间通信：

```bash
docker network create mynetwork
docker run --network mynetwork --name mycontainer image:tag
```

## 8. 安全最佳实践

### 8.1 运行时安全

- 以非root用户运行容器
- 使用只读根文件系统（如果可能）
- 限制容器的capabilities
- 使用seccomp和AppArmor配置文件

### 8.2 镜像安全

- 定期更新基础镜像
- 扫描镜像漏洞
- 避免在镜像中包含敏感数据
- 使用官方或可信的基础镜像

## 9. 性能优化

### 9.1 镜像优化

- 使用轻量级基础镜像（如Alpine Linux）
- 删除不必要的包和文件
- 合并相似的Dockerfile指令
- 使用多阶段构建

### 9.2 运行时优化

- 配置适当的资源限制
- 使用volume进行I/O密集型数据存储
- 启用Docker的实验特性（如果需要）
- 调整存储驱动参数

## 10. 离线部署

### 10.1 镜像导出导入

对于离线环境部署，需要预先准备所需镜像：

```bash
# 导出镜像
docker save 镜像名:标签 | gzip > 镜像文件.tar.gz

# 导入镜像
gunzip -c 镜像文件.tar.gz | docker load
```

### 10.2 依赖管理

- 准备所有必需的基础镜像
- 创建离线部署脚本
- 验证所有依赖项都已准备就绪

## 11. 故障排除

### 11.1 常见问题

- 容器无法启动：检查日志、端口冲突、权限问题
- 网络连接问题：检查网络配置、防火墙设置
- 存储问题：检查磁盘空间、权限设置
- 性能问题：检查资源限制、监控指标

### 11.2 调试技巧

- 使用`docker logs -f container_name`实时查看日志
- 使用`docker exec -it container_name sh`进入容器调试
- 使用`docker stats`监控资源使用情况
- 使用`docker inspect`查看详细配置

## 12. 生产环境部署

### 12.1 编排工具

- Docker Compose：适用于单主机部署
- Docker Swarm：Docker原生集群解决方案
- Kubernetes：更复杂的容器编排平台

### 12.2 监控和日志

- 集成集中式日志系统（如ELK Stack）
- 配置应用性能监控
- 设置告警机制
- 定期备份重要数据

## 13. 总结

Docker为应用程序的开发、部署和运行提供了强大的容器化解决方案。通过遵循上述最佳实践，可以构建安全、高效、可维护的容器化应用。关键是要理解Docker的核心概念，合理配置容器环境，并持续关注安全和性能优化。