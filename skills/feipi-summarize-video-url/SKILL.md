---
name: feipi-summarize-video-url
description: 基于视频 URL 调用来源技能提取字幕/转写文本，并生成“提示词+文本请求包”，交由远程大模型产出最终总结。在用户要求快速总结视频重点时使用。
---

# 视频 URL 文本总结技能（中文）

## 核心目标

输入视频 URL，输出用于远程大模型总结的请求包（提示词 + 字幕文本）。
远程模型最终只需产出两段：
1. `摘要概述`
2. `核心观点时间线`

## 关键原则

1. 不做本地“伪摘要”
- 本 skill 只负责提取文本与构建请求包。
- 不在本地用词频/规则模板直接生成最终结论。

2. 去套话
- 请求包中显式禁用无意义模板句。
- 目标是直接提炼信息，不是点评文本写法。

3. 详略由模型读文本后决定
- 不依赖本地信息密度脚本。
- 仅按时长给建议条目区间，具体详略由远程模型判断。

## 依赖技能（强约束）

必须依赖：
1. `skills/feipi-read-youtube-video`
2. `skills/feipi-read-bilibili-video`

规则：
- YouTube：调用 `feipi-read-youtube-video/scripts/download_youtube.sh`
- Bilibili：调用 `feipi-read-bilibili-video/scripts/download_bilibili.sh`
- 依赖缺失：立即停止并提示用户先配置。

## 输入与输出

1. 最少输入
- 视频 URL

2. 可选输入
- 视频标题

3. 输出
- `summary_request.md`（提示词 + 文本片段）
- 远程模型最终输出：`摘要概述` + `核心观点时间线`

## 工作流（Explore -> Plan -> Implement -> Verify）

1. Explore
- `scripts/extract_video_text.sh` 内部识别来源（YouTube/Bilibili）。
- `scripts/extract_video_text.sh --check-deps` 校验依赖。

2. Plan
- `scripts/extract_video_text.sh` 获取带时间戳文本。
- 根据视频时长控制摘要详略（短视频更短，长视频适当展开）。

3. Implement
- `scripts/render_summary_prompt.sh` 生成“提示词 + 字幕文本”请求包。
- 将请求包提交给远程大模型生成最终总结。

4. Verify
- 请求包包含 `<TRANSCRIPT_START>` 与 `<TRANSCRIPT_END>`。
- 请求包包含反套话约束。
- 远程输出包含两段标题，且时间线有具体时间点。

## 标准命令

1. 检查依赖：
```bash
bash scripts/extract_video_text.sh "<video_url>" "./tmp/video-text" auto --check-deps
```

2. 提取文本：
```bash
bash scripts/extract_video_text.sh "<video_url>" "./tmp/video-text" auto
```

3. 生成请求包：
```bash
bash scripts/render_summary_prompt.sh \
  "<video_url>" \
  "示例视频标题" \
  1500 \
  "./tmp/video-text/xxx.txt" \
  > "./tmp/video-text/summary_request.md"
```

4. 回归测试：
```bash
make test SKILL=feipi-summarize-video-url
```

## 验收标准

1. 依赖缺失时失败退出。
2. 输出文本带时间戳。
3. 请求包含字幕文本与反套话约束。
4. `make test SKILL=feipi-summarize-video-url` 可执行。

## 渐进式披露

- 用例：`references/test_cases.txt`
- 来源：`references/sources.md`
