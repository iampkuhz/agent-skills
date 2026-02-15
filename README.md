# Skills Overview

| Skill | 用途 | 特点                                    |
|---|---|---------------------------------------|
| `feipi-gen-skills` | 新建或升级其他 skill | 明确 skill 命名规范，基于 best-practice 生成高质量的 skills |
| `feipi-read-youtube-video` | 下载 YouTube 视频或提取音频 | 支持下视频或只拿音频                            |

## 安装 Skill（最简单）

在仓库根目录执行：

```bash
make install-links
```

这会把 `skills/` 下的技能以软链接方式安装到 `$CODEX_HOME/skills`（未设置时为 `~/.codex/skills`）。
