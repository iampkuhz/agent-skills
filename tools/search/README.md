# Search Tools

SearXNG 搜索服务的基础设施配置（Docker Compose）。

## 快速开始

### 1. 启动 SearXNG

```bash
podman compose -f tools/search/searxng/compose/docker-compose.yml up -d
```

### 2. 启动 FastMCP Gateway

```bash
# 后台启动
./runtimes/fastmcp/gateway/start-background.sh

# 或前台启动
./runtimes/fastmcp/gateway/start.sh
```

### 3. 测试搜索

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

## 文件说明

| 文件 | 说明 |
|------|------|
| `tools/search/searxng/compose/` | SearXNG Docker 配置 |
| `runtimes/fastmcp/searxng/` | MCP 服务实现 |
| `runtimes/fastmcp/gateway/` | 统一网关入口 |
