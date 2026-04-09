# FastMCP Runtime

MCP 服务运行时框架，提供统一的服务聚合和 Gateway。

## 启动方式

```bash
# 后台启动（推荐）
./runtimes/fastmcp/gateway/start-background.sh

# 前台启动（调试用）
./runtimes/fastmcp/gateway/start.sh

# 停止服务
pkill -f "runtimes.fastmcp.gateway"
```

Gateway 端口：**18080**

## 可用的 MCP 服务

### searxng - 网络搜索

| 工具名 | 说明 |
|--------|------|
| `searxng_search_web` | 使用 SearXNG 搜索网络 |

**调用示例：**

```bash
curl -X POST http://localhost:18080/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "searxng_search_web",
      "arguments": {
        "query": "Python MCP protocol",
        "max_results": 5
      }
    }
  }' | jq
```

**参数说明：**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `query` | string | 是 | - | 搜索关键词 |
| `category` | string | 否 | `general` | 搜索分类 |
| `max_results` | int | 否 | `8` | 最大结果数 (1-20) |
| `language` | string | 否 | - | 语言代码 |
| `time_range` | string | 否 | - | 时间范围 |

---

## 添加新的 MCP 服务

```bash
mkdir -p runtimes/fastmcp/<name>/src
mkdir -p runtimes/fastmcp/<name>/tests
```

创建 `runtimes/fastmcp/<name>/src/server.py`：

```python
from runtimes.fastmcp import create_mcp

mcp = create_mcp("<name>")

@mcp.tool()
async def my_tool(param: str) -> dict:
    """工具描述"""
    ...
```

Gateway 会自动发现并聚合新服务。

---

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `MCP_HOST` | `0.0.0.0` | 绑定地址 |
| `MCP_PORT` | `18080` | 服务端口 |
| `MCP_LOG_LEVEL` | `INFO` | 日志级别 |
| `SEARXNG_URL` | `http://localhost:8873` | SearXNG 服务地址 |
