# FastMCP 架构说明

## 架构概述

FastMCP 采用**单端口聚合网关**架构：

```
                    ┌─────────────────────────────────┐
                    │   FastMCP Gateway (18080)       │
                    │                                 │
┌──────────        │   /mcp              (统一入口)   │
│  Client  │───────▶│                                 │
└──────────        └─────────────────────────────────┘
                            │
                    ┌───────┴────────┐
                    │   mount() 聚合  │
                ┌───┴───┐      ┌──────┴──────┐
                │searxng│      │future-svc   │
                └───────┘      └─────────────┘
```

## 访问方式

| 端点 | 说明 |
|------|------|
| `http://localhost:18080/mcp` | 统一 MCP 端点（所有服务） |

## 工具命名规范

所有工具使用 `{service}_{tool_name}` 格式：

- `searxng_search_web`
- `searxng_search_images`
- `future_svc_some_tool`

## 启动方式

```bash
# 启动网关
./runtimes/fastmcp/gateway/start-background.sh

# 测试服务
./runtimes/fastmcp/scripts/test_searxng_mcp.sh

# 查看日志
tail -f runtimes/fastmcp/logs/gateway.log

# 停止服务
pkill -f "runtimes.fastmcp.gateway"
```

## 添加新服务

1. 创建服务目录：
```
runtimes/fastmcp/my-service/
└── src/
    └── server.py
```

2. 在 `server.py` 中定义 MCP 服务：
```python
from runtimes.fastmcp import create_mcp

mcp = create_mcp("my-service")

@mcp.tool()
def my_tool(x: int) -> str:
    return f"Result: {x}"
```

3. 重启网关，服务会自动发现并加载。

## 目录结构

```
runtimes/fastmcp/
├── gateway/               # 聚合网关（不存放具体服务）
│   ├── server.py          # 网关入口
│   ├── start-background.sh # 启动脚本
│   └── __init__.py
├── scripts/               # 工具脚本
│   ├── test_searxng_mcp.sh # 测试 searxng 服务
│   └── README.md
├── searxng/               # SearXNG 服务
│   ├── src/
│   │   ├── server.py      # MCP 服务定义
│   │   ├── searxng_client.py
│   │   └── schemas.py
│   └── tests/
├── shared/                # 共享模块
│   ├── config.py
│   └── common.py
├── templates/             # 服务模板
├── logs/                  # 日志目录（自动生成）
├── ARCHITECTURE.md        # 本文档
└── runtime.py             # FastMCP 运行时工具
```

## 配置

通过环境变量配置：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `MCP_HOST` | 0.0.0.0 | 监听地址 |
| `MCP_PORT` | 18080 | 监听端口 |
| `MCP_LOG_LEVEL` | INFO | 日志级别 |
| `SEARXNG_URL` | http://localhost:8873 | SearXNG 服务地址 |

## 设计原则

1. **单一入口** - 所有服务通过一个端点访问
2. **自动发现** - 新服务自动加载，无需手动配置
3. **命名隔离** - 通过 namespace 前缀区分服务
4. **简单优先** - 本地开发友好，运维简单
