# Crawl4AI MCP Service (占位)

> **定位**：基于 FastMCP 的网页内容提取服务
> **状态**：⏳ 预留位置
> **职责**：为 Claude Code 提供网页抓取和内容提取工具

---

## 目录结构（计划）

```
tools/crawl/crawl4ai-mcp/
├── README.md           # 本文件
├── pyproject.toml      # Python 项目配置
├── src/
│   ├── server.py       # FastMCP server
│   ├── client.py       # Crawl4AI 客户端
│   └── schema.py       # 输入/输出模型
├── tests/
├── compose/
├── scripts/
└── env/
```

---

## 计划功能

### 核心工具

| 工具 | 描述 |
|------|------|
| `fetch_url` | 抓取指定 URL，返回清理后的内容 |
| `extract_structured` | 按 schema 提取结构化数据 |

### fetch_url（计划）

**输入：**
- `url`: string，必填
- `wait`: integer，可选，默认 0（等待时间，秒）
- `screenshot`: boolean，可选，默认 false

**输出：**
```json
{
  "url": "https://example.com",
  "title": "Page Title",
  "content": "Cleaned text content...",
  "links": ["..."],
  "status": 200
}
```

---

## 与 searxng-mcp 的关系

| 服务 | 职责 | 运行依赖 |
|------|------|----------|
| `searxng-mcp` | 搜索 web，发现 URL | SearXNG 服务 |
| `crawl4ai-mcp` | 抓取 URL，提取内容 | Crawl4AI 服务（浏览器） |

---

## 实现计划

1. **Phase 1**: Crawl4AI 服务配置（`tools/crawl/crawl4ai/`）
2. **Phase 2**: MCP 服务框架（`tools/crawl/crawl4ai-mcp/`）
3. **Phase 3**: 与 searxng-mcp 协同

---

## 参考

- `tools/search/searxng-mcp/` - MCP 服务参考实现
- `runtimes/fastmcp/templates/python/` - FastMCP 模板
