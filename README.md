# Agent Tools

> **定位**：Agent 工具链和服务管理平台
> **演进**：从 `agent-skills` 演进而来，新增 tools、rules、commands、runtimes 等核心目录
> **状态**：🔄 重构中

---

## 快速开始

### 安装 Skills

```bash
# 软链接安装到用户级 agent 目录
make install-links

# 或指定 agent
AGENT=claudecode make install-links
```

### 启动服务

```bash
# 启动 SearXNG 搜索服务
make searxng-up

# 启动 LiteLLM 模型网关
make litellm-up

# 启动 SearXNG MCP 服务（Claude Code 使用）
make searxng-mcp-run
```

---

## 目录结构

```
agent-tools/
├── .claude/            # Claude Code 配置
├── .codex/             # Codex 配置
├── commands/           # Slash Commands（统一管理中心）
├── docs/               # 文档
├── libs/               # 共享库
├── rules/              # 行为规则和约束规范
├── runtimes/           # 运行时框架（FastMCP）
├── scripts/            # 仓库级脚本
├── skills/             # Agent Skills（保留）
├── tests/              # 测试
├── tools/              # 外部工具和服务（新增核心）
└── tmp/                # 临时文件
```

### tools/ 详细结构

```
tools/
├── search/             # 搜索服务
│   └── searxng/        # SearXNG 搜索引擎
├── crawl/              # 抓取服务
│   ├── crawl4ai/       # Crawl4AI 服务（占位）
│   └── crawl4ai-mcp/   # Crawl4AI MCP 服务（占位）
└── gateway/            # 模型网关
    └── litellm/        # LiteLLM 代理
```

---

## 核心目录职责

| 目录 | 职责 | 触发方式 | 示例 |
|------|------|----------|------|
| `skills/` | **Agent 技能** - 扩展 AI 能力 | 隐式/显式触发 | PlantUML 生成、专利撰写 |
| `rules/` | **行为规则** - 约束 AI 行为 | 自动应用 | 编码规范、图表规范 |
| `commands/` | **Slash Commands** - 显式命令 | `/command` | `/help`, `/test` |
| `tools/` | **外部服务** - API 封装 | MCP 调用 | SearXNG 搜索、LiteLLM 网关 |
| `runtimes/` | **运行时框架** - 服务化支撑 | 服务启动 | FastMCP 模板、共享库 |

---

## 服务说明

### LiteLLM

**定位**：本地 AI 模型网关，提供统一的 OpenAI 兼容接口

**位置**：`tools/gateway/litellm/`

**启动**：
```bash
make litellm-up
```

**详情**：[tools/gateway/litellm/README.md](tools/gateway/litellm/README.md)

### SearXNG

**定位**：私有化、无追踪的元搜索引擎

**位置**：`tools/search/searxng/`

**启动**：
```bash
make searxng-up
```

**详情**：[tools/search/searxng/README.md](tools/search/searxng/README.md)

### SearXNG MCP（新建）

**定位**：基于 FastMCP 的搜索服务，供 Claude Code 使用

**位置**：`tools/search/searxng-mcp/`

**启动**：
```bash
make searxng-mcp-run
```

**详情**：[tools/search/searxng-mcp/README.md](tools/search/searxng-mcp/README.md)

---

## Skills 列表

当前仓库包含以下 skills：

| Skill | 用途 | 特点 |
|-------|------|------|
| `feipi-skill-govern` | 创建、重构、自检和治理其他 skill | 统一 v2 命名、layer、模板、脚本与验证边界 |
| `feipi-patent-generate-innovation-disclosure` | 把零散创新点整理成专利创新交底书 | 先补齐专利名与使用场景，再协同架构图/时序图 skill |
| `feipi-video-read-url` | 按用户意图统一处理视频 URL | 覆盖 YouTube/Bilibili 的下载、转写、摘要和背景扩展 |
| `feipi-plantuml-generate-architecture-diagram` | 根据 architecture-brief 生成 PlantUML 架构图 | 先校验 brief，再检查命名覆盖、布局和渲染 |
| `feipi-plantuml-generate-sequence-diagram` | 根据 sequence-brief 生成 PlantUML 时序图 | 先校验 brief，再检查参与者覆盖、布局和渲染 |

**详情**：[Skills Overview](skills/)

---

## 为什么从 agent-skills 演进为 agent-tools？

### 背景

