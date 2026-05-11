#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATE_SCRIPT="$SCRIPT_DIR/validate.sh"
INSTALL_SCRIPT="$SCRIPT_DIR/install_deps.sh"
DOWNLOAD_SCRIPT="$SCRIPT_DIR/download_video.sh"
EXTRACT_SCRIPT="$SCRIPT_DIR/extract_video_text.sh"
SUMMARY_SCRIPT="$SCRIPT_DIR/render_summary_prompt.sh"
BACKGROUND_SCRIPT="$SCRIPT_DIR/render_background_prompt.sh"
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
  mkdir -p "$ROOT_DIR"
else
  ROOT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/feipi-video-read-url-test.XXXXXX")"
fi

LOG_DIR="$ROOT_DIR/logs"
OUT_DIR="$ROOT_DIR/out"
mkdir -p "$LOG_DIR" "$OUT_DIR"

echo "测试配置: $CONFIG"
echo "测试输出: $ROOT_DIR"

TOTAL=0
PASSED=0
FAILED=0

run_simple_case() {
  local name="$1"
  local expect="$2"
  shift 2
  local log_file="$LOG_DIR/${name}.log"
  local code

  TOTAL=$((TOTAL + 1))
  set +e
  "$@" >"$log_file" 2>&1
  code=$?
  set -e

  if [[ "$expect" == "pass" && "$code" -eq 0 ]]; then
    echo "[PASS] $name"
    PASSED=$((PASSED + 1))
    return
  fi

  if [[ "$expect" == "fail" && "$code" -ne 0 ]]; then
    echo "[PASS] ${name}（按预期失败）"
    PASSED=$((PASSED + 1))
    return
  fi

  echo "[FAIL] $name" >&2
  echo "日志: $log_file" >&2
  FAILED=$((FAILED + 1))
}

run_simple_case "validate-self" pass bash "$VALIDATE_SCRIPT" "$SKILL_DIR"
run_simple_case "deps-check" pass bash "$INSTALL_SCRIPT" --check
run_simple_case "unsupported-source-fails" fail bash "$DOWNLOAD_SCRIPT" "https://vimeo.com/123456" "$OUT_DIR/unsupported" dryrun

