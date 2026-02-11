# 仓库级大模型上下文（中文维护）

## 全局约束

1. 本仓库所有说明、脚本提示文案、提交说明默认使用中文。
2. 本仓库新增或更新的所有 skill 内容必须以中文为主：
   - `SKILL.md` 的 `description` 与正文使用中文。
   - `agents/openai.yaml` 的 `display_name`、`short_description`、`default_prompt` 使用中文。
   - `references/` 文档默认中文（如保留英文原文，需附中文摘要）。
   - 脚本与配置中的注释统一使用中文。
3. skill 目录名保持技术命名规范：`^[a-z0-9-]{1,64}$`。
4. 新建或修改 skill 后，必须执行 `make validate DIR=skills/<name>`。

## 维护建议

1. 优先复用 `scripts/init_skill.sh` 与 `templates/`，避免手工复制。
2. 变更前先明确“触发条件 + 输出标准”，再写入 `SKILL.md`。
