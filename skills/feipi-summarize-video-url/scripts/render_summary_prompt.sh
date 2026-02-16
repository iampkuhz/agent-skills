#!/usr/bin/env bash
set -euo pipefail

# 生成“提示词 + 字幕文本”请求包。
# 用法：bash scripts/render_summary_prompt.sh <url> <title> <duration_sec> <transcript_path> [max_chars]

URL="${1:-}"
TITLE="${2:-未命名视频}"
DURATION_SEC="${3:-}"
TRANSCRIPT_PATH="${4:-}"
MAX_CHARS="${5:-80000}"

if [[ -z "$URL" || -z "$DURATION_SEC" || -z "$TRANSCRIPT_PATH" ]]; then
  echo "用法: bash scripts/render_summary_prompt.sh <url> <title> <duration_sec> <transcript_path> [max_chars]" >&2
  exit 1
fi

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "字幕/转写文件不存在: $TRANSCRIPT_PATH" >&2
  exit 1
fi

if ! [[ "$DURATION_SEC" =~ ^[0-9]+$ ]]; then
  echo "duration_sec 必须是非负整数: $DURATION_SEC" >&2
  exit 1
fi

if ! [[ "$MAX_CHARS" =~ ^[0-9]+$ ]]; then
  echo "max_chars 必须是非负整数: $MAX_CHARS" >&2
  exit 1
fi

raw_chars="$(wc -m < "$TRANSCRIPT_PATH" | tr -d ' ')"
if [[ -z "$raw_chars" ]]; then
  raw_chars=0
fi

truncated="0"
if (( raw_chars > MAX_CHARS && MAX_CHARS > 0 )); then
  truncated="1"
  head_chars=$((MAX_CHARS * 7 / 10))
  tail_chars=$((MAX_CHARS - head_chars))
  head_part="$(LC_ALL=C cut -c1-"$head_chars" "$TRANSCRIPT_PATH")"
  tail_part="$(LC_ALL=C tail -c "$tail_chars" "$TRANSCRIPT_PATH")"
  transcript_payload="${head_part}

[...中间片段已省略，避免上下文过长...]

${tail_part}"
else
  transcript_payload="$(cat "$TRANSCRIPT_PATH")"
fi

cat <<EOF
请基于下面提供的“视频字幕/转写文本”生成中文总结。
目标：让我在最短时间内掌握视频重点，而不是看你点评写作方式。

视频 URL: $URL
视频标题: $TITLE
视频时长(秒): $DURATION_SEC
文本来源: $TRANSCRIPT_PATH
文本字符数: $raw_chars
是否截断: $truncated

只允许输出两部分，标题必须完全一致：
## 摘要概述
## 核心观点时间线

硬性规则：
1) 摘要只写“结论/事实/争议/建议”，不写过程性废话。
2) 时间线每条只写“时间 + 具体观点/事件”。
3) 绝对禁止出现以下表达（或同义空话）：
- 并承接前后文
- 围绕同一主题反复展开
- 文本信息相对连续，已按语义段落做合并
- 补充要点：围绕……展开延伸
4) 信息密度不要显式讨论，由模型阅读文本后自行判断详略。
5) 如果是歌词/重复口播：提炼主题、情绪变化、重复句含义；不要逐句复读歌词。
6) 如果是访谈/科普：优先写“观点-依据-结论”链路。
7) 摘要条目和时间线条目数量由模型根据视频时长自行控制（短视频更短，长视频适当展开）。

<TRANSCRIPT_START>
${transcript_payload}
<TRANSCRIPT_END>
EOF
