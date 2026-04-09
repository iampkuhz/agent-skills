# FastMCP Runtime

> **定位**：本仓库的 MCP 服务运行时框架
> **职责**：提供 FastMCP 服务开发模板、共享库和运行约定

---

## 为什么需要单独的 FastMCP Runtime 路径？

FastMCP 在本仓库中作为 **runtime/server framework** 存在，而非某个具体 tool 的隐式依赖。原因如下：

1. **服务化需求**：FastMCP 官方支持 HTTP / Streamable HTTP 服务化运行，需要一个统一的 runtime 层来管理服务的生命周期
2. **复用性**：多个 MCP 服务（searxng-mcp、crawl4ai-mcp 等）需要共享相同的运行约定、模板和公共库
3. **职责分离**：将 runtime 与具体 tool 实现解耦，保持 `tools/*/` 目录的纯粹性
4. **版本管理**：FastMCP 的版本升级、配置变更可以集中管理，不影响具体 tool 的实现

---

## 目录结构

```
runtimes/fastmcp/
├── README.md           # 本文件
├── templates/          # FastMCP 服务模板
│   └── python/         # Python 模板
│       ├── README.md
│       ├── pyproject.toml
│       ├── src/
│       └── tests/
└── shared/             # 共享库和约定
    ├── common.py       # 通用工具函数
    └── config.py       # 配置约定
```

---

## 与 tools/*-mcp 的关系

| 目录 | 职责 | 示例 |
|------|------|------|
| `runtimes/fastmcp/` | 运行时框架、模板、共享库 | 模板、common 工具 |
| `tools/search/searxng-mcp/` | 具体 MCP 服务实现 | SearXNG 搜索工具 |
| `tools/crawl/crawl4ai-mcp/` | 具体 MCP 服务实现 | Crawl4AI 提取工具 |

**关系说明：**
- `tools/*-mcp/` 使用 `runtimes/fastmcp/templates/` 中的模板进行初始化
- `tools/*-mcp/` 可以引用 `runtimes/fastmcp/shared/` 中的共享库
- `runtimes/fastmcp/` 不依赖具体 tool，保持框架中立

---

## FastMCP 模板

### Python 模板（templates/python/）

模板结构：

```
templates/python/
├── README.md           # 模板使用说明
├── pyproject.toml      # Python 项目配置
├── src/
│   ├── __init__.py
│   ├── server.py       # FastMCP server 定义
│   ├── client.py       # 外部 API 客户端
│   └── schema.py       # 输入/输出模型
└── tests/
    └── test_server.py  # 测试用例
```

---

## 创建新的 MCP 服务

### 步骤 1：从模板复制

```bash
cd tools/<category>/<name>-mcp
cp -r ../../runtimes/fastmcp/templates/python/* .
```

### 步骤 2：修改项目配置

编辑 `pyproject.toml`，修改：
- `name` - 项目名称
- `description` - 项目描述
- 依赖项

### 步骤 3：实现 server

编辑 `src/server.py`：
- 导入 FastMCP
- 定义工具函数
- 注册工具

### 步骤 4：实现 client

编辑 `src/client.py`：
- 实现外部 API 调用
- 处理错误和重试

### 步骤 5：定义 schema

编辑 `src/schema.py`：
- 定义输入模型（Pydantic）
- 定义输出模型

### 步骤 6：运行测试

```bash
make test
```

---

## 运行 MCP 服务

### 本地开发模式

```bash
cd tools/<category>/<name>-mcp
uv run python src/server.py
```

### Streamable HTTP 模式

```bash
cd tools/<category>/<name>-mcp
uv run python -m fastmcp.server src/server.py --transport streamable-http --port 8888
```

---

## 共享库（shared/）

### common.py

通用工具函数：
- 日志配置
- 错误处理
- 重试逻辑
- 超时控制

### config.py

配置约定：
- 环境变量读取
- 默认配置
- 配置验证

---

## 最佳实践

### 1. 工具设计原则

- **单一职责**：每个工具只做一件事
- **轻量标准化**：对上游 API 返回做轻量标准化，不透传全部原始字段
- **错误可读**：提供清晰的错误信息
- **边界控制**：对输入参数做边界验证

### 2. 代码组织

```
src/
├── server.py       # MCP 入口，只负责注册工具
├── client.py       # 外部 API 客户端，负责 HTTP 调用
├── schema.py       # 数据模型，负责输入/输出验证
└── config.py       # 配置加载
```

### 3. 错误处理

```python
from fastmcp import FastMCP
from pydantic import BaseModel

mcp = FastMCP("my-service")

@mcp.tool()
def my_tool(query: str) -> dict:
    try:
        # 调用外部 API
        result = await client.search(query)
        return {"status": "success", "data": result}
    except ConnectionError as e:
        return {"status": "error", "message": f"External service unreachable: {e}"}
    except ValueError as e:
        return {"status": "error", "message": f"Invalid response: {e}"}
```

---

## 版本兼容性

| FastMCP 版本 | Python 版本 | 备注 |
|-------------|-------------|------|
| 0.1+ | 3.10+ | 基础功能 |
| 0.2+ | 3.10+ | Streamable HTTP 支持 |

---

## 参考

- [FastMCP 官方文档](https://github.com/jlowin/fastmcp)
- [MCP 协议规范](https://modelcontextprotocol.io/)
- 本仓库内示例：`tools/search/searxng-mcp/`
