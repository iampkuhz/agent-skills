#!/usr/bin/env bash
set -euo pipefail

# Bilibili 下载脚本（简化版）
#
# 用法：
#   bash scripts/download_bilibili.sh <url> [output_dir] [mode] [whisper_profile]
#
# mode: video | audio | dryrun | subtitle | whisper
# whisper_profile: auto | fast | accurate（仅 mode=whisper 时生效）
#
# 样例（whisper 快/慢档）：
#   bash scripts/download_bilibili.sh "<bilibili_url>" "./downloads" whisper fast
#   bash scripts/download_bilibili.sh "<bilibili_url>" "./downloads" whisper accurate
#
# 认证配置：
# - 仅支持 AGENT_CHROME_PROFILE（浏览器 profile）
# - 默认不提示；仅在触发权限/风控问题时给出配置建议

URL="${1:-}"
OUT_DIR_RAW="${2:-./downloads}"
MODE="${3:-video}"
WHISPER_PROFILE="${4:-auto}"

normalize_out_dir() {
  local raw="$1"
  if [[ "$raw" == "~" ]]; then
    echo "$HOME"
    return 0
  fi
  if [[ "$raw" == "~/"* ]]; then
    echo "$HOME/${raw:2}"
    return 0
  fi
  echo "$raw"
}

OUT_DIR="$(normalize_out_dir "$OUT_DIR_RAW")"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WHISPER_HELPER="$REPO_ROOT/scripts/video/whispercpp_transcribe.sh"
YT_COMMON_LIB="$REPO_ROOT/scripts/video/yt_dlp_common.sh"

# 可选配置文件加载策略（按顺序取第一个存在的）：
# 1) AGENT_SKILL_ENV_FILE 显式指定
# 2) $CODEX_HOME/skills-config/feipi-read-bilibili-video.env
# 3) ~/.config/feipi-read-bilibili-video/.env
# 4) 兼容路径：skills/feipi-read-bilibili-video/.env
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG_CANDIDATES=(
  "${AGENT_SKILL_ENV_FILE:-}"
  "$CODEX_HOME_DIR/skills-config/feipi-read-bilibili-video.env"
  "$HOME/.config/feipi-read-bilibili-video/.env"
  "$SKILL_DIR/.env"
)

LOADED_ENV_FILE=""
for f in "${CONFIG_CANDIDATES[@]}"; do
  if [[ -n "$f" && -f "$f" ]]; then
    # shellcheck disable=SC1090
    set -a
    source "$f"
    set +a
    LOADED_ENV_FILE="$f"
    break
  fi
done

AGENT_CHROME_PROFILE="${AGENT_CHROME_PROFILE:-}"
BILI_AUTH_HIT=0
WHISPER_AUTO_ACCURATE_MAX_SEC=480

if [[ -z "$URL" ]]; then
  echo "用法: bash scripts/download_bilibili.sh <url> [output_dir] [video|audio|dryrun|subtitle|whisper] [auto|fast|accurate]" >&2
  exit 1
fi

if [[ "$WHISPER_PROFILE" != "auto" && "$WHISPER_PROFILE" != "fast" && "$WHISPER_PROFILE" != "accurate" ]]; then
  echo "whisper_profile 仅支持 auto|fast|accurate，当前: $WHISPER_PROFILE" >&2
  exit 1
fi

if [[ ! -r "$YT_COMMON_LIB" ]]; then
  echo "缺少仓库级通用脚本: $YT_COMMON_LIB" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$YT_COMMON_LIB"

yt_common_require_tools "$MODE"
yt_common_init "$OUT_DIR" "$AGENT_CHROME_PROFILE"

print_auth_guidance() {
  echo "检测到可能的 Bilibili 权限限制或风控拦截。" >&2
  echo "处理建议:" >&2
  echo "1) 临时方式（推荐先试）:" >&2
  echo "   export AGENT_CHROME_PROFILE='chrome:Profile 1'" >&2
  echo "2) 持久方式（二选一）:" >&2
  echo "   - $CODEX_HOME_DIR/skills-config/feipi-read-bilibili-video.env" >&2
  echo "   - $HOME/.config/feipi-read-bilibili-video/.env" >&2
  echo "3) 也可显式指定配置文件:" >&2
  echo "   export AGENT_SKILL_ENV_FILE='/your/path/feipi-read-bilibili-video.env'" >&2
  echo "4) 配置后先执行 dryrun，再重试下载" >&2
  if [[ -n "$LOADED_ENV_FILE" ]]; then
    echo "当前已加载配置文件: $LOADED_ENV_FILE" >&2
  else
    echo "当前未加载任何配置文件。" >&2
  fi
}

is_auth_related_error() {
  local err_file="$1"
  rg -qi "login required|logged in|Subtitles are only available when logged in|会员|大会员|403 Forbidden|HTTP Error 403|HTTP Error 412|HTTP Error 429|Too Many Requests|请先登录|限地区" "$err_file"
}

# 可选回调：yt_common_run 在失败时会调用该函数。
yt_common_on_error() {
  local err_file="$1"
  shift

  if is_auth_related_error "$err_file"; then
    BILI_AUTH_HIT=1
    print_auth_guidance
  fi

  return 1
}

precheck_subtitle_auth() {
  local check_file
  check_file="$(mktemp)"

  # list-subs 主要用于探测是否存在“需登录才有字幕”的限制。
  yt_common_run_cmd "$check_file" --skip-download --list-subs "$URL" || true

  if is_auth_related_error "$check_file"; then
    BILI_AUTH_HIT=1
    print_auth_guidance
    cat "$check_file" >&2
    rm -f "$check_file"
    return 1
  fi

  rm -f "$check_file"
  return 0
}

