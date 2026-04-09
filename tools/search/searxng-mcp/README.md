# SearXNG MCP Service

> **定位**：基于 FastMCP 的 SearXNG 搜索服务，供 Claude Code 使用
> **状态**：🆕 新建
> **运行方式**：HTTP / Streamable HTTP

---

## 目录结构

```
tools/search/searxng-mcp/
├── README.md           # 本文件
├── pyproject.toml      # Python 项目配置
├── src/
│   ├── __init__.py
│   ├── server.py       # FastMCP server
│   ├── client.py       # SearXNG HTTP 客户端
│   ├── schema.py       # 输入/输出数据模型
│   └── config.py       # 配置加载
├── tests/
│   └── test_server.py  # 测试用例
├── compose/
│   └── docker-compose.yml
├── scripts/
│   └── run.sh          # 运行脚本
└── env/
    └── .env.example    # 环境变量模板
```

---

## 快速开始

### 1. 安装依赖

```bash
cd tools/search/searxng-mcp
uv sync
```

### 2. 配置环境变量

```bash
cp env/.env.example env/.env
# 编辑 .env 文件，配置 SearXNG 地址
```

### 3. 运行服务

**Stdio 模式（Claude Code 推荐）**

```bash
# 直接运行
uv run python src/server.py

# 或使用脚本
./scripts/run.sh stdio
```

**Streamable HTTP 模式**

```bash
# 使用 HTTP transport
uv run python -m fastmcp.server src/server.py --transport streamable-http --port 8888

# 或使用脚本
./scripts/run.sh http
```

---

## 可用工具

### search_web

搜索 web 的核心工具。

**输入：**
| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `query` | string | 是 | - | 搜索关键词 |
| `category` | string | 否 | `general` | 搜索类别（general, news, images 等） |
| `max_results` | integer | 否 | `8` | 最大结果数（1-20） |
| `language` | string | 否 | `null` | 语言代码（zh-CN, en 等） |
| `time_range` | string | 否 | `null` | 时间范围（day, week, month, year） |

**输出：**
```json
{
  "query": "Python async",
  "results": [
    {
      "title": "Python Async/Await 教程",
      "url": "https://example.com/tutorial",
      "snippet": "这是一篇关于 Python 异步编程的教程...",
      "engine": "google"
    }
  ],
  "total_returned": 1
}
```

**错误处理：**
- `SearXNG unreachable` - SearXNG 服务不可达
- `Invalid response` - SearXNG 返回无效数据
- `No results` - 搜索无结果

**示例：**
```python
# 基本搜索
search_web("Python best practices")

# 限定类别和数量
search_web("AI news", category="news", max_results=5)

# 限定语言和时间
search_web("机器学习", language="zh-CN", time_range="week")
```

### health_check

检查 SearXNG 服务健康状态。

**输出：**
```json
{
  "healthy": true,
  "service": "searxng-mcp",
  "endpoint": "http://localhost:8873"
}
```

---

## 在 Claude Code 中使用

### 配置 MCP Server

在 Claude Code 的配置文件（`~/.claude/settings.json` 或项目级 `.claude/settings.local.json`）中添加：

```json
{
  "mcpServers": {
    "searxng": {
      "command": "uv",
      "args": ["run", "python"],
      "cwd": "/Users/zhehan/Documents/tools/llm/skills/agent-skills/tools/search/searxng-mcp",
      "env": {
        "SEARXNG_BASE_URL": "http://localhost:8873",
        "SEARXNG_TIMEOUT": "30.0"
      }
    }
  }
}
```

### 使用示例

在 Claude Code 对话中：

```
@searxng 帮我搜索一下 Python 异步编程的最佳实践
```

或直接在提示词中：

```
使用 search_web 工具搜索 "FastMCP tutorial"，返回 5 条结果
```

---

## 配置说明

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SEARXNG_BASE_URL` | `http://localhost:8873` | SearXNG 服务地址 |
| `SEARXNG_TIMEOUT` | `30.0` | HTTP 请求超时（秒） |
| `SEARXNG_MCP_PORT` | `8888` | HTTP 模式下的服务端口 |
| `SEARXNG_MCP_LOG_LEVEL` | `INFO` | 日志级别 |

### 与 SearXNG 服务的关系

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────┐
│  Claude Code  │ ──► │  searxng-mcp    │ ──► │   SearXNG    │
│              │     │  (FastMCP)      │     │  (搜索引擎)   │
└──────────────┘     └─────────────────┘     └──────────────┘
                                              │
                                              │ 聚合调用
                                              ▼
                                    ┌─────────────────┐
                                    │ Google/Bing/... │
                                    └─────────────────┘
```

---

## 开发说明

### 代码职责分离

| 文件 | 职责 |
|------|------|
| `server.py` | FastMCP server 定义，工具注册 |
| `client.py` | SearXNG HTTP API 调用，错误处理 |
| `schema.py` | 输入/输出数据模型（Pydantic） |
| `config.py` | 环境变量读取 |

### 添加新工具

1. 在 `src/server.py` 中定义新工具函数
2. 使用 `@mcp.tool()` 装饰器
3. 定义清晰的输入/输出 schema
4. 在 `tests/test_server.py` 中添加测试

### 运行测试

```bash
# 确保 SearXNG 服务正在运行
cd ../searxng
./scripts/searxng.sh up

# 运行测试
cd ../searxng-mcp
uv run pytest tests/ -v
```

---

## 与 crawl4ai-mcp 的职责差异

| 服务 | 职责 | 适用场景 |
|------|------|----------|
| `searxng-mcp` | **搜索** - 发现相关 URL | "找一下 X 相关的信息" |
| `crawl4ai-mcp` | **提取** - 抓取具体页面内容 | "读取这个 URL 的内容" |

**协同使用示例：**
```
1. 先用 searxng-mcp 搜索 "Python 异步编程教程"
2. 从结果中选择合适的 URL
3. 再用 crawl4ai-mcp 提取页面详细内容
```

---

## 故障排查

### 常见问题

1. **"SearXNG unreachable"**
   - 检查 SearXNG 服务是否运行：`curl http://localhost:8873/healthz`
   - 检查 `SEARXNG_BASE_URL` 环境变量是否正确

2. **返回空结果**
   - 尝试更换搜索关键词
   - 检查 SearXNG 的 engine 配置是否启用

3. **HTTP 超时**
   - 增加 `SEARXNG_TIMEOUT` 值
   - 检查网络连接

---

## 完成定义

满足以下**全部条件**时，可判定 SearXNG MCP 已可使用：

1. ✅ `uv run python src/server.py` 无错误启动
2. ✅ Claude Code 能连接并使用 MCP 服务
3. ✅ `search_web` 返回有效搜索结果
4. ✅ 错误处理清晰可读
5. ✅ 文档完整（README + pyproject.toml + 测试）
