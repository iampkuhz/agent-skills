# 相关来源（精简）

路径基准：相对本 skill 的 `SKILL.md` 所在目录。

1. `../feipi-read-youtube-video/SKILL.md`
- 用途：YouTube 链接的字幕/转写提取入口。

2. `../feipi-read-bilibili-video/SKILL.md`
- 用途：Bilibili 链接的字幕/转写提取入口。

3. `scripts/render_summary_prompt.sh`
- 用途：构建默认摘要请求包，约束输出为“总述 + 结构化列表 + 附件（原始视频链接 + 转写文本）”，并显式禁止主动扩展到背景、影响和相关新闻。

4. `scripts/render_background_prompt.sh`
- 用途：构建背景请求包，支持 `expand` 与 `background-only` 两种模式；默认 `--news off`，只有用户显式要求时才开启相关新闻/最新进展范围。

5. `../../feipi-scripts/video/whispercpp_transcribe.sh`
- 用途：仓库级 whisper.cpp 转写脚本，支持 `fast/accurate` 档位。

6. `../../feipi-scripts/video/yt_dlp_common.sh`
- 用途：仓库级 yt-dlp 公共流程，提供 whisper 模式与字幕转文本能力。
