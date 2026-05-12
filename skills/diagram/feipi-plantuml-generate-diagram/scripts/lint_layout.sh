#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
用法:
  bash scripts/lint_layout.sh --type <architecture|sequence> <diagram.puml> [brief.yaml]

说明:
  按 profile 执行布局校验。
  architecture：检查纵向布局、package 数量、legend、间距。
  sequence：检查参与者数量、box/separator 结构、autonumber 顺序、间距。
USAGE
}

DIAGRAM_TYPE=""
INPUT_FILE=""
BRIEF_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      DIAGRAM_TYPE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$INPUT_FILE" ]]; then
        INPUT_FILE="$1"
        shift
      elif [[ -z "$BRIEF_FILE" ]]; then
        BRIEF_FILE="$1"
        shift
      else
        echo "未知参数：$1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$DIAGRAM_TYPE" ]]; then
  echo "缺少 --type 参数" >&2
  usage
  exit 1
fi

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
  echo "输入文件不存在：$INPUT_FILE" >&2
  exit 1
fi

CONTENT="$(awk '
  /^[[:space:]]*\x27/ {next}
  /^[[:space:]]*\/\// {next}
  /^[[:space:]]*$/ {next}
  {print}
' "$INPUT_FILE")"

# =============================================================================
# Architecture 布局校验
# =============================================================================
if [[ "$DIAGRAM_TYPE" == "architecture" ]]; then
  if ! printf '%s\n' "$CONTENT" | grep -Eiq '^[[:space:]]*top to bottom direction'; then
    echo "布局校验失败：架构图必须显式声明 top to bottom direction" >&2
    exit 2
  fi

  if ! printf '%s\n' "$CONTENT" | grep -Eiq '^[[:space:]]*skinparam[[:space:]]+nodesep[[:space:]]+[0-9]+'; then
    echo "布局校验失败：缺少 skinparam nodesep" >&2
    exit 3
  fi

  if ! printf '%s\n' "$CONTENT" | grep -Eiq '^[[:space:]]*skinparam[[:space:]]+ranksep[[:space:]]+[0-9]+'; then
    echo "布局校验失败：缺少 skinparam ranksep" >&2
    exit 4
  fi

  PACKAGE_COUNT="$(printf '%s\n' "$CONTENT" | grep -Eic '^[[:space:]]*package[[:space:]]+"[^"]+"' || true)"
  if [[ "$PACKAGE_COUNT" -lt 3 ]]; then
    echo "布局校验失败：架构图至少需要 3 个 package 作为层容器，当前：$PACKAGE_COUNT" >&2
    exit 5
  fi

  # Legend check
  INCLUDE_LEGEND="true"
  if [[ -n "$BRIEF_FILE" && -f "$BRIEF_FILE" ]]; then
    INCLUDE_LEGEND="$(python3 -c "
import yaml, sys
try:
    with open('$BRIEF_FILE') as f:
        data = yaml.safe_load(f)
    layout = data.get('layout', {})
    val = layout.get('include_legend', True)
    print('false' if val == False else 'true')
except:
    print('true')
")" || true
  fi

  if [[ "$INCLUDE_LEGEND" == "true" ]]; then
    if ! printf '%s\n' "$CONTENT" | grep -Eiq '^[[:space:]]*legend\b'; then
      echo "布局校验失败：缺少 legend，读者无法快速识别层级语义" >&2
      exit 6
    fi
  fi

  # Long lines
  LONG_LINES="$(awk 'length($0) > 140 {print NR ":" length($0)}' "$INPUT_FILE" || true)"
  if [[ -n "$LONG_LINES" ]]; then
    echo "布局提示：存在超过 140 字符的长行，建议拆分标签或子图。" >&2
    echo "$LONG_LINES" >&2
  fi

  echo "layout_check=ok"
  echo "layout_packages=$PACKAGE_COUNT"
  exit 0
fi

# =============================================================================
# Sequence 布局校验
# =============================================================================
if [[ "$DIAGRAM_TYPE" == "sequence" ]]; then
  PARTICIPANT_COUNT="$(printf '%s\n' "$CONTENT" | grep -Eic '^[[:space:]]*(participant|actor|database)[[:space:]]+"[^"]+"' || true)"
  if [[ "$PARTICIPANT_COUNT" -lt 2 ]]; then
    echo "布局校验失败：时序图至少需要 2 个参与者，当前：$PARTICIPANT_COUNT" >&2
    exit 2
  fi

  BOX_COUNT="$(printf '%s\n' "$CONTENT" | grep -Eic '^[[:space:]]*box[[:space:]]' || true)"
  ENDBOX_COUNT="$(printf '%s\n' "$CONTENT" | grep -Eic '^[[:space:]]*endbox' || true)"
  if [[ "$BOX_COUNT" -gt 0 && "$BOX_COUNT" -ne "$ENDBOX_COUNT" ]]; then
    echo "布局校验失败：box 和 endbox 数量不匹配，box=$BOX_COUNT, endbox=$ENDBOX_COUNT" >&2
    exit 5
  fi

  if [[ "$BOX_COUNT" -gt 0 ]] && printf '%s\n' "$CONTENT" | grep -Eiq '^[[:space:]]*left[[:space:]]+to[[:space:]]+right[[:space:]]+direction'; then
    echo "布局校验失败：sequence diagram 中 box 与 left to right direction 互斥" >&2
    exit 6
  fi

  if printf '%s\n' "$CONTENT" | grep -Eiq '^[[:space:]]*separator\b'; then
    echo "布局校验失败：不要使用 PlantUML separator 关键字；请改用 == 组名 == 分隔线" >&2
    exit 7
  fi

  AUTONUMBER_LINE="$(grep -nE '^[[:space:]]*autonumber\b' "$INPUT_FILE" | head -1 | cut -d: -f1 || true)"
  LAST_PARTICIPANT_LINE="$(grep -nE '^[[:space:]]*(participant|actor|database)[[:space:]]+"[^"]+"' "$INPUT_FILE" | tail -1 | cut -d: -f1 || true)"
  if [[ -z "$AUTONUMBER_LINE" ]]; then
    echo "布局提示：建议包含 autonumber 以自动编号消息" >&2
  elif [[ -n "$LAST_PARTICIPANT_LINE" && "$AUTONUMBER_LINE" -le "$LAST_PARTICIPANT_LINE" ]]; then
    echo "布局校验失败：autonumber 必须放在所有参与者声明之后、第一条消息之前" >&2
    exit 8
  fi

  if ! printf '%s\n' "$CONTENT" | grep -Eiq '^[[:space:]]*skinparam[[:space:]]+nodesep[[:space:]]+[0-9]+'; then
    echo "布局校验失败：缺少 skinparam nodesep" >&2
    exit 3
  fi

  if ! printf '%s\n' "$CONTENT" | grep -Eiq '^[[:space:]]*skinparam[[:space:]]+ranksep[[:space:]]+[0-9]+'; then
    echo "布局校验失败：缺少 skinparam ranksep" >&2
    exit 4
  fi

  LONG_LINES="$(awk 'length($0) > 140 {print NR ":" length($0)}' "$INPUT_FILE" || true)"
  if [[ -n "$LONG_LINES" ]]; then
    echo "布局提示：存在超过 140 字符的长行，建议拆分标签或子图。" >&2
    echo "$LONG_LINES" >&2
  fi

  echo "layout_check=ok"
  echo "layout_participants=$PARTICIPANT_COUNT"
  exit 0
fi

echo "不支持的图类型：$DIAGRAM_TYPE" >&2
exit 1