while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"
  line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue

  IFS='|' read -r KIND URL ARG3 ARG4 ARG5 <<< "$line"
  KIND="$(printf '%s' "${KIND:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  URL="$(printf '%s' "${URL:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  ARG3="$(printf '%s' "${ARG3:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  ARG4="$(printf '%s' "${ARG4:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  ARG5="$(printf '%s' "${ARG5:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

  TOTAL=$((TOTAL + 1))
  case_id="case-$TOTAL"
  case_dir="$OUT_DIR/$case_id"
  log_file="$LOG_DIR/$case_id.log"
  mkdir -p "$case_dir"

  case "$KIND" in
    download)
      MODE="${ARG3:-dryrun}"
      WHISPER_PROFILE="${ARG4:-auto}"
      set +e
      bash "$DOWNLOAD_SCRIPT" "$URL" "$case_dir" "$MODE" "$WHISPER_PROFILE" >"$log_file" 2>&1
      code=$?
      set -e

      if [[ "$code" -ne 0 ]]; then
        echo "[FAIL] $case_id download-$MODE" >&2
        echo "日志: $log_file" >&2
        FAILED=$((FAILED + 1))
        continue
      fi

      case "$MODE" in
        dryrun)
          if find "$case_dir" -type f \( -name '*.mp4' -o -name '*.mp3' -o -name '*.txt' \) | grep -q .; then
            echo "[FAIL] $case_id dryrun 不应生成媒体或文本文件" >&2
            echo "日志: $log_file" >&2
            FAILED=$((FAILED + 1))
            continue
          fi
          ;;
        video)
          if ! find "$case_dir" -type f -name '*.mp4' | grep -q .; then
            echo "[FAIL] $case_id video 未生成 mp4" >&2
            echo "日志: $log_file" >&2
            FAILED=$((FAILED + 1))
            continue
          fi
          ;;
        audio)
          if ! find "$case_dir" -type f -name '*.mp3' | grep -q .; then
            echo "[FAIL] $case_id audio 未生成 mp3" >&2
            echo "日志: $log_file" >&2
            FAILED=$((FAILED + 1))
            continue
          fi
          ;;
        subtitle|whisper)
          if ! find "$case_dir" -type f -name '*.txt' | grep -q .; then
            echo "[FAIL] $case_id $MODE 未生成 txt" >&2
            echo "日志: $log_file" >&2
            FAILED=$((FAILED + 1))
            continue
          fi
          ;;
      esac

      echo "[PASS] $case_id download-$MODE"
      PASSED=$((PASSED + 1))
      ;;
    summary)
      INSTRUCTION="$ARG3"
      EXPECTED_PROFILE="${ARG4:-fast}"
      RUN_TYPE="${ARG5:-extract}"

      selection_cmd=(bash "$EXTRACT_SCRIPT" "$URL" "$case_dir/selection" auto --quality auto --check-deps)
      if [[ -n "$INSTRUCTION" ]]; then
        selection_cmd+=(--instruction "$INSTRUCTION")
      fi

      set +e
      selection_output="$("${selection_cmd[@]}" 2>&1)"
      selection_code=$?
      set -e
      printf "[selection]\n%s\n" "$selection_output" >"$log_file"

      if [[ "$selection_code" -ne 0 ]]; then
        echo "[FAIL] $case_id 选档检查失败" >&2
        echo "日志: $log_file" >&2
        FAILED=$((FAILED + 1))
        continue
      fi

      selected_profile="$(printf "%s\n" "$selection_output" | sed -n 's/^whisper_profile=//p' | tail -n1)"
      selected_run_dir="$(printf "%s\n" "$selection_output" | sed -n 's/^run_dir=//p' | tail -n1)"
      if [[ "$selected_profile" != "$EXPECTED_PROFILE" ]]; then
        echo "[FAIL] $case_id 选档不符合预期（expect=$EXPECTED_PROFILE actual=$selected_profile）" >&2
        echo "日志: $log_file" >&2
        FAILED=$((FAILED + 1))
        continue
      fi

      if [[ -z "$selected_run_dir" || "$selected_run_dir" != "$case_dir/selection/"* ]]; then
        echo "[FAIL] $case_id 选档阶段 run_dir 异常（actual=$selected_run_dir）" >&2
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
      printf "[selection]\n%s\n\n[extract]\n%s\n" "$selection_output" "$extract_output" >"$log_file"

      if [[ "$extract_code" -ne 0 ]]; then
        echo "[FAIL] $case_id 文本提取失败" >&2
        echo "日志: $log_file" >&2
        FAILED=$((FAILED + 1))
        continue
      fi

      text_path="$(printf "%s\n" "$extract_output" | sed -n 's/^text_path=//p' | tail -n1)"
      run_dir="$(printf "%s\n" "$extract_output" | sed -n 's/^run_dir=//p' | tail -n1)"
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

      if [[ "$text_path" == *" "* || "$run_dir" == *" "* ]]; then
        echo "[FAIL] $case_id 路径包含空格" >&2
        echo "日志: $log_file" >&2
        FAILED=$((FAILED + 1))
        continue
      fi

      if [[ -z "$run_dir" || ! -d "$run_dir" || "$text_path" != "$run_dir/"* ]]; then
        echo "[FAIL] $case_id run_dir 或 text_path 归位异常" >&2
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

      summary_request="$run_dir/summary_request.md"
      set +e
      summary_output="$(bash "$SUMMARY_SCRIPT" "$URL" "$video_title" "$duration_sec" "$text_path" >"$summary_request" 2>&1)"
      summary_code=$?
      set -e
      printf "\n[summary_request]\n%s\n" "$summary_output" >> "$log_file"

      if [[ "$summary_code" -ne 0 || ! -f "$summary_request" ]]; then
        echo "[FAIL] $case_id 摘要请求包生成失败" >&2
        echo "日志: $log_file" >&2
        FAILED=$((FAILED + 1))
        continue
      fi

      if ! rg -q '^## 摘要概述$' "$summary_request" || ! rg -q '^## 附件$' "$summary_request"; then
        echo "[FAIL] $case_id 摘要请求包缺少结构约束" >&2
        echo "日志: $log_file" >&2
        FAILED=$((FAILED + 1))
        continue
      fi

      summary_result="$run_dir/summary_result.md"
      printf '## 摘要概述\n- [00:12] 示例摘要。\n\n## 附件\n- 原始视频：%s\n- 转写文本：%s\n' "$URL" "$text_path" > "$summary_result"

      background_expand="$run_dir/background_request_expand.md"
      set +e
      expand_output="$(bash "$BACKGROUND_SCRIPT" "$URL" "$video_title" "$summary_result" "$text_path" --mode expand --news off >"$background_expand" 2>&1)"
      expand_code=$?
      set -e
      printf "\n[background_expand]\n%s\n" "$expand_output" >> "$log_file"

      if [[ "$expand_code" -ne 0 || ! -f "$background_expand" ]]; then
        echo "[FAIL] $case_id expand 背景请求包生成失败" >&2
        echo "日志: $log_file" >&2
        FAILED=$((FAILED + 1))
        continue
      fi

      if ! rg -q '## 相关影响和背景分析' "$background_expand" || ! rg -q '背景知识补充（约2/3）' "$background_expand"; then
        echo "[FAIL] $case_id expand 背景请求包缺少章节结构" >&2
        echo "日志: $log_file" >&2
        FAILED=$((FAILED + 1))
        continue
      fi

      background_only="$run_dir/background_request_only.md"
      set +e
      only_output="$(bash "$BACKGROUND_SCRIPT" "$URL" "$video_title" "-" "$text_path" --mode background-only --news off >"$background_only" 2>&1)"
      only_code=$?
      set -e
      printf "\n[background_only]\n%s\n" "$only_output" >> "$log_file"

      if [[ "$only_code" -ne 0 || ! -f "$background_only" ]]; then
        echo "[FAIL] $case_id background-only 请求包生成失败" >&2
        echo "日志: $log_file" >&2
        FAILED=$((FAILED + 1))
        continue
      fi

      if ! rg -q '## 上下文背景' "$background_only" || ! rg -q '关键背景脉络' "$background_only"; then
        echo "[FAIL] $case_id background-only 请求包缺少章节结构" >&2
        echo "日志: $log_file" >&2
        FAILED=$((FAILED + 1))
        continue
      fi

      echo "[PASS] $case_id summary-extract"
      PASSED=$((PASSED + 1))
      ;;
    *)
      echo "[FAIL] $case_id 未知 kind: $KIND" >&2
      FAILED=$((FAILED + 1))
      ;;
  esac
