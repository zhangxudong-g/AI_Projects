# Ollama和vLLM使用经验总结文档

## 1. 概述

本文档总结了Ollama和vLLM两个流行的大型语言模型推理框架的使用经验和最佳实践。Ollama以其简单易用著称，而vLLM则以高性能推理闻名。本文将详细介绍两者的配置方法、使用技巧和适用场景。

## 2. Ollama使用经验

### 2.1 环境变量配置

Ollama提供了丰富的环境变量来控制其行为：

- `OLLAMA_DEBUG`: 启用调试信息（如OLLAMA_DEBUG=1）
- `OLLAMA_HOST`: 服务器IP地址（默认127.0.0.1:11434）
- `OLLAMA_KEEP_ALIVE`: 模型在内存中的保留时间（默认5分钟）
- `OLLAMA_MAX_LOADED_MODELS`: 每个GPU上最大加载模型数
- `OLLAMA_MAX_QUEUE`: 最大排队请求数
- `OLLAMA_MODELS`: 模型存储路径
- `OLLAMA_NUM_PARALLEL`: 最大并行请求数
- `OLLAMA_GPU_LAYERS`: GPU推理层数
- `OLLAMA_NUM_GPU`: 使用GPU数量

### 2.2 系统服务配置

Ollama可以通过systemd进行管理，在`/etc/systemd/system/ollama.service`中配置：

```ini
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_MAX_LOADED_MODELS=2"
Environment="OLLAMA_NUM_PARALLEL=6"
Environment="OLLAMA_MAX_QUEUE=1024"
Environment="OLLAMA_MAX_VRAM=60GB"
Environment="PATH=/home/ps/miniconda3/bin:/home/ps/miniconda3/condabin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"

[Install]
WantedBy=default.target
```

配置完成后使用以下命令管理服务：
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
sudo systemctl status ollama
```

### 2.3 性能优化

- **自动资源配置**：根据系统资源自动调整参数
  - `OLLAMA_MAX_LOADED_MODELS`: 每64GB内存允许加载1个模型
  - `OLLAMA_NUM_PARALLEL`: 每4个CPU核心允许1个并行任务
  - `OLLAMA_MAX_QUEUE`: 默认设置为1024

- **内存管理**：合理设置VRAM限制，避免内存溢出

- **并行处理**：根据CPU核心数调整并行请求数

### 2.4 监控和调试

- 查看服务状态：`sudo systemctl status ollama`
- 查看实时日志：`journalctl -u ollama -f`
- 检查端口监听：`sudo netstat -tulnp | grep 11434`
- Windows日志跟踪：`Get-Content -Path "$env:USERPROFILE\.ollama\logs\server.log" -Wait -Tail 50`

### 2.5 API使用

Ollama提供标准的OpenAI兼容API接口，支持：
- Chat completions
- Completions
- 模型管理
- 流式响应

## 3. vLLM使用经验

### 3.1 模型下载和准备

使用Hugging Face CLI下载模型时，建议设置以下环境变量避免下载问题：

```bash
export HF_HUB_DISABLE_XET=1
export HF_HUB_ENABLE_HF_TRANSFER=0
```

下载脚本示例：
```bash
#!/usr/bin/env bash
set -e

MODEL_ID="Qwen/Qwen2.5-32B-Instruct"
TARGET_DIR="/home/ps/vllm/models/Qwen2.5-32B-Instruct"

mkdir -p "${TARGET_DIR}"

huggingface-cli download "${MODEL_ID}" \
  --local-dir "${TARGET_DIR}" \
  --local-dir-use-symlinks False \
  --resume-download \
  --max-workers 1

# 验证必要文件
test -f "${TARGET_DIR}/config.json"
test -f "${TARGET_DIR}/tokenizer.json"
```

### 3.2 启动配置

vLLM启动时的关键配置参数：

```bash
python -m vllm.entrypoints.openai.api_server \
  --model "${MODEL_DIR}" \
  --served-model-name "${SERVED_NAME}" \
  --host 0.0.0.0 \
  --port "${PORT}" \
  \
  --tensor-parallel-size 2 \  # 张量并行大小
  --dtype bfloat16 \          # 数据类型
  \
  --max-model-len 8192 \      # 最大模型长度
  --max-num-seqs 8 \          # 最大序列数
  --gpu-memory-utilization 0.80 \  # GPU内存利用率
  \
  --disable-log-requests \    # 禁用请求日志
  --trust-remote-code         # 信任远程代码
