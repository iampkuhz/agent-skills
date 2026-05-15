# Feipi Agent Kit

> **版本**：v2.2（瘦身版）
> **定位**：指导 AI 在本仓库中高效协作

## 强约束

1. **中文优先**：所有面向用户的可见输出默认使用简体中文。过程文本（计划/分析/总结）也必须用简体中文。代码/命令/路径/API 名保持英文。详见 `rules/global/language.md`。
2. **规则先行**：处理 skill/tool 任务时，先遵循 `rules/` 和 `feipi-skill-govern`，再实现。
3. **职责分离**：`skills/`（Agent 能力）| `tools/`（外部服务封装）| `rules/`（行为规范）| `runtimes/`（运行时框架）。

## 目录路由

| 目录 | 职责 | 触发方式 |
|------|------|----------|
| `skills/` | Agent 技能扩展 | 隐式/@skill |
| `tools/` | 外部服务封装 | MCP/脚本 |
| `rules/` | 行为规范 | 自动应用 |
| `runtimes/` | 运行时框架 | 内部使用 |

## 工具使用协议

操作文件/搜索/测试前先查阅 `docs/governance/tool-usage.md`，使用低 token 成本的命令组合。禁止一次性 cat 大文件或全量 grep 整个仓库。

## 完成定义（DoD）

1. 可追溯：改动与用户目标直接对应
2. 可验证：必要验证已执行并反馈结果
3. 文档同步：代码和文档同步更新
4. 规范一致：遵循 `rules/` 和 AGENTS.md

## 参考

- [README.md](README.md) - 仓库总览
- [docs/agent-handbook.md](docs/agent-handbook.md) - 操作手册
- [docs/governance/tool-usage.md](docs/governance/tool-usage.md) - 工具使用规范
- [rules/README.md](rules/README.md) - 行为规则
- [skills/authoring/feipi-skill-govern/](skills/authoring/feipi-skill-govern/) - Skill 治理
