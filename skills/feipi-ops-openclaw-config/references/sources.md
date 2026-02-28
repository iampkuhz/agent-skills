# 参考来源（GitHub 高 star）

更新时间：2026-02-28

## 1) openai/skills（10,062 stars）

- 仓库：<https://github.com/openai/skills>
- 星标数据（GitHub API）：<https://api.github.com/repos/openai/skills>
- 参考文件：
  - <https://raw.githubusercontent.com/openai/skills/main/skills/.system/skill-creator/SKILL.md>
  - <https://raw.githubusercontent.com/openai/skills/main/skills/.system/skill-installer/SKILL.md>
  - <https://raw.githubusercontent.com/openai/skills/main/skills/.system/skill-installer/agents/openai.yaml>

提炼要点：
1. frontmatter 触发描述要精确，明确“做什么 + 什么时候用”。
2. 采用渐进式披露：`SKILL.md` 保持精简，细节放 `references/`。
3. 优先用可执行脚本承载确定性任务，减少重复手写逻辑。

## 2) openclaw/openclaw（236,778 stars）

- 仓库：<https://github.com/openclaw/openclaw>
- 星标数据（GitHub API）：<https://api.github.com/repos/openclaw/openclaw>
- 参考文件：
  - <https://raw.githubusercontent.com/openclaw/openclaw/main/skills/obsidian/SKILL.md>
  - <https://raw.githubusercontent.com/openclaw/openclaw/main/skills/skill-creator/SKILL.md>

提炼要点：
1. 技能内容强调“操作边界 + 默认路径 + 避免硬编码”。
2. 针对具体工具给出最短可执行命令，降低误操作概率。
3. 把“发现源信息的真实来源”写清（例如配置文件路径）。

## 3) numman-ali/n-skills（913 stars）

- 仓库：<https://github.com/numman-ali/n-skills>
- 星标数据（GitHub API）：<https://api.github.com/repos/numman-ali/n-skills>
- 参考文件：
  - <https://raw.githubusercontent.com/numman-ali/n-skills/main/skills/workflow/orchestration/skills/orchestration/SKILL.md>
  - <https://raw.githubusercontent.com/numman-ali/n-skills/main/skills/workflow/open-source-maintainer/skills/open-source-maintainer/SKILL.md>

提炼要点：
1. “操作契约”写法清晰：先说明必须做/禁止做，再给流程。
2. 输出标准可直接执行：建议固定“摘要 + 验证 + 风险”结构。
3. 复杂任务时按阶段路由 references，避免一次性加载全部信息。

## 合并到本 skill 的决策

1. 用 `SKILL.md` 定义触发、约束、流程与验收标准。
2. 用 `scripts/audit_openclaw_config.sh` 实现可重复审计（敏感字段、路径、类型）。
3. 用 `references/test_cases.txt + scripts/test.sh` 固化正常/边界/异常回放。
