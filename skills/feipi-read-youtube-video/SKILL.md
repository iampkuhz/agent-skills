---
name: feipi-read-youtube-video
description: 下载 YouTube 视频或音频并保存到本地目录。在用户提到 YouTube 下载、视频转音频、批量保存视频素材、或需要先验证链接可下载时使用。
---

# YouTube 下载技能（中文）

## 核心目标

稳定下载 YouTube 视频/音频，输出可验证结果，并在失败时给出可执行修复路径。

## 触发条件

当用户出现以下意图时触发：
- 下载 YouTube 视频到本地
- 提取 YouTube 音频（如 mp3）
- 先验证链接可下载再执行
- 批量处理播放列表（需用户明确允许）

## 边界与合规

1. 仅处理用户有权下载和使用的内容。
2. 默认关闭播放列表批量下载，避免误下载大量内容。
3. 若用户未提供 URL，不执行下载，先索取链接。

## 依赖

1. `yt-dlp`
2. `ffmpeg`（下载合并高质量视频、音频转码时需要）

## 工作流（Explore -> Plan -> Implement -> Verify）

1. Explore
- 确认 URL、输出目录、目标格式（视频/音频）。
- 若需求不明确，默认：下载单视频到 `./downloads`。

2. Plan
- 选择模式：`video`、`audio`、`dryrun`。
- 明确输出路径与命名。

3. Implement
- 运行脚本：`scripts/download_youtube.sh`。
- 对未知站点或异常链接，先 `dryrun` 再实下载。

4. Verify
- 检查命令退出码为 0。
- 检查输出目录存在新增文件。
- 记录验证结果（文件名、大小、路径）。

## 标准命令

1. 下载视频（默认）：
```bash
bash scripts/download_youtube.sh "<youtube_url>" "./downloads" video
```

2. 提取音频（mp3）：
```bash
bash scripts/download_youtube.sh "<youtube_url>" "./downloads" audio
```

3. 仅验证可下载（不真正下载）：
```bash
bash scripts/download_youtube.sh "<youtube_url>" "./downloads" dryrun
```
说明：`dryrun` 只输出标题和视频 ID，不生成下载文件。适合先验证链接与权限，再执行真实下载。

## 失败处理

1. 缺少依赖
- 提示安装 `yt-dlp` 与 `ffmpeg`，再重试。

2. 地区/权限限制
- 先执行 `dryrun`，返回错误摘要给用户。
- 如需登录态，提示用户自行提供合法 cookie 方案。

3. 下载成功但无音频/无视频
- 优先改用默认 `video` 模式重试。

## 验收标准

1. 至少执行一次 `dryrun` 或真实下载。
2. 输出包含：执行命令、结果状态、文件路径。
3. 若失败，输出明确错误与下一步建议。

## 参考

- 来源与改造记录：`references/sources.md`
