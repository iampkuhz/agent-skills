# 仓库落地硬约束

## 命名
- 必须符合命名规范，见 `references/naming-conventions.md`。

## Frontmatter 规范
- 见 `references/frontmatter-policy.md`。

## 中文维护
- 见 `references/chinese-policy.md`。

## 版本约束
- 见 `references/version-policy.md`。

## 测试结构约束（开发流程）
- 每个 skill 必须提供统一测试入口：`<skill-root>/<name>/scripts/test.sh`。
- 测试数据默认放在：`<skill-root>/<name>/references/test_cases.txt`（如需要）。
- 仓库级统一通过 `bash scripts/test.sh <skill-name>` 调度。
- 上述测试命令仅在创建/修改 skill 的开发流程执行，不写入目标 skill 的 `SKILL.md`。

## 校验约束
- 新建或修改 skill 后，必须执行：`bash scripts/validate.sh <skill-dir>`。
- 修改 skill 后，除执行校验外，还必须确认版本处理符合 `references/version-policy.md`。

## 新建 skill 目录判定
- 见 `references/skill-directory-policy.md`。

## 使用态与开发流程分离
- 使用态（调用 skill 完成用户任务）：`SKILL.md` 只保留完成任务所需信息（输入、输出、执行步骤、结果校验）。
- 禁止在非 `feipi-gen-skills` 的 `SKILL.md` 中出现仓库维护命令。
- 开发流程（创建/修改/重构 skill）：执行 `validate` 与必要的 `test`，结果记录在开发过程与提交说明中，不沉淀到目标 `SKILL.md`。

## 版本兼容策略
- 见 `references/version-policy.md`。
