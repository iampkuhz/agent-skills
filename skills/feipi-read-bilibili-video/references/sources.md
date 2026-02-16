# 来源与改造说明

本技能参考并中文化改造自以下资料：

1. GitHub: daymade/claude-code-skills（`youtube-downloader` 技能方向）
   - https://github.com/daymade/claude-code-skills
2. yt-dlp 官方文档（命令行参数与格式选择）
   - https://github.com/yt-dlp/yt-dlp
3. yt-dlp 支持站点说明（含 bilibili 提取器）
   - https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md
4. whisper.cpp 官方仓库（本地转写引擎）
   - https://github.com/ggml-org/whisper.cpp
5. whisper.cpp 模型发布（large-v3 q5_0）
   - https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin

改造点：
- 对齐本仓库 `feipi-<action>-<target...>` 命名规范。
- 强制中文维护与可验证输出（dryrun + 结果摘要）。
- 将 `whisper` 转写实现切换为 `whisper.cpp`（Mac Metal + CPU 回退）。
