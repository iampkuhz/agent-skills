---
name: feipi-summarize-video-url
description: 用于根据视频 URL 调用来源技能提取带时间戳文本，并生成交付远程大模型的总结请求包。在需要快速产出“摘要概述 + 核心观点时间线”时使用。
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
- 用户原始指令（用于自动判定提取质量档位）
- 质量档位参数：`--quality auto|fast|accurate`（默认 `auto`）

3. 输出
- `summary_request.md`（提示词 + 文本片段）
- 远程模型最终输出：`摘要概述` + `核心观点时间线`

## 自动选档规则（提速重点）

1. 默认策略（`--quality auto`）
- 指令明确要求高质量（如“高质量/高精度/准确/逐字”）时，选择 `accurate`。
- 其他情况默认选择 `fast`。

2. `mode=auto` 的执行顺序
- `accurate`：先 `whisper`，失败再回退 `subtitle`。
- `fast`：先 `subtitle`，失败再回退 `whisper`。

3. 观测字段
- `extract_video_text.sh` 输出中包含：
  - `whisper_profile`
  - `selection_reason`
  - `strategy`

## 工作流（Explore -> Plan -> Implement -> Verify）

1. Explore
- `scripts/extract_video_text.sh` 内部识别来源（YouTube/Bilibili）。
- `scripts/extract_video_text.sh --check-deps` 校验依赖与自动选档结果。

2. Plan
- 根据用户指令选择质量档位（默认快档，显式高质量则慢档）。
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
bash scripts/extract_video_text.sh "<video_url>" "./tmp/video-text" auto \
  --instruction "请快速总结" \
  --check-deps
```

2. 自动选档提取（默认快档）：
```bash
bash scripts/extract_video_text.sh "<video_url>" "./tmp/video-text" auto \
  --instruction "请快速提取并总结重点"
```

3. 高质量提取（触发慢档）：
```bash
bash scripts/extract_video_text.sh "<video_url>" "./tmp/video-text" auto \
  --instruction "请高质量逐字转写，准确优先"
```

4. 显式指定档位（可绕过自动判定）：
```bash
bash scripts/extract_video_text.sh "<video_url>" "./tmp/video-text" whisper \
  --quality accurate
```

5. 生成请求包：
```bash
bash scripts/render_summary_prompt.sh \
  "<video_url>" \
  "示例视频标题" \
  1500 \
  "./tmp/video-text/xxx.txt" \
  > "./tmp/video-text/summary_request.md"
```

6. 回归测试：
```bash
make test SKILL=feipi-summarize-video-url
```

## 验收标准

1. 依赖缺失时失败退出。
2. 输出文本带时间戳。
3. 自动选档结果可观察（`whisper_profile`、`selection_reason`、`strategy`）。
4. 请求包含字幕文本与反套话约束。
5. `make test SKILL=feipi-summarize-video-url` 可执行。

## 渐进式披露

- 用例：`references/test_cases.txt`
- 来源：`references/sources.md`
