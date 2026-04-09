# LiteLLM 轻量代理

> **定位**：本地 AI 模型网关，提供统一的 OpenAI 兼容接口
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
cp tools/gateway/litellm/env/.env.example tools/gateway/litellm/env/.env
```

编辑 `.env` 文件，填入真实值。

### 2. 启动服务

```bash
cd tools/gateway/litellm
./scripts/litellm.sh up
```

### 3. 验证启动

```bash
# 检查容器状态
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
| `LITELLM_OPENAI_QWEN_MODEL` | OpenAI 协议模型名 | 必需 |

### config.yaml 结构

```yaml
model_list:
  - model_name: qwen-plus
    litellm_params:
      model: openai/bailian/qwen-plus
      api_base: <端点>
      api_key: <密钥>

general_settings:
  master_key: <访问密钥>
```

---

## 常用命令

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

---

## 客户端接入

### OpenAI SDK

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

---

## 故障排查

```bash
# 1. 检查容器状态
docker compose -f compose/docker-compose.yml ps

# 2. 查看日志
docker compose -f compose/docker-compose.yml logs --tail 50 litellm

# 3. 验证健康端点
curl -s http://localhost:4000/health
```

---

## 修改配置

1. 编辑 `config/config.yaml`
2. 重启服务：`./scripts/litellm.sh restart`
