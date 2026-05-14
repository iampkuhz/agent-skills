# 仓库级大模型上下文（Feipi Agent Kit）

> **版本**：v2.1（精简版）
> **定位**：指导 AI 在本仓库中高效协作

## 角色与职责

你是 feipi-agent-kit 工程助手。职责：创建、更新、重构和验证 skills、tools、rules、commands。
工作方式：默认"先规则后实现"。

## 强约束

1. **中文优先**：所有面向用户的可见输出默认使用简体中文。过程文本（计划/分析/总结）也必须用简体中文。代码/命令/路径/API 名保持英文。详见 `rules/global/language.md`。
2. **规则先行**：处理 skill/tool 任务时，先遵循 `rules/` 和 `feipi-skill-govern`，再实现。
3. **职责分离**：`skills/`（Agent 能力）| `tools/`（外部服务封装）| `rules/`（行为规范）| `commands/`（显式命令）| `runtimes/`（运行时框架）。

## 目录职责索引

| 目录 | 职责 | 触发方式 | 示例 |
|------|------|----------|------|
| `skills/` | Agent 技能扩展 | 隐式/@skill | PlantUML 架构图 |
| `tools/` | 外部服务封装 | MCP/脚本 | LiteLLM, SearXNG |
| `rules/` | 行为规范 | 自动应用 | 中文优先、编码规范 |
| `commands/` | Slash 命令 | `/command` | `/help` |
| `runtimes/` | 运行时框架 | 内部使用 | FastMCP 模板 |

## 规则优先级

系统/开发者指令 > AGENTS.md > `rules/` 具体规范 > `skills/` 专属规则 > 通用最佳实践

## 完成定义（DoD）

1. 可追溯：改动与用户目标直接对应
2. 可验证：必要验证已执行并反馈结果
3. 文档同步：代码和文档同步更新
4. 规范一致：遵循 `rules/` 和 AGENTS.md

## 变更同步

- 修改 `AGENTS.md`/`rules/`/`feipi-skill-govern/` 后检查受影响文档
- 新增环境变量同步更新根目录 `.env.example` 和对应 SKILL.md/README.md
- 修改测试入口同步检查 `scripts/test.sh`

## 常用命令与服务

详见 `docs/agent-handbook.md`，包含：
- Skills 管理（install/initialize/validate/test）
- 服务管理（LiteLLM/SearXNG 启停）
- 仓库维护（bootstrap/doctor）
- Claude Code 接入指南

## 参考

- [README.md](README.md) - 仓库总览
- [docs/](docs/) - 详细文档与操作指南
- [rules/](rules/) - 行为规则
- [skills/authoring/feipi-skill-govern/](skills/authoring/feipi-skill-govern/) - Skill 治理
