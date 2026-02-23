# Skills Overview

| Skill | 用途 | 特点                                    |
|---|---|---------------------------------------|
| `feipi-gen-skills` | 新建或升级其他 skill | 明确 skill 命名规范，基于 best-practice 生成高质量的 skills |
| `feipi-gen-plantuml-code` | 根据指令生成 PlantUML 并自动校验语法 | 本地 server 优先，失败自动回退公网；内置宽度/布局约束与分类型 reference |
| `feipi-read-youtube-video` | 下载 YouTube 视频或提取音频 | 支持下视频或只拿音频                            |

## 安装 Skill（最简单）

在仓库根目录执行：

```bash
make install-links
```

这会把 `skills/` 下的技能以软链接方式安装到目标目录（默认 `~/.agents/skills`）。

可选示例：

```bash
AGENT=qoder make install-links
AGENT=openclaw make install-links
```

默认目录映射：

codex -> `$CODEX_HOME/skills`（未设置时为 `~/.codex/skills`）
qoder -> `~/.qoder/skills`
claudecode -> `~/.claude/skills`
openclaw -> `$OPENCLAW_HOME/skills`（未设置时为 `~/.openclaw/skills`）
未设置 AGENT -> `~/.agents/skills`