最初的 `agent-skills` 仓库只关注 skills 管理，但随着使用深入，发现需要：

1. **服务化需求**：LiteLLM、SearXNG 等服务需要独立管理
2. **MCP 生态**：Model Context Protocol 成为新标准，需要专门的服务框架
3. **规范统一**：rules、commands 需要独立于 skills 管理
4. **复用性**：多个服务共享相同的运行时框架（如 FastMCP）

### 演进目标

| 维度 | agent-skills | agent-tools |
|------|--------------|-------------|
| **范围** | 仅 skills | skills + tools + rules + commands + runtimes |
| **服务** | 无 | LiteLLM、SearXNG、MCP 服务 |
| **规范** | 分散在 AGENTS.md | 独立的 rules/ 目录 |
| **命令** | 分散在 .claude/commands/ | 统一的 commands/ 目录 |

### 为什么保留 skills/？

1. **向后兼容**：现有技能和安装脚本继续有效
2. **职责分离**：skills 是 agent 能力扩展，tools 是外部服务封装
3. **渐进演进**：温和重构，不破坏现有工作流

---

## 环境配置

### 统一环境变量

仓库根目录的 `.env.example` 是所有技能和服务的统一环境变量模板：

```bash
cp .env.example .env
# 编辑 .env 填入真实值
```

### 服务独立环境

每个服务有自己的 env/ 目录：

- `tools/gateway/litellm/env/.env.example`
- `tools/search/searxng/env/.env.example`
- `tools/search/searxng-mcp/env/.env.example`

---

## 常用命令

```bash
# ===== Skills =====
make install-links           # 安装 skills 到用户级目录
make install-project PROJECT=/path/to/project  # 安装到项目目录

# ===== Services =====
make searxng-up              # 启动 SearXNG
make searxng-down            # 停止 SearXNG
make litellm-up              # 启动 LiteLLM
make litellm-down            # 停止 LiteLLM
make searxng-mcp-run         # 运行 SearXNG MCP

# ===== Scripts =====
./scripts/bootstrap/setup.sh # 初始化设置
./scripts/doctor/check.sh    # 健康检查
```

---

## 架构说明

```
┌─────────────────────────────────────────────────────────────┐
│                      Claude Code / Codex                     │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┼───────────┐
         │           │           │
    ┌────▼────┐ ┌────▼────┐ ┌───▼────┐
    │ skills/ │ │commands/│ │rules/  │
    │ (能力)  │ │ (命令)  │ │ (规范)  │
    └─────────┘ └─────────┘ └────────┘
                     │
                     │ MCP
         ┌───────────▼───────────┐
         │    runtimes/fastmcp   │
         │    (运行时框架)        │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │       tools/          │
         │  ┌───────┬───────┐    │
         │  │search │ crawl │    │
         │  └───────┴───────┘    │
         │       └───────┐       │
         │        gateway│       │
         └───────────────┴───────┘
                     │
         ┌───────────▼───────────┐
         │   外部服务/API         │
         │  SearXNG, LiteLLM...  │
         └───────────────────────┘
```

---

## 文档索引

### 核心文档
- [AGENTS.md](AGENTS.md) - Agent 行为指南
- [README.md](README.md) - 本文件

### 目录文档
- [skills/](skills/) - Skills 总览
- [rules/](rules/) - Rules 说明
- [commands/](commands/) - Commands 说明
- [runtimes/fastmcp/](runtimes/fastmcp/) - FastMCP Runtime

### 服务文档
- [tools/gateway/litellm/](tools/gateway/litellm/) - LiteLLM
- [tools/search/searxng/](tools/search/searxng/) - SearXNG
- [tools/search/searxng-mcp/](tools/search/searxng-mcp/) - SearXNG MCP

---

## 验证清单

完成以下条件时，可判定重构已落地：

- [x] `tools/` 目录结构已创建
- [x] LiteLLM 已配置到 `tools/gateway/litellm/`
- [x] SearXNG 已配置到 `tools/search/searxng/`
- [x] `runtimes/fastmcp/` 已创建
- [x] `rules/` 目录已创建
- [x] `commands/` 目录已创建
- [ ] Crawl4AI 服务已配置
- [ ] 所有服务可正常启动

---

---

## 版本

当前版本：v0.1.0（重构中）

**变更日志**：[CHANGELOG.md](CHANGELOG.md)