```

### 3.3 性能优化配置

- **CUDA内存管理**：
  ```bash
  export CUDA_VISIBLE_DEVICES=0,1
  export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,max_split_size_mb:256
  ```

- **高性能模式**：在高负载场景下，可调整参数：
  - 增加GPU内存利用率至0.90
  - 减少并发序列数以保证稳定性

- **张量并行**：根据GPU数量配置tensor-parallel-size

### 3.4 API接口

vLLM提供兼容OpenAI API的接口：

- `/v1/chat/completions` - 聊天完成接口
- `/v1/completions` - 文本完成接口
- `/v1/models` - 模型列表接口

### 3.5 客户端调用

#### Python客户端示例：
```python
import requests
import json

def chat_completion(messages, temperature=0.7, max_tokens=1024):
    url = "http://localhost:8010/v1/chat/completions"
    
    payload = {
        "model": "qwen32b",
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "stream": False
    }

    headers = {"Content-Type": "application/json"}
    
    response = requests.post(url, headers=headers, data=json.dumps(payload))
    return response.json()
```

#### curl命令示例：
```bash
curl -X POST "http://localhost:8010/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen32b",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Hello, how are you today?"}
    ],
    "temperature": 0.7,
    "max_tokens": 150
  }'
```

### 3.6 压力测试

使用asyncio和aiohttp进行并发测试：

```python
import asyncio
import aiohttp
import time

async def send_request(session, idx):
    payload = {
        "model": "qwen32b",
        "messages": [
            {"role": "user", "content": "Your prompt here"}
        ],
        "max_tokens": 512,
        "temperature": 0.2
    }

    start = time.time()
    async with session.post(API_URL, json=payload) as resp:
        result = await resp.json()
        latency = time.time() - start
        print(f"[REQ {idx}] status={resp.status} latency={latency:.2f}s")
        return latency
```

## 4. Ollama与vLLM对比

### 4.1 架构差异

| 特性 | Ollama | vLLM |
|------|--------|------|
| 部署复杂度 | 简单，开箱即用 | 相对复杂，需要更多配置 |
| 性能 | 适合中小型模型 | 针对大型模型优化，性能更高 |
| 内存管理 | 标准管理 | PagedAttention技术，更高效 |
| 模型库 | 内置丰富模型库 | 需要自行准备模型文件 |

### 4.2 性能特点

- **Ollama**：
  - 适合中小型模型
  - 简单易用，适合快速原型开发
  - 支持多种硬件平台（CPU/GPU）
  - 适合个人开发者和小团队

- **vLLM**：
  - 针对大型模型优化
  - 更高的吞吐量和更低的延迟
  - 支持张量并行处理
  - 适合企业级高并发应用

### 4.3 使用场景

- **Ollama适用场景**：
  - 快速原型开发
  - 个人项目和实验
  - 边缘设备部署
  - 需要简单管理界面的场景

- **vLLM适用场景**：
  - 高并发生产环境
  - 大型语言模型服务
  - 需要最大化吞吐量的应用
  - 对延迟敏感的服务

### 4.4 配置复杂度

- **Ollama**：配置相对简单，主要通过环境变量和服务文件配置
- **vLLM**：配置更复杂但更灵活，需要更多参数调优

## 5. 最佳实践

### 5.1 Ollama最佳实践

1. **资源规划**：根据硬件资源合理设置环境变量
2. **服务管理**：使用systemd管理服务生命周期
3. **监控日志**：定期检查服务状态和日志
4. **安全配置**：正确配置访问控制和网络设置

### 5.2 vLLM最佳实践

1. **模型准备**：确保模型文件完整性和正确性
2. **参数调优**：根据硬件配置调整内存和并行参数
3. **性能测试**：部署前进行充分的压力测试
4. **监控告警**：建立完善的监控体系

## 6. 故障排除

### 6.1 Ollama常见问题

- 内存不足：调整OLLAMA_MAX_LOADED_MODELS参数
- GPU未使用：检查OLLAMA_NUM_GPU和驱动程序
- API访问失败：确认OLLAMA_HOST设置和防火墙配置

### 6.2 vLLM常见问题

- CUDA错误：检查CUDA版本和驱动程序兼容性
- 内存溢出：调整gpu-memory-utilization参数
- 启动失败：验证模型文件完整性和路径配置

## 7. 总结

Ollama和vLLM都是优秀的LLM推理框架，选择哪个取决于具体的应用场景和需求。对于快速原型开发和个人项目，Ollama是更好的选择；而对于需要高性能和高并发的企业级应用，vLLM更适合。