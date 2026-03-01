# Skill 质量检查清单（可复用）

## 核心质量

- [ ] `name` 与目录名一致，且匹配 `^[a-z0-9-]{1,64}$`
- [ ] `name` 不含 `anthropic`、`claude`
- [ ] `description` 非空、第三人称、<= 1024 字符
- [ ] frontmatter 仅含 `name` 与 `description`
- [ ] `SKILL.md` 正文 <= 500 行

## 结构与内容

- [ ] SKILL.md 有明确工作流（探索/规划/实现/验证）
- [ ] 至少包含一种可执行验证方式
- [ ] 非 `feipi-gen-skills` 的 SKILL.md 不含 `make test SKILL=...` / `make validate DIR=...`
- [ ] 复杂细节下沉到 `references/`，主文件保持简洁
- [ ] 引用为一级深（由 SKILL.md 直接链接）
- [ ] 术语一致，无同义词混用

## 工程化

- [ ] 优先复用脚本实现确定性步骤
- [ ] 脚本具备基本错误处理
- [ ] 无 Windows 风格路径（统一 `/`）
- [ ] 新建 skill 目录判定正确（本仓库内 -> `.agents/skills/`；默认优先 `skills/`）
- [ ] 无 skill 内分散 `.env.example`，环境变量模板仅维护在仓库根 `.env.example`
- [ ] 同类场景环境变量命名统一（如 `AGENT_VIDEO_*`、`AGENT_PLANTUML_PORT`）
- [ ] 若存在历史变量重命名，已提供新旧名兼容与迁移说明
- [ ] 已运行 `make validate DIR=<skill-root>/<name>` 并通过

## 评估与迭代

- [ ] 至少 3 个评估场景（正常/边界/异常）
- [ ] 用真实任务回放进行验证
- [ ] 记录失败行为并迭代修复
