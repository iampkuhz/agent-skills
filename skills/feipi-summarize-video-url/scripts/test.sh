#!/usr/bin/env bash
set -euo pipefail

# 统一测试入口（供 make test 调用）
# 每行用例格式：<url>|<instruction>|<expected_profile>|<run_type>
# - expected_profile: fast|accurate（可空，默认 fast）
# - run_type: selection|extract（可空，默认 extract）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTRACT_SCRIPT="$SCRIPT_DIR/extract_video_text.sh"
REQUEST_SCRIPT="$SCRIPT_DIR/render_summary_prompt.sh"
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
  stamp="$(date +%Y%m%d-%H%M%S)"
  ROOT_DIR="$HOME/Downloads/feipi-summarize-video-url-test-$stamp"
fi
mkdir -p "$ROOT_DIR"
LOG_DIR="$ROOT_DIR/logs"
OUT_DIR="$ROOT_DIR/out"
mkdir -p "$LOG_DIR" "$OUT_DIR"

echo "测试配置: $CONFIG"
echo "测试输出: $ROOT_DIR"

TOTAL=0
PASSED=0
FAILED=0

# 依赖检查：存在
TOTAL=$((TOTAL + 1))
log_file="$LOG_DIR/case-$TOTAL-deps-ok.log"
set +e
bash "$EXTRACT_SCRIPT" "https://www.youtube.com/watch?v=abc" "$OUT_DIR/deps" auto --check-deps >"$log_file" 2>&1
code=$?
set -e
if [[ $code -eq 0 ]]; then
  echo "[PASS] case-$TOTAL deps-check-ok"
  PASSED=$((PASSED + 1))
else
  echo "[FAIL] case-$TOTAL deps-check-ok" >&2
  echo "日志: $log_file" >&2
  FAILED=$((FAILED + 1))
fi

# 依赖检查：缺失
TOTAL=$((TOTAL + 1))
log_file="$LOG_DIR/case-$TOTAL-deps-missing.log"
set +e
AGENT_SKILLS_ROOT="$ROOT_DIR/not-exists" bash "$EXTRACT_SCRIPT" "https://www.youtube.com/watch?v=abc" "$OUT_DIR/deps-missing" auto --check-deps >"$log_file" 2>&1
code=$?
set -e
if [[ $code -ne 0 ]]; then
  echo "[PASS] case-$TOTAL deps-check-missing（预期失败）"
  PASSED=$((PASSED + 1))
else
  echo "[FAIL] case-$TOTAL deps-check-missing（预期失败，实际成功）" >&2
  echo "日志: $log_file" >&2
  FAILED=$((FAILED + 1))
fi

