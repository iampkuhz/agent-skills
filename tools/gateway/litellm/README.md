# LiteLLM 轻量代理

> **定位**：本地 AI 模型网关，提供统一的 OpenAI 兼容接口
> **状态**：✅ 已迁移至 agent-tools 仓库
> **特点**：轻量、低内存（< 500MB）、单容器、本地可运行

---

## 目录结构

```
tools/gateway/litellm/
├── README.md           # 本文件
├── config/
│   └── config.yaml     # LiteLLM 主配置
├── compose/
│   └── docker-compose.yml
├── env/
│   └── .env.example    # 环境变量模板
└── scripts/
    └── litellm.sh      # 启动/停止脚本
```

---

## 快速开始

### 1. 准备环境变量

```bash
# 复制模板
cp tools/gateway/litellm/env/.env.example tools/gateway/litellm/env/.env

# 编辑 .env 文件，填入真实值
# 至少需要配置：
# - LITELLM_MASTER_KEY（生成随机 token）
# - BAILIAN_CODING_PLAN_API_KEY
```

### 2. 启动服务

**方式一：使用脚本**
```bash
cd tools/gateway/litellm
./scripts/litellm.sh up
```

**方式二：使用 Makefile（仓库根目录）**
```bash
make litellm-up
```

**方式三：直接使用 Docker Compose**
```bash
cd tools/gateway/litellm
# 先 source 环境变量或手动 export
docker compose -f compose/docker-compose.yml up -d
```

### 3. 验证启动

```bash
# 检查容器状态（应显示 healthy）
docker compose -f compose/docker-compose.yml ps

# 检查健康端点
curl -s http://localhost:4000/health

# 检查模型列表
curl -s http://localhost:4000/v1/models \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" | jq .
```

### 4. 测试对话

```bash
curl -s http://localhost:4000/v1/chat/completions \
  -X POST \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3.5-plus",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": false
  }' | jq .
```

---

## 配置说明

### 环境变量

| 变量名 | 用途 | 是否必需 |
|--------|------|----------|
| `LITELLM_MASTER_KEY` | LiteLLM 访问密钥 | 必需 |
| `BAILIAN_CODING_PLAN_API_KEY` | 百炼 API 密钥 | 必需 |
| `BAILIAN_CODING_PLAN_OPENAI_BASE_URL` | 百炼 OpenAI 兼容端点 | 必需 |
| `BAILIAN_CODING_PLAN_ANTHROPIC_BASE_URL` | 百炼 Anthropic 兼容端点 | 必需 |
| `LITELLM_OPENAI_QWEN_MODEL` | OpenAI 协议模型名 | 必需 |
| `LITELLM_ANTHROPIC_QWEN_MODEL` | Anthropic 协议模型名 | 必需 |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTel 端点（接 Braintrust/Arize） | 可选 |
| `OTEL_EXPORTER_OTLP_HEADERS` | OTel 请求头 | 可选 |
| `USE_OTEL_LITELLM_REQUEST_SPAN` | 是否启用 Request Span | 可选 |

### config.yaml 结构

```yaml
model_list:
  - model_name: <逻辑名>
    litellm_params:
      model: <provider/model-id>
      api_base: <端点>
      api_key: <密钥>

litellm_settings:
  # 当前不配置本地观测回调
  # 未来通过 OTel 接入云端平台

general_settings:
  master_key: <访问密钥>
```

---

## 常用命令

### 使用脚本
```bash
# 启动
./scripts/litellm.sh up

# 停止
./scripts/litellm.sh down

# 重启
./scripts/litellm.sh restart

# 查看日志
./scripts/litellm.sh logs

# 查看状态
./scripts/litellm.sh status
```

### 使用 Makefile
```bash
# 仓库根目录执行
make litellm-up
make litellm-down
make litellm-restart
```

### 直接使用 Docker Compose
```bash
cd tools/gateway/litellm

# 启动
docker compose -f compose/docker-compose.yml up -d

# 停止
docker compose -f compose/docker-compose.yml down

# 重启
docker compose -f compose/docker-compose.yml restart

# 日志
docker compose -f compose/docker-compose.yml logs -f
```

---

## 客户端接入

### OpenClaw

在 `~/.openclaw/.env` 配置：

