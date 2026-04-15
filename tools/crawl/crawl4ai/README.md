# Crawl4AI Service

> **定位**：Web 内容抓取和提取服务
> **服务地址**：http://localhost:11235

---

## 快速开始

### 前置条件

```bash
# 使用 Docker（推荐）
docker pull unclecode/crawl4ai:latest
```

### 运行服务

```bash
# 进入服务目录
cd tools/crawl/crawl4ai

# 复制环境变量文件
cp ../env/.env.example ../env/.env

# 启动服务
podman compose -f compose/docker-compose.yml up -d
# 或 docker compose up -d
```

说明：`compose/docker-compose.yml` 已固定 Compose 项目名为 `crawl4ai`，即使在 `compose/` 子目录下直接启动，也不会与仓库里其它服务共享默认的 `compose` 项目名。

### 验证服务

```bash
# 健康检查
curl http://localhost:11235/health

# 测试抓取功能
curl -X POST http://localhost:11235/crawl \
  -H "Content-Type: application/json" \
  -d '{"urls":["https://example.com"]}' | jq .

# 使用测试脚本（推荐）
cd scripts
chmod +x test_crawl4ai_mcp.sh
./test_crawl4ai_mcp.sh md https://example.com
./test_crawl4ai_mcp.sh html https://example.com
./test_crawl4ai_mcp.sh screenshot https://example.com
```

---

## 测试脚本

Crawl4AI 提供了一套测试脚本，方便快速验证服务功能。

### 用法

```bash
cd scripts
chmod +x test_crawl4ai_mcp.sh

# 用法：./test_crawl4ai_mcp.sh [操作] [URL]

# 提取 Markdown
./test_crawl4ai_mcp.sh md https://example.com

# 提取 HTML
./test_crawl4ai_mcp.sh html https://example.com

# 截取截图
./test_crawl4ai_mcp.sh screenshot https://example.com

# 生成 PDF
./test_crawl4ai_mcp.sh pdf https://example.com
```

### 输出示例

```
╔════════════════════════════════════════╗
║     Crawl4AI 测试脚本                  ║
╚════════════════════════════════════════╝

服务地址：http://localhost:11235
操作：md
目标 URL: https://example.com

Step 1: 健康检查
健康状态：{"status":"ok","version":"0.8.6"}

Step 2: 抓取页面
=== 结果 ===
URL: https://example.com
状态码：200

--- Markdown 内容 ---
# Example Domain
This domain is for use in documentation examples...

--- 外部链接 (1 个) ---
  - Learn more: https://iana.org/domains/example

--- 性能 ---
服务器处理时间：0.38 秒
```

---

## MCP 服务配置

Crawl4AI 自带 MCP (Model Context Protocol) 服务，可直接在 Claude Code 中使用。

### 可用工具

| 工具 | 描述 |
|------|------|
| `md` | 将网页转换为 Markdown 格式 |
| `html` | 抓取并清理 HTML 内容 |
| `screenshot` | 截取网页截图（PNG） |
| `pdf` | 生成网页 PDF 文档 |
| `execute_js` | 执行 JavaScript 脚本 |
| `crawl` | 批量抓取多个 URL |
| `ask` | 查询 Crawl4AI 相关文档 |

### 配置方法

在项目目录的 `.mcp.json` 中添加：

```json
{
  "mcpServers": {
    "crawl4ai": {
      "type": "sse",
      "url": "http://localhost:11235/mcp/sse"
    }
  }
}
```

### 使用示例

在 Claude Code 中直接使用：

```
/md https://example.com
```

```
/screenshot https://example.com --output_path ./screenshot.png
```

```
/crawl --urls ["https://example.com", "https://example.org"]
```

---

## 目录结构

```
tools/crawl/crawl4ai/
├── README.md               # 本文件
├── compose/                # Docker Compose 配置
│   └── docker-compose.yml
├── scripts/                # 测试脚本
│   ├── crawl4ai.sh         # 服务管理脚本（占位）
│   └── test_crawl4ai_mcp.sh  # 测试脚本（支持 md/html/screenshot/pdf）
└── env/                    # 环境变量
    └── .env.example
```

---

## 与 searxng-mcp 的协同

| 服务 | 职责 | 输入 | 输出 |
|------|------|------|------|
| `searxng-mcp` | **搜索** - 发现相关 URL | 搜索关键词 | URL 列表 + 摘要 |
| `crawl4ai` (MCP) | **提取** - 抓取页面内容 | 具体 URL | Markdown/HTML/截图等 |

**协同使用示例：**

```
1. 使用 searxng-mcp 搜索 "Python 异步编程教程"
   → 返回 10 个相关 URL

2. 选择最有价值的 URL

3. 使用 crawl4ai MCP 工具提取内容
   /md https://example.com/tutorial
   → 返回清理后的 Markdown 内容
```

---

## 参考

- [Crawl4AI GitHub](https://github.com/unclecode/crawl4ai)
- [Crawl4AI 官方文档](https://docs.crawl4ai.com/)
- `tools/search/searxng/` - 搜索引擎参考
- `tools/search/searxng-mcp/` - MCP 服务参考
