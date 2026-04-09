# SearXNG 私有搜索引擎

> **定位**：私有化、无追踪的元搜索引擎
> **状态**：✅ 已迁移至 agent-tools 仓库
> **特点**：多引擎聚合、隐私保护、可自托管

---

## 目录结构

```
tools/search/searxng/
├── README.md           # 本文件
├── settings/
│   ├── settings.yml    # SearXNG 主配置
│   └── limiter.toml    # 限流器配置
├── compose/
│   └── docker-compose.yml
├── env/
│   └── .env.example    # 环境变量模板
└── scripts/
    └── searxng.sh      # 启动/停止脚本
```

---

## 快速开始

### 1. 启动服务

**方式一：使用脚本**
```bash
cd tools/search/searxng
./scripts/searxng.sh up
```

**方式二：使用 Makefile（仓库根目录）**
```bash
make searxng-up
```

**方式三：直接使用 Docker Compose**
```bash
cd tools/search/searxng
docker compose -f compose/docker-compose.yml up -d
```

### 2. 验证启动

```bash
# 检查容器状态
docker compose -f compose/docker-compose.yml ps

# 检查健康端点
curl http://localhost:8873/healthz

# 浏览器访问
# http://localhost:8873
```

### 3. 测试搜索

```bash
# 使用 API 搜索
curl -s "http://localhost:8873/search?q=hello+world&format=json" | jq .
```

---

## 配置说明

### settings.yml 结构

```yaml
# 使用默认设置，只覆盖需要修改的部分
use_default_settings: true

general:
  instance_name: "SearXNG"

server:
  secret_key: "searxng-secret-key"

outgoing:
  proxies:
    http: "http://host.containers.internal:7890"
    https: "http://host.containers.internal:7890"
  verify_ssl: true

engines:
  # 启用的搜索引擎
  - name: google
    enabled: true
  - name: bing
    enabled: true
  # 禁用的搜索引擎
  - name: ahmia
    engine: ahmia
    inactive: true
```

### 搜索引擎分类

| 类别 | 引擎 |
|------|------|
| 通用搜索 | google, bing, duckduckgo |
| 图片搜索 | google images |
| 知识库 | wikipedia |
| 代码 | github |

### 禁用引擎

以下引擎默认禁用：

- `ahmia` - 暗网搜索（需要 Tor）
- `torch` - 引擎文件不存在

---

## 常用命令

### 使用脚本
```bash
# 启动
./scripts/searxng.sh up

# 停止
./scripts/searxng.sh down

# 重启
./scripts/searxng.sh restart

# 查看日志
./scripts/searxng.sh logs

# 查看状态
./scripts/searxng.sh status
```

### 使用 Makefile
```bash
# 仓库根目录执行
make searxng-up
make searxng-down
make searxng-restart
```

---

## API 使用

### 搜索 API

```bash
# JSON 格式
curl -s "http://localhost:8873/search?q=<query>&format=json"

# 指定类别
curl -s "http://localhost:8873/search?q=<query>&categories=general&format=json"

# 指定语言
curl -s "http://localhost:8873/search?q=<query>&language=zh-CN&format=json"
```

### 搜索参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `q` | 搜索关键词 | `hello+world` |
| `format` | 输出格式 | `json`, `html` |
| `categories` | 搜索类别 | `general`, `images`, `news` |
| `language` | 语言 | `zh-CN`, `en` |
| `pageno` | 页码 | `1`, `2` |

### 自动补全 API

```bash
curl -s "http://localhost:8873/autocomplete?q=hello"
```

---

## 客户端接入

### SearXNG MCP Service

本仓库提供了 `tools/search/searxng-mcp/`，这是一个基于 FastMCP 的 MCP 服务：

```bash
# 启动 MCP 服务
cd tools/search/searxng-mcp
make run

# 在 Claude Code 中配置 MCP server
# 参见 ../../searxng-mcp/README.md
```

### Python 示例

```python
import requests

SEARXNG_BASE_URL = "http://localhost:8873"

def search(query, category="general", max_results=10):
    response = requests.get(
        f"{SEARXNG_BASE_URL}/search",
        params={"q": query, "format": "json", "categories": category}
    )
    results = response.json().get("results", [])[:max_results]
    return results
```

---

## 架构说明

```
┌──────────────┐     ┌──────────────┐     ┌─────────────────┐
│   客户端      │ ──► │   SearXNG    │ ──► │  上游搜索引擎     │
│ (MCP/HTTP)   │     │  (端口 8873)  │     │ (Google/Bing/...) │
└──────────────┘     └──────────────┘     └─────────────────┘
                              │
                              │ (可选代理)
                              ▼
                    ┌─────────────────┐
                    │  代理服务器      │
                    │ (host:7890)     │
                    └─────────────────┘
```

---

## 故障排查

**快速诊断命令：**

```bash
# 1. 检查容器状态
docker compose -f compose/docker-compose.yml ps

# 2. 查看日志
docker compose -f compose/docker-compose.yml logs --tail 50

# 3. 验证健康端点
curl http://localhost:8873/healthz

# 4. 检查端口监听
lsof -i :8873
```

**常见问题：**

1. **容器启动失败**：检查 settings.yml 语法是否正确
2. **搜索无结果**：检查 outgoing.proxies 配置，可能需要代理
3. **某些引擎失败**：查看日志中具体引擎的错误信息

---

## 修改配置

1. 编辑 `settings/settings.yml`
2. 重启服务：`./scripts/searxng.sh restart`

---

## 完成定义

满足以下**全部条件**时，可判定 SearXNG 已可使用：

1. ✅ `docker compose up -d` 无错误，容器状态为 Up
2. ✅ `http://localhost:8873` 可访问
3. ✅ `/healthz` 返回 200
4. ✅ `/search?q=test&format=json` 返回有效结果
5. ✅ 文档完整（README + settings.yml）

---

## 迁移说明

本配置从以下外部目录迁移而来：

- **来源**：`/Users/zhehan/Documents/tools/dotfiles/web-tools/searxng`
- **目标**：`tools/search/searxng/`
- **改动**：
  - 调整了 compose 文件中的挂载路径为相对路径
  - 新增 scripts/searxng.sh 简化本地操作
  - 结构调整：settings/、compose/、env/、scripts/ 分离