done < "$CONFIG"

# --- 离线 stub 测试：不依赖真实网络，验证核心控制流 ---

STUB_DIR="$(mktemp -d "${TMPDIR:-/tmp}/feipi-video-stub.XXXXXX")"

# 加载真实 lib 函数，而非重复正则
YT_RETRY_POLICY_LIB="$SCRIPT_DIR/lib/youtube_retry_policy.sh"
if [[ ! -r "$YT_RETRY_POLICY_LIB" ]]; then
  echo "缺少 YouTube retry policy lib: $YT_RETRY_POLICY_LIB" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$YT_RETRY_POLICY_LIB"

stub_pass() {
  TOTAL=$((TOTAL + 1))
  PASSED=$((PASSED + 1))
  echo "[PASS] stub-$1"
}

stub_fail_msg() {
  TOTAL=$((TOTAL + 1))
  FAILED=$((FAILED + 1))
  echo "[FAIL] stub-$1: $2" >&2
}

write_mock_log() {
  local name="$1" content="$2"
  printf "%s" "$content" > "$STUB_DIR/$name.log"
}

# 1. is_retryable_youtube_download_error 匹配 403
write_mock_log "err-403" "HTTP Error 403: Forbidden"
if is_retryable_youtube_download_error "$STUB_DIR/err-403.log"; then
  stub_pass "retryable-403"
else
  stub_fail_msg "retryable-403" "403 未被识别为可重试错误"
fi

# 2. is_retryable_youtube_download_error 匹配 "Requested format is not available"
write_mock_log "err-format-unavailable" "ERROR: [youtube] abc123: Requested format is not available."
if is_retryable_youtube_download_error "$STUB_DIR/err-format-unavailable.log"; then
  stub_pass "retryable-format-unavailable"
