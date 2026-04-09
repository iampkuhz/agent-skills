# 从旧 skills-centric 结构继续迁移的建议路径

> 本文档指导如何从旧的 skills-centric 结构渐进迁移到新的 agent-tools 结构

---

## 当前状态（v0.1.0）

### 已完成

- [x] 新目录结构创建（tools/, rules/, commands/, runtimes/）
- [x] LiteLLM 迁移到 `tools/gateway/litellm/`
- [x] SearXNG 迁移到 `tools/search/searxng/`
- [x] SearXNG MCP 创建于 `tools/search/searxng-mcp/`
- [x] FastMCP Runtime 创建于 `runtimes/fastmcp/`
- [x] README.md 和 AGENTS.md 更新
- [x] Makefile 更新

### 保留的旧结构

- [x] `skills/` - 继续保留为一级目录
- [x] `.claude/` - 保留（用于快速链接）
- [x] `.codex/` - 保留（用于快速链接）
- [x] `scripts/install_skills.sh` - 保留（安装脚本）

---

## Phase 1: 稳定新结构（当前阶段）

### 目标

确保新创建的服务和结构可以正常运行

### 任务

1. **验证服务运行**
   - `make searxng-up` 可正常启动
   - `make litellm-up` 可正常启动
   - `make searxng-mcp-run` 可正常运行

2. **验证 MCP 集成**
   - 在 Claude Code 中配置 MCP server
   - 测试 `search_web` 工具

3. **文档完善**
   - 确保所有服务 README 完整
   - 更新验证指南

### 验收标准

- 所有服务可正常启动
- SearXNG MCP 可在 Claude Code 中使用
- 文档无明显缺失

---

## Phase 2: Rules 充实

### 目标

将现有规则从 AGENTS.md 和 skills 文档中抽取到独立的 rules/ 目录

### 任务

1. **Global Rules**
   - 创建 `rules/global/language.md` - 中文优先规则
   - 创建 `rules/global/security.md` - 安全约束

2. **Coding Rules**
   - 创建 `rules/coding/python.md` - Python 编码规范
   - 创建 `rules/coding/testing.md` - 测试规范
   - 创建 `rules/coding/commits.md` - Git 提交规范

3. **Diagram Rules**
   - 创建 `rules/diagram/plantuml.md` - PlantUML 规范
   - 创建 `rules/diagram/naming.md` - 命名约定
   - 创建 `rules/diagram/review-checklist.md` - 审查清单

4. **Review Rules**
   - 创建 `rules/review/checklist.md` - 审查清单
   - 创建 `rules/review/security.md` - 安全审查

### 验收标准

- 每条规则有清晰的适用场景
- 规则与 AGENTS.md 不冲突
- 规则可被 AI 自动应用

---

## Phase 3: Commands 整理

### 目标

将 .claude/commands/ 和 .codex/commands/ 中的命令整理到统一的 commands/ 目录

### 任务

1. **审计现有 Commands**
   - 列出 .claude/commands/ 中的所有命令
   - 列出 .codex/commands/ 中的所有命令
   - 识别重复和冲突

2. **分类迁移**
   - 通用命令 → `commands/shared/`
   - Claude Code 专属 → `commands/claude/`
   - Codex 专属 → `commands/codex/`

3. **更新链接**
   - 更新 .claude/settings.local.json 中的引用
   - 更新 .codex/ 中的引用

### 验收标准

- 所有命令有唯一来源
- 通用命令在 shared/ 中
- 客户端专属命令在对应目录中

---

## Phase 4: Skills 规范化

### 目标

确保所有 skills 遵循统一的 v2 规范

### 任务

1. **检查现有 Skills**
   - 使用 `feipi-skill-govern` 检查每个 skill
   - 记录不符合 v2 规范的技能

2. **逐步重构**
   - 按优先级重构技能
   - 确保测试通过

3. **文档更新**
   - 更新 skills/README.md
   - 确保每个技能有独立的 README

### 验收标准

- 所有技能通过 `feipi-skill-govern` 校验
- 测试可正常执行
- 文档完整

---

## Phase 5: Crawl4AI 接入

### 目标

完成 Crawl4AI 服务和 MCP 封装

### 任务

1. **Crawl4AI 服务配置**
   - 创建 `tools/crawl/crawl4ai/` 配置
   - 编写 docker-compose.yml
   - 配置浏览器环境

2. **Crawl4AI MCP 封装**
   - 从 `runtimes/fastmcp/templates/python/` 复制模板
   - 实现 `fetch_url` 工具
   - 编写测试

3. **与 SearXNG MCP 协同**
   - 编写协同使用示例
   - 更新文档

### 验收标准

- Crawl4AI 服务可正常启动
- `fetch_url` 工具可正常使用
- 与 searxng-mcp 协同工作

---

## Phase 6: 自动化测试

### 目标

添加 CI/CD 自动化测试

### 任务

1. **单元测试**
   - MCP 服务单元测试
   - 共享库单元测试

2. **集成测试**
   - 服务启动测试
   - MCP 工具调用测试

3. **CI/CD 配置**
   - GitHub Actions 配置
   - 自动验证 PR

### 验收标准

- PR 自动触发测试
- 测试覆盖率 > 80%
- 失败测试阻塞合并

---

## 迁移检查清单

### 每次迁移后检查

- [ ] 服务可正常启动
- [ ] 文档已同步更新
- [ ] 测试已通过
- [ ] 环境变量已更新
- [ ] Makefile 已更新（如需要）

### 迁移完成后检查

- [ ] 所有 Phase 任务完成
- [ ] 验证指南中所有检查通过
- [ ] 文档无矛盾或过时内容
- [ ] 团队成员了解新结构

---

## 回滚策略

如果迁移过程中遇到问题：

1. **Git 回滚**
   ```bash
   git checkout <previous-tag>
   ```

2. **部分回滚**
   ```bash
   # 恢复特定目录
   git checkout HEAD~1 -- tools/search/searxng/
   ```

3. **配置回滚**
   ```bash
   # 使用外部目录配置
   # （如果有备份）
   ```

---

## 参考

- [docs/verification/README.md](verification/README.md) - 验证指南
- [docs/migration/README.md](migration/README.md) - 迁移说明
- [README.md](../README.md) - 仓库总览
