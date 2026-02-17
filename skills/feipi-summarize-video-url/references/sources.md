# 相关来源（精简）

1. `skills/feipi-read-youtube-video/SKILL.md`
- 用途：YouTube 链接的字幕/转写提取入口。

2. `skills/feipi-read-bilibili-video/SKILL.md`
- 用途：Bilibili 链接的字幕/转写提取入口。

3. `skills/feipi-summarize-video-url/scripts/render_summary_prompt.sh`
- 用途：构建“提示词 + 字幕文本”请求包，交由远程模型总结。

4. `scripts/video/whispercpp_transcribe.sh`
- 用途：仓库级 whisper.cpp 转写脚本，支持 `fast/accurate` 档位。

5. `scripts/video/yt_dlp_common.sh`
- 用途：仓库级 yt-dlp 公共流程，提供 whisper 模式与字幕转文本能力。