while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"
  line="$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue

  IFS='|' read -r URL INSTRUCTION EXPECTED_PROFILE RUN_TYPE <<< "$line"
  URL="$(echo "${URL:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  INSTRUCTION="$(echo "${INSTRUCTION:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  EXPECTED_PROFILE="$(echo "${EXPECTED_PROFILE:-fast}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  RUN_TYPE="$(echo "${RUN_TYPE:-extract}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

  if [[ -z "$URL" ]]; then
    TOTAL=$((TOTAL + 1))
    echo "[FAIL] case-$TOTAL URL 为空" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  if [[ "$EXPECTED_PROFILE" != "fast" && "$EXPECTED_PROFILE" != "accurate" ]]; then
    TOTAL=$((TOTAL + 1))
    echo "[FAIL] case-$TOTAL expected_profile 非法: $EXPECTED_PROFILE" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  if [[ "$RUN_TYPE" != "selection" && "$RUN_TYPE" != "extract" ]]; then
    TOTAL=$((TOTAL + 1))
    echo "[FAIL] case-$TOTAL run_type 非法: $RUN_TYPE" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  TOTAL=$((TOTAL + 1))
  case_id="case-$TOTAL"
  case_dir="$OUT_DIR/$case_id"
  mkdir -p "$case_dir"
  log_file="$LOG_DIR/$case_id.log"

  echo "----"
  echo "开始执行 $case_id"
  echo "URL: $URL"
  echo "instruction: ${INSTRUCTION:-<empty>}"
  echo "expected_profile: $EXPECTED_PROFILE"
  echo "run_type: $RUN_TYPE"

  selection_cmd=(bash "$EXTRACT_SCRIPT" "$URL" "$case_dir/selection" auto --quality auto --check-deps)
  if [[ -n "$INSTRUCTION" ]]; then
    selection_cmd+=(--instruction "$INSTRUCTION")
  fi

  set +e
  selection_output="$("${selection_cmd[@]}" 2>&1)"
  selection_code=$?
  set -e
  printf "[selection]\n%s\n" "$selection_output" > "$log_file"

  if [[ $selection_code -ne 0 ]]; then
    echo "[FAIL] $case_id 选档检查失败" >&2
    echo "日志: $log_file" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  selected_profile="$(printf "%s\n" "$selection_output" | sed -n 's/^whisper_profile=//p' | tail -n1)"
  if [[ "$selected_profile" != "$EXPECTED_PROFILE" ]]; then
    echo "[FAIL] $case_id 选档不符合预期（expect=$EXPECTED_PROFILE actual=$selected_profile）" >&2
    echo "日志: $log_file" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  if [[ "$RUN_TYPE" == "selection" ]]; then
    echo "[PASS] $case_id selection-only profile=$selected_profile"
    PASSED=$((PASSED + 1))
    continue
  fi

  extract_cmd=(bash "$EXTRACT_SCRIPT" "$URL" "$case_dir" auto --quality auto)
  if [[ -n "$INSTRUCTION" ]]; then
    extract_cmd+=(--instruction "$INSTRUCTION")
  fi
  set +e
  extract_output="$("${extract_cmd[@]}" 2>&1)"
  extract_code=$?
  set -e
  printf "[selection]\n%s\n\n[extract]\n%s\n" "$selection_output" "$extract_output" > "$log_file"

  if [[ $extract_code -ne 0 ]]; then
    echo "[FAIL] $case_id 文本提取失败" >&2
    echo "日志: $log_file" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  text_path="$(printf "%s\n" "$extract_output" | sed -n 's/^text_path=//p' | tail -n1)"
  source="$(printf "%s\n" "$extract_output" | sed -n 's/^source=//p' | tail -n1)"
  whisper_profile="$(printf "%s\n" "$extract_output" | sed -n 's/^whisper_profile=//p' | tail -n1)"

  if [[ "$whisper_profile" != "$EXPECTED_PROFILE" ]]; then
    echo "[FAIL] $case_id 提取阶段选档不符合预期（expect=$EXPECTED_PROFILE actual=$whisper_profile）" >&2
    echo "日志: $log_file" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  if [[ -z "$text_path" || ! -f "$text_path" ]]; then
    echo "[FAIL] $case_id 未产出文本文件" >&2
    echo "日志: $log_file" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  if ! rg -q '^- \[[0-9]{2}:[0-9]{2}(:[0-9]{2})?\] ' "$text_path"; then
    echo "[FAIL] $case_id 文本不含时间戳" >&2
    echo "日志: $log_file" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  set +e
  meta_line="$(yt-dlp --skip-download --no-playlist --print "%(duration)s|%(title)s" "$URL" 2>>"$log_file" | head -n1)"
  meta_code=$?
  set -e

  duration_sec=""
  video_title="未命名视频"
  if [[ $meta_code -eq 0 && -n "$meta_line" ]]; then
    duration_sec="${meta_line%%|*}"
    video_title="${meta_line#*|}"
  fi
  if ! [[ "$duration_sec" =~ ^[0-9]+$ ]]; then
    duration_sec=900
  fi

  request_path="$case_dir/summary_request.md"
  set +e
  request_output="$(bash "$REQUEST_SCRIPT" "$URL" "$video_title" "$duration_sec" "$text_path" > "$request_path" 2>&1)"
  request_code=$?
  set -e
  printf "\n[request]\n%s\n" "$request_output" >> "$log_file"

  if [[ $request_code -ne 0 || ! -f "$request_path" ]]; then
    echo "[FAIL] $case_id 请求包生成失败" >&2
    echo "日志: $log_file" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  if ! rg -q '^## 摘要概述$' "$request_path" || ! rg -q '^## 核心观点时间线$' "$request_path"; then
    echo "[FAIL] $case_id 请求包缺少输出结构约束" >&2
    echo "日志: $log_file" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  if ! rg -q '<TRANSCRIPT_START>' "$request_path" || ! rg -q '<TRANSCRIPT_END>' "$request_path"; then
    echo "[FAIL] $case_id 请求包未包含文本片段" >&2
    echo "日志: $log_file" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  if ! rg -q '绝对禁止出现以下表达|禁止出现以下模板句' "$request_path"; then
    echo "[FAIL] $case_id 请求包缺少反套话约束" >&2
    echo "日志: $log_file" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  inside_lines="$(awk '
    /<TRANSCRIPT_START>/ {inside=1; next}
    /<TRANSCRIPT_END>/ {inside=0}
    inside {c++}
    END {print c+0}
  ' "$request_path")"
  if [[ -z "$inside_lines" || "$inside_lines" -lt 5 ]]; then
    echo "[FAIL] $case_id 请求包文本内容过少" >&2
    echo "日志: $log_file" >&2
    FAILED=$((FAILED + 1))
    continue
  fi

  echo "[PASS] $case_id source=$source request=$request_path"
  PASSED=$((PASSED + 1))
done < "$CONFIG"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "未执行任何测试用例" >&2
  exit 1
fi

echo "测试汇总: total=$TOTAL pass=$PASSED fail=$FAILED"
if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi

echo "测试通过: feipi-summarize-video-url（提取 + 请求包链路通过）"
