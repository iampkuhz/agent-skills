#!/usr/bin/env bash
set -euo pipefail

# 布局宽度校验：元素较多时强制上下布局，避免图横向过宽。

usage() {
  cat <<'USAGE'
用法:
  scripts/lint_layout.sh <input.puml> [--threshold <num>]

说明:
  当元素数或连线数超过阈值时，必须出现 `top to bottom direction`。
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

INPUT_FILE=""
THRESHOLD=8

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold)
      THRESHOLD="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$INPUT_FILE" ]]; then
        INPUT_FILE="$1"
        shift 1
      else
        echo "未知参数: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
  echo "输入文件不存在: $INPUT_FILE" >&2
  exit 1
fi

if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || [[ "$THRESHOLD" -lt 1 ]]; then
  echo "--threshold 必须是正整数" >&2
  exit 1
fi

CONTENT="$(awk '
  /^[[:space:]]*\x27/ {next}
  /^[[:space:]]*\/\// {next}
  /^[[:space:]]*$/ {next}
  {print}
' "$INPUT_FILE")"

ENTITY_PATTERN='^[[:space:]]*(actor|participant|component|rectangle|node|database|class|interface|usecase|cloud|queue|package|frame|artifact|agent|collections?)\b'
RELATION_PATTERN='(<[-.]+>|[-.]+>|<[-.]+|-[Uu][Pp]-|-[Dd][Oo][Ww][Nn]-|-[Ll][Ee][Ff][Tt]-|-[Rr][Ii][Gg][Hh][Tt]-)'

ENTITY_COUNT=$(printf '%s\n' "$CONTENT" | grep -Eic "$ENTITY_PATTERN" || true)
RELATION_COUNT=$(printf '%s\n' "$CONTENT" | grep -Eic "$RELATION_PATTERN" || true)

SEQUENCE_ENTITY_COUNT=$(printf '%s\n' "$CONTENT" | grep -Eic '^[[:space:]]*(actor|participant|boundary|control|entity|collections?|database)\b' || true)
SEQUENCE_MESSAGE_COUNT=$(printf '%s\n' "$CONTENT" | grep -Eic '[-.]+>|<[-.]+' || true)
NON_SEQUENCE_ENTITY_COUNT=$(printf '%s\n' "$CONTENT" | grep -Eic '^[[:space:]]*(component|rectangle|class|interface|usecase|cloud|node|package|frame|artifact|agent)\b' || true)

IS_SEQUENCE=0
if (( SEQUENCE_ENTITY_COUNT > 0 && SEQUENCE_MESSAGE_COUNT > 0 && NON_SEQUENCE_ENTITY_COUNT == 0 )); then
  IS_SEQUENCE=1
fi

REQUIRE_VERTICAL=0
if (( ENTITY_COUNT >= THRESHOLD || RELATION_COUNT >= THRESHOLD + 2 )); then
  REQUIRE_VERTICAL=1
fi

if (( IS_SEQUENCE == 1 )); then
  # sequence 图不支持 top to bottom direction，避免错误要求导致语法失败。
  if (( SEQUENCE_ENTITY_COUNT > 6 )); then
    echo "布局提示: sequence 图参与者较多（$SEQUENCE_ENTITY_COUNT），建议拆分子图或收敛角色数量，避免过宽。" >&2
  fi
elif (( REQUIRE_VERTICAL == 1 )); then
  if ! printf '%s\n' "$CONTENT" | grep -Eiq '^[[:space:]]*top to bottom direction'; then
    echo "布局校验失败: 元素较多时必须添加 top to bottom direction，避免图过宽。" >&2
    echo "检测结果: entities=$ENTITY_COUNT relations=$RELATION_COUNT threshold=$THRESHOLD" >&2
    exit 3
  fi

  if ! printf '%s\n' "$CONTENT" | grep -Eiq '^[[:space:]]*skinparam[[:space:]]+nodesep[[:space:]]+[0-9]+'; then
    echo "布局提示: 建议设置 skinparam nodesep（如 6~10）进一步压缩横向宽度。" >&2
  fi

  if ! printf '%s\n' "$CONTENT" | grep -Eiq '^[[:space:]]*skinparam[[:space:]]+ranksep[[:space:]]+[0-9]+'; then
    echo "布局提示: 建议设置 skinparam ranksep（如 60~90）拉开纵向可读性。" >&2
  fi
fi

echo "layout_check=ok"
echo "layout_entities=$ENTITY_COUNT"
echo "layout_relations=$RELATION_COUNT"
echo "layout_vertical_required=$REQUIRE_VERTICAL"
echo "layout_is_sequence=$IS_SEQUENCE"
