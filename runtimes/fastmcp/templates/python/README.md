# FastMCP Python 模板

> 用于快速创建新的 MCP 服务

---

## 目录结构

```
<name>-mcp/
├── README.md
├── pyproject.toml
├── src/
│   ├── __init__.py
│   ├── server.py
│   ├── client.py
│   └── schema.py
├── tests/
│   └── test_server.py
├── compose/
│   └── docker-compose.yml
├── scripts/
│   └── run.sh
└── env/
    └── .env.example
```

---

## 快速开始

### 1. 初始化项目

```bash
# 从模板复制
cp -r ../../runtimes/fastmcp/templates/python/* /path/to/new-mcp/

# 修改 pyproject.toml
# 修改 src/server.py 中的服务名称
```

### 2. 实现工具

编辑 `src/server.py`：

```python
from fastmcp import FastMCP

mcp = FastMCP("my-service")

@mcp.tool()
def my_tool(query: str) -> dict:
    """工具描述"""
    return {"result": query}

if __name__ == "__main__":
    mcp.run()
```

### 3. 运行服务

```bash
# 本地开发
uv run python src/server.py

# Streamable HTTP 模式
uv run python -m fastmcp.server src/server.py --transport streamable-http --port 8888
```

---

## 模板说明

### pyproject.toml

```toml
[project]
name = "<name>-mcp"
version = "0.1.0"
description = "MCP service for <name>"
requires-python = ">=3.10"
dependencies = [
    "fastmcp>=0.2.0",
    "httpx>=0.25.0",
    "pydantic>=2.0.0",
]
```

### server.py

FastMCP server 定义，职责：
- 初始化 FastMCP 实例
- 注册工具函数
- 启动服务

### client.py

外部 API 客户端，职责：
- HTTP 请求封装
- 错误处理
- 重试逻辑

### schema.py

数据模型定义，职责：
- 输入模型（Pydantic）
- 输出模型
- 验证逻辑

---

## 最佳实践

1. **职责分离**：server 只注册工具，client 负责调用，schema 负责验证
2. **轻量标准化**：对上游返回做轻量标准化，不透传全部字段
3. **错误可读**：提供清晰的错误信息
4. **边界控制**：对输入参数做验证

---

## 参考

- `tools/search/searxng-mcp/` - 完整示例
- `runtimes/fastmcp/README.md` - Runtime 说明
