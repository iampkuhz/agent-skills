---
name: feipi-gen-skills
description: 用于创建或更新 Codex/Claude 风格 skills 的中文高质量工作流。在新建 skill、重构已有 skill、补充 scripts/references/assets、完善触发描述、建立验证闭环、或控制长会话上下文成本时使用。
---

# Skill Creator（中文）

## 核心目标

以最小上下文成本，产出可发现、可执行、可验证、可迭代的高质量 skills。

## 目录标准

每个 skill 推荐结构：

```txt
<skill-name>/
├── SKILL.md
├── agents/openai.yaml
├── scripts/
├── references/
└── assets/
```

说明：
- `SKILL.md`：唯一必需文件，定义触发与执行规则。
- `agents/openai.yaml`：UI 元数据（展示名、短描述、默认提示词）。
- `scripts/`：确定性、可重复执行的脚本。
- `references/`：按需加载的详细资料。
- `assets/`：输出时使用的模板或静态文件。

## 强约束原则

1. 简洁优先
- SKILL.md 只保留高价值信息；默认假设模型已具备通用知识。
- 正文建议 <= 500 行；超出即拆分到 `references/`。

2. 验证优先
- 先定义验收标准，再实现内容。
- 无可执行验证证据视为未完成。

3. 自由度匹配风险
- 高自由度：多方案均可行的分析类任务。
- 中自由度：有推荐模式、可参数化任务。
- 低自由度：高风险、易错、必须按序执行任务。

4. 渐进式披露
- SKILL.md 提供导航与流程。
- 细节放 `references/` 并由 SKILL.md 直接一跳链接。
- 避免多层嵌套引用。

5. 中文维护
- 面向维护者字段使用中文：`description`、正文、`agents/openai.yaml` 关键字段。

## Frontmatter 规范

1. 仅保留 `name` 与 `description`。
2. `name`：
- 与目录名一致。
- 匹配 `^[a-z0-9-]{1,64}$`。
- 不含保留词 `anthropic`、`claude`。
- 不含 XML 标签。
3. `description`：
- 非空，<= 1024 字符。
- 使用第三人称，写清“做什么 + 什么时候用”。
- 不含 XML 标签。

## 命名规范

强制格式：`feipi-<action>-<target...>`。
- 示例：`feipi-coding-react-components`、`feipi-gen-api-tests`、`feipi-read-video-transcript`
- `action` 必须来自标准动作字典
- 详细规则见：`references/naming-conventions.md`

## 四阶段工作流（Explore -> Plan -> Implement -> Verify）

1. Explore（探索）
- 收集任务目标、输入输出、边界与风险。
- 只读必要文件；先索引后定向打开。

2. Plan（规划）
- 明确改动文件、理由、验证方法。
- 变更可一句话描述 diff 时可直做，不做重规划。

3. Implement（实现）
- 先落可复用资源（脚本/参考/资产），再完善 SKILL.md。
- 对确定性操作优先写脚本并执行脚本，而不是临时重写代码。
- 避免 Windows 路径，统一正斜杠。

4. Verify（验证）
- 运行仓库校验：`make validate DIR=skills/<name>`。
- 执行至少一种任务级验证（测试、命令、截图比对、结构校验）。
- 交付必须给出：验证步骤、结果、剩余风险。

## 反馈循环

默认采用循环：验证 -> 修复 -> 再验证。

若任务高风险（批量改动、破坏性操作、复杂规则）：
1. 先生成中间计划文件（如 `changes.json`）。
2. 用脚本校验计划。
3. 通过后再执行变更。

## 反模式与修复

1. 说明冗长且重复常识
- 修复：删解释，保留流程、约束、命令与示例。

2. 给太多并列方案导致选择困难
- 修复：给一个默认方案 + 一个例外逃生舱。

3. 只给规则，不给验证
- 修复：补充可执行验证步骤与通过条件。

4. 路径/目录组织混乱
- 修复：用语义化文件名，按领域拆分 `references/`。

## 测试与迭代要求

1. 至少准备 3 个评估场景（正常、边界、异常）。
2. 优先真实任务回放，不只做静态阅读。
3. 若目标环境涉及多模型，至少在预期模型档位做一次对照测试。
4. 根据观察到的失败行为迭代，不基于猜测优化。

## 交付清单

每次创建/更新 skill 前，复制并打勾：

```txt
技能质量清单
- [ ] frontmatter 合规（name/description）
- [ ] description 清晰说明能力与触发时机
- [ ] SKILL.md 正文 <= 500 行
- [ ] 已提供验证步骤与通过标准
- [ ] 已运行 make validate
- [ ] 文件引用均为一级深链接
- [ ] 无 Windows 风格路径
- [ ] 术语一致，示例可执行
```