run_subtitle_mode() {
  local marker subtitle_file text_file danmaku_file

  marker="$(mktemp "$OUT_DIR/.subtitle-marker.XXXXXX")"

  if ! precheck_subtitle_auth; then
    rm -f "$marker"
    return 1
  fi

  # 一次请求覆盖常见中英字幕标签，减少多次重试带来的耗时。
  yt_common_try \
    --skip-download \
    --write-subs \
    --write-auto-subs \
    --convert-subs vtt \
    --sub-langs "zh-TW,zh-Hant,zh-HK,zh-Hans,zh-CN,zh,ai-zh,ai-en,en" \
    --sub-format "vtt/srt" \
    "$URL" || true
  subtitle_file="$(yt_common_find_new_subtitle_file "$OUT_DIR" "$marker")"

  # 最后兜底：直接拉取全部字幕语言，避免站点语言标签差异导致漏抓。
  if [[ -z "$subtitle_file" ]]; then
    yt_common_try \
      --skip-download \
      --write-subs \
      --write-auto-subs \
      --convert-subs vtt \
      --sub-langs "all" \
      --sub-format "vtt/srt" \
      "$URL" || true
    subtitle_file="$(yt_common_find_new_subtitle_file "$OUT_DIR" "$marker")"
  fi

  subtitle_file="$(yt_common_find_new_subtitle_file "$OUT_DIR" "$marker")"
  danmaku_file="$(yt_common_find_new_danmaku_file "$OUT_DIR" "$marker")"
  rm -f "$marker"

  if [[ -z "$subtitle_file" ]]; then
    if [[ "$BILI_AUTH_HIT" -eq 1 ]]; then
      print_auth_guidance
    fi
    if [[ -n "$danmaku_file" ]]; then
      echo "仅检测到弹幕文件（${danmaku_file}），未获取到标准字幕（vtt/srt）。" >&2
      echo "建议改用 whisper 模式做语音转写。" >&2
    else
      echo "未获取到字幕文件（vtt/srt）。" >&2
    fi
    return 1
  fi

  text_file="${subtitle_file%.*}.txt"
  yt_common_subtitle_to_text "$subtitle_file" "$text_file"
  echo "完成: mode=subtitle, subtitle=$subtitle_file, text=$text_file"
}

run_whisper_mode() {
  local whisper_log used_device used_profile used_model audio_file text_file
  local resolved_profile profile_reason profile_pair

  resolve_whisper_profile_auto() {
    local requested="$1"
    local duration_raw duration_int

    if [[ "$requested" != "auto" ]]; then
      echo "$requested|explicit"
      return 0
    fi

    set +e
    duration_raw="$(yt-dlp --skip-download --no-playlist --print "%(duration)s" "$URL" 2>/dev/null | head -n1)"
    set -e

    if [[ "$duration_raw" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      duration_int="${duration_raw%.*}"
      if (( duration_int <= WHISPER_AUTO_ACCURATE_MAX_SEC )); then
        echo "accurate|auto_duration_short_${duration_int}s"
      else
        echo "fast|auto_duration_long_${duration_int}s"
      fi
      return 0
    fi

    # 无法获取时长时默认快档，优先保障速度。
    echo "fast|auto_duration_unknown_default_fast"
  }

  profile_pair="$(resolve_whisper_profile_auto "$WHISPER_PROFILE")"
  resolved_profile="${profile_pair%%|*}"
  profile_reason="${profile_pair#*|}"

  whisper_log="$(mktemp "$OUT_DIR/.whisper-mode.XXXXXX")"
  if ! yt_common_run_whisper_mode_from_url "$URL" "$OUT_DIR" "$WHISPER_HELPER" zh "$resolved_profile" >"$whisper_log" 2>&1; then
    cat "$whisper_log"
    rm -f "$whisper_log"
    return 1
  fi

  cat "$whisper_log"
  used_device="$(sed -n 's/^device=//p' "$whisper_log" | tail -n1)"
  used_profile="$(sed -n 's/^profile=//p' "$whisper_log" | tail -n1)"
  used_model="$(sed -n 's/^model=//p' "$whisper_log" | tail -n1)"
  audio_file="$(sed -n 's/^audio_file=//p' "$whisper_log" | tail -n1)"
  text_file="$(sed -n 's/^text_file=//p' "$whisper_log" | tail -n1)"
  rm -f "$whisper_log"

  if [[ -z "$used_device" ]]; then
    used_device="unknown"
  fi
  if [[ -z "$used_profile" ]]; then
    used_profile="unknown"
  fi
  if [[ -z "$used_model" ]]; then
    used_model="unknown"
  fi

  echo "whisper_profile_requested=$WHISPER_PROFILE"
  echo "whisper_profile_resolved=$resolved_profile"
  echo "whisper_profile_reason=$profile_reason"
  echo "完成: mode=whisper, engine=whisper.cpp, profile=$used_profile, model=$used_model, device=$used_device, audio=$audio_file, text=$text_file"
}

case "$MODE" in
  dryrun)
    yt_common_mode_dryrun "$URL"
    ;;
  audio)
    yt_common_mode_audio "$URL"
    ;;
  video)
    yt_common_mode_video "$URL"
    ;;
  subtitle)
    run_subtitle_mode
    ;;
  whisper)
    run_whisper_mode
    ;;
  *)
    echo "不支持的 mode: $MODE (可选: video|audio|dryrun|subtitle|whisper)" >&2
    exit 1
    ;;
esac

echo "完成: mode=$MODE, output_dir=$OUT_DIR"
