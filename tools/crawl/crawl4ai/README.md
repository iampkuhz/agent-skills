# Crawl4AI Service (占位)

> **定位**：Web 内容抓取和提取服务
> **状态**：⏳ 预留位置
> **职责**：与 `crawl4ai-mcp/` 分离，本目录仅包含 Crawl4AI 服务本体

---

## 目录结构（计划）

```
tools/crawl/crawl4ai/
├── README.md           # 本文件
├── config/             # Crawl4AI 配置
├── compose/            # Docker Compose 配置
├── scripts/            # 启动/停止脚本
└── env/                # 环境变量
```

---

## 职责说明

### crawl4ai/（本目录）

- Crawl4AI 服务本体
- 浏览器自动化配置
- 网页抓取规则
- 内容提取模板

### crawl4ai-mcp/

- 基于 FastMCP 的 MCP 服务封装
- 供 Claude Code 使用的工具接口
- 轻量标准化输出

---

## 与 searxng-mcp 的职责差异

| 服务 | 职责 | 输入 | 输出 |
|------|------|------|------|
| `searxng-mcp` | **搜索** - 发现相关 URL | 搜索关键词 | URL 列表 + 摘要 |
| `crawl4ai-mcp` | **提取** - 抓取页面内容 | 具体 URL | 页面正文/结构化数据 |

**协同使用示例：**

```
1. 使用 searxng-mcp 搜索 "Python 异步编程教程"
   → 返回 10 个相关 URL

2. 选择最有价值的 URL

3. 使用 crawl4ai-mcp 提取该 URL 的完整内容
   → 返回清理后的正文、代码块、链接等
```

---

## 未来功能（TODO）

- [ ] Crawl4AI 服务配置
- [ ] Docker Compose 编排
- [ ] crawl4ai-mcp 实现
- [ ] 与 searxng-mcp 的协同示例

---

## 参考

- [Crawl4AI GitHub](https://github.com/unclecode/crawl4ai)
- `tools/search/searxng/` - 搜索引擎参考
- `tools/search/searxng-mcp/` - MCP 服务参考
- `runtimes/fastmcp/` - FastMCP runtime
