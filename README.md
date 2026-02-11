# agent-skills

用于维护个人 Codex skills 的仓库，默认使用中文维护。

## 目录结构

- `skills/`: 所有 skills（不区分 public/private）
- `templates/`: skill 与 agent 元数据模板（仓库自定义，不是 Codex 强制目录）
- `scripts/`: 初始化与校验脚本

## templates 是做什么的

- `templates/` 是本仓库的工程化约定，用来统一新 skill 的初始内容。
- 它不是 Codex 的专用配置目录；没有它也能写 skill。
- 价值是减少重复劳动和风格漂移：
  - `templates/SKILL.template.md`：新 skill 的默认骨架
  - `templates/openai.template.yaml`：`agents/openai.yaml` 默认模板

## 单个 Skill 结构

- `skills/<name>/SKILL.md`: 技能核心说明（触发与执行规则）
- `skills/<name>/agents/openai.yaml`: UI 元数据（显示名、短描述、默认提示词）
- `skills/<name>/scripts/`: 可执行脚本（可选）
- `skills/<name>/references/`: 参考文档（可选）
- `skills/<name>/assets/`: 模板与静态资源（可选）

## Skills 列表

- `skills/feipi-gen-skills`: 中文版 skill 创建与迭代指南（首个技能）
- `skills/feipi-read-youtube-video`: YouTube 视频/音频下载技能（中文）

## 快速开始

创建 skill：

```bash
make new SKILL=gen-api-tests RESOURCES=scripts,references
```

校验 skill：

```bash
make validate DIR=skills/my-skill
```
