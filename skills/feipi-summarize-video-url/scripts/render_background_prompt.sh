#!/usr/bin/env bash
set -euo pipefail

# 生成“第二次交付（相关影响与背景分析）”请求包。
# 用法：
#   bash scripts/render_background_prompt.sh <url> <title> <summary_path> <transcript_path> [max_chars]

URL="${1:-}"
TITLE="${2:-未命名视频}"
SUMMARY_PATH="${3:-}"
TRANSCRIPT_PATH="${4:-}"
MAX_CHARS="${5:-60000}"

if [[ -z "$URL" || -z "$SUMMARY_PATH" || -z "$TRANSCRIPT_PATH" ]]; then
  echo "用法: bash scripts/render_background_prompt.sh <url> <title> <summary_path> <transcript_path> [max_chars]" >&2
  exit 1
fi

if [[ ! -f "$SUMMARY_PATH" ]]; then
  echo "第一轮总结文件不存在: $SUMMARY_PATH" >&2
  exit 1
fi

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "字幕/转写文件不存在: $TRANSCRIPT_PATH" >&2
  exit 1
fi

if ! [[ "$MAX_CHARS" =~ ^[0-9]+$ ]]; then
  echo "max_chars 必须是非负整数: $MAX_CHARS" >&2
  exit 1
fi

summary_payload="$(cat "$SUMMARY_PATH")"
summary_chars="$(printf "%s" "$summary_payload" | wc -m | tr -d ' ')"
if [[ -z "$summary_chars" ]]; then
  summary_chars=0
fi

# 第二轮分析主要依赖“第一轮总结 + 字幕证据”。
transcript_payload_raw="$(cat "$TRANSCRIPT_PATH")"
transcript_chars="$(printf "%s" "$transcript_payload_raw" | wc -m | tr -d ' ')"
if [[ -z "$transcript_chars" ]]; then
  transcript_chars=0
fi

truncated="0"
if (( transcript_chars > MAX_CHARS && MAX_CHARS > 0 )); then
  truncated="1"
  head_chars=$((MAX_CHARS * 7 / 10))
  tail_chars=$((MAX_CHARS - head_chars))
  head_part="$(printf "%s" "$transcript_payload_raw" | LC_ALL=C cut -c1-"$head_chars")"
  tail_part="$(printf "%s" "$transcript_payload_raw" | LC_ALL=C tail -c "$tail_chars")"
  transcript_payload="${head_part}

[...中间片段已省略，避免上下文过长...]

${tail_part}"
else
  transcript_payload="$transcript_payload_raw"
fi

cat <<EOF
你正在执行“第二次交付”：在第一轮视频总结的基础上，补充相关影响和背景分析。
第一轮结果已经交付给用户，本轮不要重复第一轮内容，不要复述原文。

视频 URL: $URL
视频标题: $TITLE
第一轮总结文件: $SUMMARY_PATH
转写文件: $TRANSCRIPT_PATH
第一轮摘要字符数: $summary_chars
转写字符数(编号后): $transcript_chars
转写是否截断: $truncated

只允许输出一个章节，标题必须完全一致：
## 相关影响和背景分析

硬性规则：
1) 篇幅分配强约束：
   - “背景知识补充”约占 2/3。
   - “关键影响”约占 1/3。
   - 影响只写最重要的 1-2 条，不做冗长推演。
2) 在该章节内必须使用以下小标题，且顺序固定：
   - ### 背景知识补充（约2/3）
   - ### 关键影响（约1/3）
3) “背景知识补充”必须覆盖以下 4 组信息（缺一不可）：
   - 122 条款是什么：法源、触发条件、权限边界（税率/时限）、与国会关系。
   - 122 条款历史上何时、何场景被使用（或长期未被正式启用），给出具体年份/事件。
   - 本案“此前条款 -> 当前条款”的切换：先前主要依据什么法条，为什么改换，切换后约束有什么变化。
   - 之前已经收上来的税如何处置：资金去向、退税主张路径、通常程序环节与时间成本。
4) “关键影响”每条都要写清：
   - 触发点 -> 作用机制 -> 受影响对象 -> 可观察结果。
   - 禁止只写“会有波动/会受影响”等空话。
5) 背景部分必须给出具体“时间 + 机构/主体 + 关键动作 + 直接结果 + 含义”。
6) 如引用视频证据，时间锚点格式只能是：
   - 时长未超过 1 小时： [MM:SS]
   - 时长超过 1 小时： [HH:MM:SS]
   禁止使用 T+00:00:00，禁止使用字幕行号。
7) 禁止重复第一轮的同义改写；每个列表项都必须新增信息价值。
8) 禁止输出“关键不确定性”“后续观察点是否有诉讼”等空洞小节。
9) 禁止出现“转写误差、不确定、信息不足、仅供参考”等质量豁免表达。

<FIRST_ROUND_SUMMARY_START>
${summary_payload}
<FIRST_ROUND_SUMMARY_END>

<TRANSCRIPT_START>
${transcript_payload}
<TRANSCRIPT_END>
EOF