```bash
OPENCLAW_BASE_URL=http://127.0.0.1:4000/v1
OPENCLAW_API_KEY=<与 LITELLM_MASTER_KEY 相同>
OPENCLAW_MODEL_ID=qwen3.5-plus
```

### 其他客户端

使用标准 OpenAI SDK 格式：

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:4000/v1",
    api_key="你的 LITELLM_MASTER_KEY"
)

response = client.chat.completions.create(
    model="qwen3.5-plus",
    messages=[{"role": "user", "content": "Hello"}]
)
```

### 透传 metadata（用于观测）

```python
response = client.chat.completions.create(
    model="qwen3.5-plus",
    messages=[{"role": "user", "content": "Test"}],
    metadata={
        "scene": "code_completion",
        "use_case": "unit_test",
        "client_name": "openclaw",
        "trace_id": "trace-001",
        "session_id": "session-001"
    }
)
```

**建议透传字段：**
- `scene` - 使用场景
- `use_case` - 具体用例
- `client_name` - 客户端标识
- `trace_id` - 链路追踪 ID
- `session_id` - 会话 ID

---

## 接入观测平台

### 当前配置

当前**不默认依赖任何本地观测组件**。LiteLLM 独立运行，无需 Langfuse、ClickHouse、Redis 等。

### 未来接入 Braintrust / Arize AX

只需配置 OTel 环境变量：

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=https://otlp.braintrust.dev
export OTEL_EXPORTER_OTLP_HEADERS=Authorization=Bearer your-key
export USE_OTEL_LITELLM_REQUEST_SPAN=true
```

然后重启 LiteLLM：

```bash
make litellm-restart
```

**为什么建议启用 `USE_OTEL_LITELLM_REQUEST_SPAN=true`？**

- Request Span 会记录完整的请求/响应生命周期
- 包含延迟、token 消耗、错误信息等关键指标
- 便于在观测平台中追踪端到端链路

---

## 架构说明

### 当前架构

```
┌──────────────┐     ┌──────────────┐     ┌─────────────────┐
│   客户端      │ ──► │  LiteLLM     │ ──► │  上游模型 API     │
│ (OpenClaw)   │     │  (端口 4000)  │     │ (百炼 / 其他)     │
└──────────────┘     └──────────────┘     └─────────────────┘
                              │
                              │ (可选 OTel)
                              ▼
                    ┌─────────────────┐
                    │ Braintrust /    │
                    │ Arize AX        │
                    └─────────────────┘
```

### 轻量化目标

| 指标 | 目标值 | 验证命令 |
|------|--------|----------|
| 容器数量 | 1 | `docker ps --filter name=litellm` |
| 内存占用 | < 500MB（空闲） | `docker stats litellm-proxy` |
| 启动时间 | < 30 秒 | - |

---

## 故障排查

**快速诊断命令：**

```bash
# 1. 检查容器状态
docker compose -f compose/docker-compose.yml ps

# 2. 查看日志
docker compose -f compose/docker-compose.yml logs --tail 50 litellm

# 3. 检查环境变量
docker inspect litellm-proxy | jq '.[0].Config.Env'

# 4. 验证健康端点
curl -s http://localhost:4000/health

# 5. 检查端口监听
lsof -i :4000
```

**常见问题：**

1. **容器启动失败**：检查 PostgreSQL 是否先启动完成
2. **API 返回 502**：检查容器内代理配置是否正确
3. **模型无法调用**：检查 BAILIAN_CODING_PLAN_API_KEY 是否正确

---

## 完成定义

满足以下**全部条件**时，可判定 LiteLLM 已可使用：

1. ✅ `docker compose up -d` 无错误，容器状态为 Up
2. ✅ `http://localhost:4000` 可访问，health 端点返回 200
3. ✅ `/v1/chat/completions` 返回有效响应
4. ✅ 文档完整（README + .env.example + config.yaml）
5. ✅ 仅运行 1 个 LiteLLM 容器，无 Langfuse 等重型依赖
6. ✅ OTel 配置位已预留，可无缝接入 Braintrust/Arize

---

## 迁移说明

本配置从以下外部目录迁移而来：

- **来源**：`/Users/zhehan/Documents/tools/dotfiles/observability/litellm`
- **目标**：`tools/gateway/litellm/`
- **改动**：
  - 调整了 compose 文件中的挂载路径为相对路径
  - 新增 scripts/litellm.sh 简化本地操作
  - 结构调整：config/、compose/、env/、scripts/ 分离
