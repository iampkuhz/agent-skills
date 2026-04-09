# 迁移指南：agent-skills → agent-tools

> **版本**: v0.1.0
> **日期**: 2026-04-09

---

## 背景

最初的 `agent-skills` 仓库只关注 skills 管理，但随着使用深入，需要支持：

1. **服务化需求**：LiteLLM、SearXNG 等服务需要独立管理
2. **MCP 生态**：Model Context Protocol 成为新标准，需要专门的服务框架
3. **规范统一**：rules、commands 需要独立于 skills 管理
4. **复用性**：多个服务共享相同的运行时框架（如 FastMCP）

---

## 演进目标

| 维度 | agent-skills | agent-tools |
|------|--------------|-------------|
| **范围** | 仅 skills | skills + tools + rules + commands + runtimes |
| **服务** | 无 | LiteLLM、SearXNG、MCP 服务 |
| **规范** | 分散在 AGENTS.md | 独立的 rules/ 目录 |
| **命令** | 分散在 .claude/commands/ | 统一的 commands/ 目录 |

---

## 目录结构变更

### 新增一级目录

| 目录 | 职责 | 状态 |
|------|------|------|
| `tools/` | 外部服务封装（LiteLLM、SearXNG、MCP 服务） | ✅ 已创建 |
| `rules/` | 行为规则和规范 | ✅ 已创建 |
| `commands/` | Slash Commands 统一管理 | ✅ 已创建 |
| `runtimes/` | 运行时框架（FastMCP） | ✅ 已创建 |

### 保留的一级目录

| 目录 | 职责 | 说明 |
|------|------|------|
| `skills/` | Agent 技能 | 继续保留，向后兼容 |
| `docs/` | 文档 | 继续保留 |
| `libs/` | 共享库 | 继续保留 |
| `scripts/` | 仓库脚本 | 继续保留 |
| `tests/` | 测试 | 继续保留 |

---

## 迁移内容

### 从外部目录迁移

| 来源 | 目标 | 状态 |
|------|------|------|
| `/Users/zhehan/Documents/tools/dotfiles/observability/litellm` | `tools/gateway/litellm/` | ✅ 已迁移 |
| `/Users/zhehan/Documents/tools/dotfiles/web-tools/searxng` | `tools/search/searxng/` | ✅ 已迁移 |

### 新建内容

| 路径 | 描述 | 状态 |
|------|------|------|
| `tools/search/searxng-mcp/` | SearXNG MCP 服务 | ✅ 已创建 |
| `tools/crawl/crawl4ai/` | Crawl4AI 服务（占位） | ✅ 已创建 |
| `tools/crawl/crawl4ai-mcp/` | Crawl4AI MCP 服务（占位） | ✅ 已创建 |
| `runtimes/fastmcp/` | FastMCP Runtime | ✅ 已创建 |
| `rules/` | 规则目录 | ✅ 已创建 |
| `commands/` | Commands 目录 | ✅ 已创建 |

---

## 温和重构原则

本次重构遵循以下原则：

1. **不删除现有内容**：skills/ 继续保留，安装脚本继续有效
2. **渐进演进**：新增目录与现有结构并存
3. **向后兼容**：`make install-links` 等命令继续工作
4. **服务内聚**：每个服务有自己的 compose/、env/、scripts/，不使用全局目录

---

## 从旧结构继续迁移的路径

### Phase 1（已完成）

- [x] 创建 `tools/` 目录结构
- [x] 迁移 LiteLLM 和 SearXNG
- [x] 创建 FastMCP runtime
- [x] 创建 SearXNG MCP 服务
- [x] 创建 `rules/` 和 `commands/` 目录

### Phase 2（进行中）

- [ ] 将 `.claude/commands/` 中的内容迁移到 `commands/claude/`
- [ ] 将 `.codex/commands/` 中的内容迁移到 `commands/codex/`
- [ ] 为 `rules/` 填充具体内容

### Phase 3（计划中）

- [ ] 实现 Crawl4AI 服务
- [ ] 实现 Crawl4AI MCP 服务
- [ ] 创建更多共享 commands
- [ ] 完善文档和示例

---

## 运行说明

### 启动服务

```bash
# SearXNG 搜索引擎
make searxng-up

# LiteLLM 模型网关
make litellm-up

# SearXNG MCP 服务（Claude Code 使用）
make searxng-mcp-run
```

### 验证

```bash
# 健康检查
make doctor

# 测试 SearXNG MCP
make searxng-mcp-test
```

---

## 参考

- [README.md](../README.md) - 仓库总览
- [AGENTS.md](../AGENTS.md) - Agent 行为指南
- [tools/](../tools/) - 工具和服务
- [runtimes/fastmcp/](../runtimes/fastmcp/) - FastMCP Runtime
