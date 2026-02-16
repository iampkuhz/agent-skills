#!/usr/bin/env bash
set -euo pipefail

# YouTube 下载脚本（简化版）
#
# 用法：
#   bash scripts/download_youtube.sh <url> [output_dir] [mode]
#
# mode: video | audio | dryrun | subtitle | whisper
#
# 认证配置：
# - 仅支持 AGENT_CHROME_PROFILE（浏览器 profile）
# - 默认不提示；仅在触发 bot 检测时给出配置建议

URL="${1:-}"
OUT_DIR="${2:-./downloads}"
MODE="${3:-video}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WHISPER_HELPER="$REPO_ROOT/scripts/video/whispercpp_transcribe.sh"
YT_COMMON_LIB="$REPO_ROOT/scripts/video/yt_dlp_common.sh"

# 可选配置文件加载策略（按顺序取第一个存在的）：
# 1) AGENT_SKILL_ENV_FILE 显式指定
# 2) $CODEX_HOME/skills-config/feipi-read-youtube-video.env
# 3) ~/.config/feipi-read-youtube-video/.env
# 4) 兼容路径：skills/feipi-read-youtube-video/.env
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG_CANDIDATES=(
  "${AGENT_SKILL_ENV_FILE:-}"
  "$CODEX_HOME_DIR/skills-config/feipi-read-youtube-video.env"
  "$HOME/.config/feipi-read-youtube-video/.env"
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

# YouTube 反爬重试策略固定值（不通过环境变量暴露）。
YT_REMOTE_COMPONENTS_DEFAULT="ejs:github"
YT_EXTRACTOR_ARGS_DEFAULT="youtube:player_client=android,web_safari"
YT_BOT_HIT=0

if [[ -z "$URL" ]]; then
  echo "用法: bash scripts/download_youtube.sh <url> [output_dir] [video|audio|dryrun|subtitle|whisper]" >&2
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

is_challenge_error() {
  local err_file="$1"
  rg -qi "n challenge solving failed|Remote components challenge solver script|Only images are available|Requested format is not available|Sign in to confirm|confirm you're not a bot" "$err_file"
}

print_bot_guidance() {
  echo "检测到可能的 YouTube bot/风控拦截。" >&2
  echo "处理建议:" >&2
  echo "1) 临时方式（推荐先试）:" >&2
  echo "   export AGENT_CHROME_PROFILE='chrome:Profile 1'" >&2
  echo "2) 持久方式（二选一）:" >&2
  echo "   - $CODEX_HOME_DIR/skills-config/feipi-read-youtube-video.env" >&2
  echo "   - $HOME/.config/feipi-read-youtube-video/.env" >&2
  echo "3) 也可显式指定配置文件:" >&2
  echo "   export AGENT_SKILL_ENV_FILE='/your/path/feipi-read-youtube-video.env'" >&2
  echo "4) 配置后先执行 dryrun，再重试下载" >&2
  if [[ -n "$LOADED_ENV_FILE" ]]; then
    echo "当前已加载配置文件: $LOADED_ENV_FILE" >&2
  else
    echo "当前未加载任何配置文件。" >&2
  fi
}

# 可选回调：yt_common_run 在失败时会调用该函数。
yt_common_on_error() {
  local err_file="$1"
  shift

  # YouTube JS challenge 失败时，使用远程组件与提取器参数重试一次。
  if is_challenge_error "$err_file"; then
    if yt_common_run_cmd "$err_file" \
      --remote-components "$YT_REMOTE_COMPONENTS_DEFAULT" \
      --extractor-args "$YT_EXTRACTOR_ARGS_DEFAULT" \
      "$@"; then
      return 0
    fi
  fi

  if rg -qi "confirm you're not a bot|Sign in to confirm|403 Forbidden|HTTP Error 429" "$err_file"; then
    YT_BOT_HIT=1
    print_bot_guidance
  fi

  return 1
}

run_subtitle_mode() {
  local marker subtitle_file text_file
  local -a langs
  local lang

  marker="$(mktemp "$OUT_DIR/.subtitle-marker.XXXXXX")"

  # 优先中文字幕，再回退英文；包含自动字幕，避免无人工字幕时失败。
  langs=(zh en)
  for lang in "${langs[@]}"; do
    if yt_common_try \
      --skip-download \
      --write-subs \
      --write-auto-subs \
      --convert-subs vtt \
      --sub-langs "$lang" \
      --sub-format "vtt/srt" \
      "$URL"; then
      subtitle_file="$(yt_common_find_new_subtitle_file "$OUT_DIR" "$marker")"
      if [[ -n "$subtitle_file" ]]; then
        break
      fi
    fi
  done

  subtitle_file="$(yt_common_find_new_subtitle_file "$OUT_DIR" "$marker")"
  rm -f "$marker"

  if [[ -z "$subtitle_file" ]]; then
    if [[ "$YT_BOT_HIT" -eq 1 ]]; then
      print_bot_guidance
    fi
    echo "未获取到字幕文件（vtt/srt）。" >&2
    return 1
  fi

  text_file="${subtitle_file%.*}.txt"
  yt_common_subtitle_to_text "$subtitle_file" "$text_file"
  echo "完成: mode=subtitle, subtitle=$subtitle_file, text=$text_file"
}

run_whisper_mode() {
  local whisper_log used_device audio_file text_file

  whisper_log="$(mktemp "$OUT_DIR/.whisper-mode.XXXXXX")"
  if ! yt_common_run_whisper_mode_from_url "$URL" "$OUT_DIR" "$WHISPER_HELPER" zh >"$whisper_log" 2>&1; then
    cat "$whisper_log"
    rm -f "$whisper_log"
    return 1
  fi

  cat "$whisper_log"
  used_device="$(sed -n 's/^device=//p' "$whisper_log" | tail -n1)"
  audio_file="$(sed -n 's/^audio_file=//p' "$whisper_log" | tail -n1)"
  text_file="$(sed -n 's/^text_file=//p' "$whisper_log" | tail -n1)"
  rm -f "$whisper_log"

  if [[ -z "$used_device" ]]; then
    used_device="unknown"
  fi

  echo "完成: mode=whisper, engine=whisper.cpp, device=$used_device, audio=$audio_file, text=$text_file"
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