else
  stub_fail_msg "retryable-format-unavailable" "format unavailable 未被识别为可重试错误"
fi

# 3. is_challenge_error 不匹配纯 403（挑战错误保持独立语义）
write_mock_log "err-only-403" "HTTP Error 403: Forbidden"
if is_challenge_error "$STUB_DIR/err-only-403.log"; then
  stub_fail_msg "challenge-not-403" "纯 403 被误判为 challenge 错误"
else
  stub_pass "challenge-not-403"
fi

# 4. is_challenge_error 匹配 n challenge solving failed
write_mock_log "err-challenge" "WARNING: [youtube] n challenge solving failed"
if is_challenge_error "$STUB_DIR/err-challenge.log"; then
  stub_pass "challenge-match"
else
  stub_fail_msg "challenge-match" "n challenge solving failed 未被识别"
fi

# 5. 普通无字幕日志不触发认证/可重试错误
write_mock_log "err-no-subtitle" "There are no subtitles for the requested languages
[SubtitlesConvertor] There aren't any subtitles to convert"
if rg -qi "Sign in to confirm|confirm you're not a bot|HTTP Error 429|403 Forbidden|Subtitles are only available when logged in" "$STUB_DIR/err-no-subtitle.log"; then
  stub_fail_msg "no-subtitle-not-auth" "普通无字幕被误判为认证问题"
else
  stub_pass "no-subtitle-not-auth"
fi

# 6. "Only images are available" 同时匹配 is_challenge_error 和 is_retryable
write_mock_log "err-only-images" "WARNING: Only images are available for download. use --list-formats to see them"
if is_challenge_error "$STUB_DIR/err-only-images.log" && is_retryable_youtube_download_error "$STUB_DIR/err-only-images.log"; then
  stub_pass "only-images-both"
else
  stub_fail_msg "only-images-both" "Only images are available 应同时匹配 challenge 和 retryable"
fi

# 7. HTTP Error 429 匹配可重试错误
write_mock_log "err-429" "ERROR: HTTP Error 429: Too Many Requests"
if is_retryable_youtube_download_error "$STUB_DIR/err-429.log"; then
  stub_pass "retryable-429"
else
  stub_fail_msg "retryable-429" "429 未被识别为可重试错误"
fi

# --- 测试 1：client fallback 顺序验证 ---
# 加载公共 lib（yt_common_run_cmd 等需要 yt_dlp_common.sh）。
source "$SCRIPT_DIR/lib/yt_dlp_common.sh"

