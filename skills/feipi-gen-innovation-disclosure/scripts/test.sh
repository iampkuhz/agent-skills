#!/usr/bin/env bash
set -euo pipefail

# 统一测试入口（供 make test 调用）
# 配置文件格式：每行一个 markdown 文件路径（相对 skill 目录或绝对路径）。
# 本 skill 仅保留 happy case 回归。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK_SCRIPT="$SCRIPT_DIR/check_disclosure_format.sh"
DEFAULT_CONFIG="$SKILL_DIR/references/test_cases.txt"

CONFIG=""
OUTPUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$CONFIG" ]]; then
  CONFIG="$DEFAULT_CONFIG"
fi
if [[ ! -f "$CONFIG" ]]; then
  echo "测试配置不存在: $CONFIG" >&2
  exit 1
fi

if [[ -n "$OUTPUT" ]]; then
  ROOT_DIR="$OUTPUT"
else
  STAMP="$(date +%Y%m%d-%H%M%S)"
  ROOT_DIR="$HOME/Downloads/feipi-gen-innovation-disclosure-test-$STAMP"
fi
mkdir -p "$ROOT_DIR"
LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"

echo "测试配置: $CONFIG"
echo "测试输出: $ROOT_DIR"

TOTAL=0
PASSED=0
FAILED=0

while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"
  line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue

  TOTAL=$((TOTAL + 1))
  doc_path="$line"
  if [[ "$doc_path" != /* ]]; then
    doc_path="$SKILL_DIR/$doc_path"
  fi

  log_file="$LOG_DIR/case-$TOTAL.log"
  if [[ ! -f "$doc_path" ]]; then
    echo "[FAIL] case-$TOTAL 文件不存在: $doc_path" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  set +e
  output="$(bash "$CHECK_SCRIPT" "$doc_path" 2>&1)"
  code=$?
  set -e
  printf "%s\n" "$output" > "$log_file"

  if [[ "$code" -eq 0 ]]; then
    echo "[PASS] case-$TOTAL $doc_path"
    PASSED=$((PASSED + 1))
  else
    echo "[FAIL] case-$TOTAL $doc_path" >&2
    echo "日志: $log_file" >&2
    FAILED=$((FAILED + 1))
  fi
done < "$CONFIG"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "未执行任何测试用例" >&2
  exit 1
fi

if [[ "$TOTAL" -ne 1 ]]; then
  echo "当前约束为仅保留 1 个 happy case，实际用例数: $TOTAL" >&2
  exit 1
fi

echo "测试汇总: total=$TOTAL pass=$PASSED fail=$FAILED"
if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi

echo "测试通过: feipi-gen-innovation-disclosure（happy case 通过）"
