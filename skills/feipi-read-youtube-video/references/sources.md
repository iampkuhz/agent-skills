# 来源与改造说明

本技能参考并中文化改造自以下资料：

1. GitHub: daymade/claude-code-skills（`youtube-downloader` 技能方向）
   - https://github.com/daymade/claude-code-skills
2. GitHub 聚合索引：skills.sh 上的 `youtube-downloader`
   - https://skills.sh/
3. yt-dlp 官方文档（命令行参数与格式选择）
   - https://github.com/yt-dlp/yt-dlp

改造点：
- 对齐本仓库 `feipi-<action>-<target...>` 命名规范。
- 强制中文维护与可验证输出（dryrun + 结果摘要）。
- 增加依赖检查和失败路径建议。