# 定义 run_with_client_fallbacks 的内联副本（避免 source download_youtube.sh 的副作用）。
# shellcheck disable=SC2317
run_with_client_fallbacks_test() {
  local err_file="$1"
  shift
  local client
  local idx
  idx="$YT_CURRENT_CLIENT_IDX"
  while [[ "$idx" -lt $(( ${#YT_CLIENT_FALLBACKS[@]} - 1 )) ]]; do
    idx=$(( idx + 1 ))
    client="${YT_CLIENT_FALLBACKS[$idx]}"
    YT_CLIENT_TRIED+=("$client")
    echo "client_fallback: 切换到 youtube:player_client=$client" >&2
    if yt_common_run_cmd "$err_file" \
      --remote-components "ejs:github" \
      --extractor-args "youtube:player_client=$client" \
      "$@"; then
      YT_CURRENT_CLIENT_IDX="$idx"
      return 0
    fi
  done
  return 1
}

# mock yt_common_run_cmd 总是失败，记录实际尝试的 client。
STUB_DIR_CLIENT="$STUB_DIR/client-fallback"
mkdir -p "$STUB_DIR_CLIENT"

# 覆盖 source 产生的 YT_CLIENT_FALLBACKS / YT_CURRENT_CLIENT_IDX / YT_CLIENT_TRIED。
YT_CLIENT_FALLBACKS=("web_safari" "ios" "web")
YT_CURRENT_CLIENT_IDX=-1
YT_CLIENT_TRIED=()

MOCK_RUN_CMD_CLIENT="$STUB_DIR_CLIENT/mock_run_cmd.sh"
cat > "$MOCK_RUN_CMD_CLIENT" << 'CLIENT_MOCK'
#!/usr/bin/env bash
# 从参数中提取 player_client 值
for arg in "$@"; do
  if [[ "$arg" == *player_client=* ]]; then
    echo "${arg#*player_client=}" >> "$(dirname "$0")/.clients-tried"
  fi
done
exit 1
CLIENT_MOCK
chmod +x "$MOCK_RUN_CMD_CLIENT"

# 覆盖 yt_common_run_cmd
yt_common_run_cmd() {
  local err_file="$1"; shift
  "$MOCK_RUN_CMD_CLIENT" "$@" 2>"$err_file"
  return $?
}

: > "$STUB_DIR_CLIENT/.clients-tried"
YT_CURRENT_CLIENT_IDX=-1
YT_CLIENT_TRIED=()

run_with_client_fallbacks_test "/tmp/err" "https://youtube.com/watch?v=test" 2>/dev/null || true

clients_tried=()
while IFS= read -r c; do
  clients_tried+=("$c")
done < "$STUB_DIR_CLIENT/.clients-tried"

if [[ ${#clients_tried[@]} -ge 3 && "${clients_tried[0]}" == "web_safari" && "${clients_tried[1]}" == "ios" && "${clients_tried[2]}" == "web" ]]; then
  stub_pass "client-fallback-order"
else
  stub_fail_msg "client-fallback-order" "clients_tried=${clients_tried[*]:-<empty>}，预期 web_safari → ios → web"
fi

# 测试 1b：AGENT_YOUTUBE_ENABLE_ANDROID_VR_FALLBACK=1 时 android_vr 出现在最后。
if [[ "${AGENT_YOUTUBE_ENABLE_ANDROID_VR_FALLBACK:-0}" != "1" ]]; then
  YT_CLIENT_FALLBACKS=("web_safari" "ios" "web" "android_vr")
  YT_CURRENT_CLIENT_IDX=-1
  YT_CLIENT_TRIED=()
  CLIENTS_TRIED_FILE="$STUB_DIR_CLIENT/.clients-tried-vr"
  : > "$CLIENTS_TRIED_FILE"

  yt_common_run_cmd() {
    local err_file="$1"; shift
    for arg in "$@"; do
      if [[ "$arg" == *player_client=* ]]; then
        echo "${arg#*player_client=}" >> "$CLIENTS_TRIED_FILE"
      fi
    done
    return 1
  }

  run_with_client_fallbacks_test "/tmp/err" "https://youtube.com/watch?v=test" 2>/dev/null || true

  clients_tried=()
  while IFS= read -r c; do
    clients_tried+=("$c")
  done < "$CLIENTS_TRIED_FILE"
  if [[ ${#clients_tried[@]} -gt 0 ]]; then
    last_client="${clients_tried[$(( ${#clients_tried[@]} - 1 ))]}"
  else
    last_client="<empty>"
  fi
  if [[ "$last_client" == "android_vr" ]]; then
    stub_pass "client-fallback-android-vr-last"
  else
    stub_fail_msg "client-fallback-android-vr-last" "最后一个 client=$last_client，预期 android_vr"
  fi
fi

# --- 测试 2：dryrun 不污染 stdout ---
STUB_DIR_DRYRUN="$STUB_DIR/dryrun-stdout"
mkdir -p "$STUB_DIR_DRYRUN"

# mock yt-dlp：stdout 输出标题和 ID，stderr 输出诊断 warning。
MOCK_YTDLP_DRYRUN="$STUB_DIR_DRYRUN/mock-yt-dlp"
cat > "$MOCK_YTDLP_DRYRUN" << 'DRYRUN_MOCK'
#!/usr/bin/env bash
echo "Fake Title"
echo "fake_id"
echo "WARNING: diagnostic" >&2
exit 0
DRYRUN_MOCK
chmod +x "$MOCK_YTDLP_DRYRUN"

yt_common_run_cmd() {
  local err_file="$1"; shift
  "$MOCK_YTDLP_DRYRUN" "$@" 2>"$err_file"
}

YT_COMMON_ARGS=(--no-playlist --restrict-filenames)
YT_COMMON_AUTH_ARGS=()

output="$(yt_common_mode_dryrun "https://youtube.com/watch?v=test")"

if printf "%s\n" "$output" | grep -qF "WARNING: diagnostic"; then
  stub_fail_msg "dryrun-no-stdout-pollution" "stdout 包含 'WARNING: diagnostic'，yt_common_run 成功时将 err_file 输出到 stdout"
else
  if printf "%s\n" "$output" | grep -qF "Fake Title" && printf "%s\n" "$output" | grep -qF "fake_id"; then
    stub_pass "dryrun-no-stdout-pollution"
  else
    stub_fail_msg "dryrun-no-stdout-pollution" "stdout 缺少 Fake Title 或 fake_id，输出: $output"
  fi
fi

# --- 测试 3（增强）：whisper 音频路径回填 —— 完整函数调用 ---
STUB_DIR_BACKFILL="$STUB_DIR/full-backfill"
mkdir -p "$STUB_DIR_BACKFILL"

# 创建已存在的 mp3 文件
EXISTING_MP3="$STUB_DIR_BACKFILL/existing_test.mp3"
echo "fake audio" > "$EXISTING_MP3"

# mock yt-dlp：输出已下载消息到 stderr，模拟文件已存在。
MOCK_YTDLP_BACKFILL="$STUB_DIR_BACKFILL/mock-yt-dlp"
cat > "$MOCK_YTDLP_BACKFILL" << BACKFILL_MOCK
#!/usr/bin/env bash
echo "[download] $EXISTING_MP3 has already been downloaded" >&2
exit 0
BACKFILL_MOCK
chmod +x "$MOCK_YTDLP_BACKFILL"

# 覆盖 yt_common_run_cmd 使用 mock
yt_common_run_cmd() {
  local err_file="$1"; shift
  "$MOCK_YTDLP_BACKFILL" "$@" 2>"$err_file"
}

YT_COMMON_ARGS=(--no-playlist --restrict-filenames --output "$STUB_DIR_BACKFILL/%(title).200B [%(id)s].%(ext)s")
YT_COMMON_AUTH_ARGS=()

# mock ffmpeg：创建目标 wav 文件并返回 0。
ffmpeg() {
  touch "$STUB_DIR_BACKFILL/existing_test.whisper.wav"
  return 0
}

# mock whisper helper：创建预期的 .srt 和 .txt 文件，并输出诊断信息到日志。
MOCK_WHISPER="$STUB_DIR_BACKFILL/mock-whispercpp.sh"
cat > "$MOCK_WHISPER" << 'WHISPER_MOCK'
#!/usr/bin/env bash
transcribe_audio="$1"
output_prefix="$2"
srt_file="$output_prefix.srt"
text_file="$output_prefix.txt"
echo "requested_profile=fast"
echo "profile=fast"
echo "model=mock"
echo "device=mock"
echo "[mock whisper output]" > "$srt_file"
echo "- [00:00] mock transcript text" > "$text_file"
exit 0
WHISPER_MOCK
chmod +x "$MOCK_WHISPER"

output="$(yt_common_run_whisper_mode_from_url "https://youtube.com/watch?v=test" "$STUB_DIR_BACKFILL" "$MOCK_WHISPER" "zh" "fast")"
backfill_code=$?

if [[ "$backfill_code" -ne 0 ]]; then
  stub_fail_msg "full-whisper-backfill" "yt_common_run_whisper_mode_from_url 返回非零：$backfill_code"
elif printf "%s\n" "$output" | grep -qF "audio_file=$EXISTING_MP3"; then
  if printf "%s\n" "$output" | grep -q '^text_file='; then
    stub_pass "full-whisper-backfill"
  else
    stub_fail_msg "full-whisper-backfill" "输出缺少 text_file= 行"
  fi
else
  stub_fail_msg "full-whisper-backfill" "输出缺少 audio_file=$EXISTING_MP3，实际输出：$output"
fi

# --- 测试 4：Mock yt-dlp format fallback 控制流测试 ---
#    模拟第一次 bestaudio[abr<=96]/bestaudio 返回 403，第二次 format 18 成功。
MOCK_YTDLP="$STUB_DIR/mock-yt-dlp"
MOCK_OUT_DIR="$STUB_DIR/mock-out"
mkdir -p "$MOCK_OUT_DIR"

# 计数器文件记录调用次数，每次调用 +1 并按序号返回不同行为。
CALL_COUNTER="$STUB_DIR/.call-counter"
FORMAT_LOG="$STUB_DIR/.format-log"
echo "0" > "$CALL_COUNTER"
: > "$FORMAT_LOG"

cat > "$MOCK_YTDLP" << 'MOCK_EOF'
#!/usr/bin/env bash
counter_file="$(dirname "$0")/.call-counter"
format_log="$(dirname "$0")/.format-log"
count="$(cat "$counter_file")"
echo $(( count + 1 )) > "$counter_file"

# 解析参数
output=""
format_val=""
extract_audio=0
audio_format=""
for arg in "$@"; do
  case "$arg" in
    --output) output_next=1 ;;
    --format) format_next=1 ;;
    --extract-audio) extract_audio=1 ;;
    --audio-format) audio_format_next=1 ;;
    *)
      if [[ "${output_next:-0}" -eq 1 ]]; then
        output="$arg"
        output_next=0
      fi
      if [[ "${format_next:-0}" -eq 1 ]]; then
        format_val="$arg"
        format_next=0
      fi
      if [[ "${audio_format_next:-0}" -eq 1 ]]; then
        audio_format="$arg"
        audio_format_next=0
      fi
      ;;
  esac
done

# 记录每次使用的 format 参数
if [[ -n "$format_val" ]]; then
  echo "$format_val" >> "$format_log"
fi

# 第一次调用：返回 403 错误
if [[ "$count" -eq 0 ]]; then
  echo "ERROR: HTTP Error 403: Forbidden" >&2
  exit 1
fi

# 第二次调用：模拟成功下载，输出目标文件路径
# 解析 --extract-audio + --audio-format mp3 → 输出 .mp3
if [[ -n "$output" && "$extract_audio" -eq 1 && "$audio_format" == "mp3" ]]; then
  mp3_file="${output%.%(ext)s}.mp3"
  mkdir -p "$(dirname "$mp3_file")"
  echo "fake mp3 content" > "$mp3_file"
  echo "[download] Destination: $mp3_file" >&2
fi
exit 0
MOCK_EOF
chmod +x "$MOCK_YTDLP"

# 将 mock-yt-dlp 注入 PATH 前端
export PATH="$STUB_DIR:$PATH"

# 准备 lib 依赖：在 mock 环境中 source yt_dlp_common.sh，但替换 yt_common_init
# 使其使用 mock-yt-dlp 而非系统 yt-dlp
YTDLP_SAVE="$(command -v yt-dlp 2>/dev/null || true)"
alias yt-dlp="$MOCK_YTDLP"

# 构造最小化测试：直接调用 yt_common_mode_whisper_audio_with_format_fallback
# 需要 source 公共 lib
source "$SCRIPT_DIR/lib/yt_dlp_common.sh"

# 重写 yt_common_run_cmd 以使用 mock（覆盖原实现中的 yt-dlp 调用）
yt_common_run_cmd() {
  local err_file="$1"
  shift
  local -a cmd
  cmd=("$MOCK_YTDLP" "${YT_COMMON_ARGS[@]}")
  if [[ ${#YT_COMMON_AUTH_ARGS[@]} -gt 0 ]]; then
    cmd+=("${YT_COMMON_AUTH_ARGS[@]}")
  fi
  cmd+=("$@")
  if [[ -n "$err_file" ]]; then
    "${cmd[@]}" 2>"$err_file"
  else
    "${cmd[@]}"
  fi
}

# 初始化（设置输出目录和 args）
yt_common_init "$MOCK_OUT_DIR" ""

# 执行 format fallback 函数
echo "0" > "$CALL_COUNTER"
: > "$FORMAT_LOG"
if yt_common_mode_whisper_audio_with_format_fallback "https://youtube.com/watch?v=test"; then
  call_count="$(cat "$CALL_COUNTER")"
  if [[ "$call_count" -ge 2 ]]; then
    # 验证 format 顺序：前两次正好是 bestaudio[abr<=96]/bestaudio 和 18
    fmt1="$(sed -n '1p' "$FORMAT_LOG")"
    fmt2="$(sed -n '2p' "$FORMAT_LOG")"
    if [[ "$fmt1" == "bestaudio[abr<=96]/bestaudio" && "$fmt2" == "18" ]]; then
      stub_pass "format-fallback-order"
    else
      stub_fail_msg "format-fallback-order" "format 顺序不符：fmt1=$fmt1, fmt2=$fmt2，预期 bestaudio[abr<=96]/bestaudio → 18"
    fi
  else
    stub_fail_msg "format-fallback-order" "调用次数=$call_count，预期≥2（先失败后成功）"
  fi
else
  call_count="$(cat "$CALL_COUNTER")"
  stub_fail_msg "format-fallback-order" "format fallback 整体失败（调用次数=$call_count）"
fi

# --- 测试 5：已存在 mp3 回填路径（sed 逻辑验证，保留作为完整函数测试的对照） ---
#    模拟 yt-dlp 输出 "has already been downloaded"，验证能从日志回填音频路径。
#    直接测试路径回填逻辑，不经过完整 whisper 流程（避免依赖真实 ffmpeg/whisper.cpp）。
ALREADY_EXISTS_DIR="$STUB_DIR/already-exists"
mkdir -p "$ALREADY_EXISTS_DIR"

# 创建一个已存在的 mp3 文件
EXISTING_MP3="$ALREADY_EXISTS_DIR/existing_test.mp3"
echo "fake audio" > "$EXISTING_MP3"

# 构造 mock：直接输出已下载消息
cat > "$MOCK_YTDLP" << MOCK_EOF2
#!/usr/bin/env bash
echo "[download] $EXISTING_MP3 has already been downloaded" >&2
exit 0
MOCK_EOF2
chmod +x "$MOCK_YTDLP"

# 重写 yt_common_run_cmd 使用 mock
yt_common_run_cmd() {
  local err_file="$1"
  shift
  "$MOCK_YTDLP" 2>"$err_file"
}

# 初始化输出目录
yt_common_init "$ALREADY_EXISTS_DIR" ""

# 模拟 yt_common_run_whisper_mode_from_url 内部的回填步骤：
# 1. audio_download_fn 产生日志
# 2. yt_common_find_new_audio_file 未找到新文件
# 3. 从日志 sed 回填路径
marker="$(mktemp "$ALREADY_EXISTS_DIR/.marker.XXXXXX")"
audio_download_log="$(mktemp "$ALREADY_EXISTS_DIR/.audio-log.XXXXXX")"

set +e
yt_common_mode_whisper_audio "https://youtube.com/watch?v=test-backfill" >"$audio_download_log" 2>&1
download_code=$?
set -e

if [[ "$download_code" -ne 0 ]]; then
  stub_fail_msg "already-exists-path-backfill" "下载函数返回非零：$download_code"
else
  audio_file="$(yt_common_find_new_audio_file "$ALREADY_EXISTS_DIR" "$marker")"

  # 若未找到新文件，从日志回填
  if [[ -z "$audio_file" ]]; then
    audio_file="$(sed -nE \
      -e 's#^\[download\] Destination: (.*)$#\1#p' \
      -e 's#^\[download\] (.*) has already been downloaded$#\1#p' \
      -e 's#^\[ExtractAudio\] Destination: (.*)$#\1#p' \
      -e 's#^\[ExtractAudio\] Not converting audio (.*)[; ].*$#\1#p' \
      "$audio_download_log" | grep '\.mp3$' | tail -n1)"
    if [[ -n "$audio_file" && ! -f "$audio_file" ]]; then
      audio_file=""
    fi
  fi

  rm -f "$audio_download_log" "$marker"

  if [[ "$audio_file" == "$EXISTING_MP3" ]]; then
    stub_pass "already-exists-path-backfill"
  else
    stub_fail_msg "already-exists-path-backfill" "audio_file=$audio_file（预期 $EXISTING_MP3）"
  fi
fi

# 清理 mock
unalias yt-dlp 2>/dev/null || true
if [[ -n "$YTDLP_SAVE" ]]; then
  export PATH="$(dirname "$YTDLP_SAVE"):$(echo "$PATH" | sed "s|$STUB_DIR:||g")"
fi

rm -rf "$STUB_DIR"

echo "测试汇总: total=$TOTAL pass=$PASSED fail=$FAILED"
if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi

echo "测试通过: feipi-video-read-url"
