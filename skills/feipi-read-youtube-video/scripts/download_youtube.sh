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
AGENT_YT_REMOTE_COMPONENTS="${AGENT_YT_REMOTE_COMPONENTS:-ejs:github}"
AGENT_YT_EXTRACTOR_ARGS="${AGENT_YT_EXTRACTOR_ARGS:-youtube:player_client=android,web_safari}"

if [[ -z "$URL" ]]; then
  echo "用法: bash scripts/download_youtube.sh <url> [output_dir] [video|audio|dryrun|subtitle|whisper]" >&2
  exit 1
fi

if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "缺少依赖: yt-dlp" >&2
  echo "安装示例: brew install yt-dlp" >&2
  exit 1
fi

if [[ "$MODE" =~ ^(video|audio|whisper)$ ]] && ! command -v ffmpeg >/dev/null 2>&1; then
  echo "缺少依赖: ffmpeg" >&2
  echo "安装示例: brew install ffmpeg" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

OUTPUT_TEMPLATE="$OUT_DIR/%(title).200B [%(id)s].%(ext)s"
COMMON_ARGS=(
  --no-playlist
  --restrict-filenames
  --output "$OUTPUT_TEMPLATE"
)

AUTH_ARGS=()
if [[ -n "$AGENT_CHROME_PROFILE" ]]; then
  AUTH_ARGS+=(--cookies-from-browser "$AGENT_CHROME_PROFILE")
fi

is_challenge_error() {
  local err_file="$1"
  rg -qi "n challenge solving failed|Remote components challenge solver script|Only images are available|Requested format is not available|Sign in to confirm|confirm you're not a bot" "$err_file"
}

run_yt_dlp() {
  local -a cmd
  local -a retry_cmd
  local err_file

  err_file="$(mktemp)"
  cmd=(yt-dlp "${COMMON_ARGS[@]}")
  if [[ ${#AUTH_ARGS[@]} -gt 0 ]]; then
    cmd+=("${AUTH_ARGS[@]}")
  fi
  cmd+=("$@")

  if ! "${cmd[@]}" 2>"$err_file"; then
    # YouTube JS challenge 失败时，使用远程组件与提取器参数重试一次。
    if is_challenge_error "$err_file"; then
      retry_cmd=(yt-dlp "${COMMON_ARGS[@]}")
      if [[ ${#AUTH_ARGS[@]} -gt 0 ]]; then
        retry_cmd+=("${AUTH_ARGS[@]}")
      fi
      if [[ -n "$AGENT_YT_REMOTE_COMPONENTS" ]]; then
        retry_cmd+=(--remote-components "$AGENT_YT_REMOTE_COMPONENTS")
      fi
      if [[ -n "$AGENT_YT_EXTRACTOR_ARGS" ]]; then
        retry_cmd+=(--extractor-args "$AGENT_YT_EXTRACTOR_ARGS")
      fi
      retry_cmd+=("$@")
      if "${retry_cmd[@]}" 2>"$err_file"; then
        rm -f "$err_file"
        return 0
      fi
    fi

    if rg -qi "confirm you're not a bot|Sign in to confirm|403 Forbidden|HTTP Error 429" "$err_file"; then
      print_bot_guidance
    fi

    cat "$err_file" >&2
    rm -f "$err_file"
    return 1
  fi

  rm -f "$err_file"
  return 0
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

normalize_timestamp() {
  local raw="$1"
  raw="$(echo "$raw" | sed 's/,/./g; s/[[:space:]]//g')"
  if [[ "$raw" =~ ^([0-9]+):([0-9]{2}):([0-9]{2})(\.[0-9]+)?$ ]]; then
    printf "%02d:%02d:%02d" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    return 0
  fi
  if [[ "$raw" =~ ^([0-9]+):([0-9]{2})(\.[0-9]+)?$ ]]; then
    printf "%02d:%02d" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi
  printf "00:00"
}

subtitle_to_text() {
  local subtitle_file="$1"
  local text_file="$2"
  awk '
    BEGIN {
      IGNORECASE=1
      current_ts=""
      last_out_ts=""
    }
    /^[[:space:]]*$/ { next }
    /^WEBVTT/ { next }
    /^NOTE/ { next }
    /^[0-9]+$/ { next }
    /-->/ {
      ts=$1
      gsub(/,/, ".", ts)
      gsub(/[[:space:]]/, "", ts)
      split(ts, a, ":")
      if (length(a)==3) {
        current_ts=sprintf("%02d:%02d:%02d", a[1]+0, a[2]+0, int(a[3]))
      } else if (length(a)==2) {
        current_ts=sprintf("%02d:%02d", a[1]+0, a[2]+0)
      } else {
        current_ts="00:00"
      }
      next
    }
    {
      line=$0
      gsub(/\r/, "", line)
      gsub(/<[^>]*>/, "", line)
      gsub(/[[:space:]]+/, " ", line)
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line=="") next
      if (line ~ /^(Kind:|Language:|Source:|Style:)/) next
      if (current_ts=="") current_ts="00:00"
      if (current_ts != last_out_ts) {
        print "- [" current_ts "] " line
        last_out_ts=current_ts
      } else {
        print "  " line
      }
    }
  ' "$subtitle_file" > "$text_file"
}

run_subtitle_mode() {
  local marker subtitle_file text_file
  local -a langs
  local lang err_file
  local bot_hit=0
  local any_try=0
  marker="$(mktemp "$OUT_DIR/.subtitle-marker.XXXXXX")"

  # 优先中文字幕，再回退英文；包含自动字幕，避免无人工字幕时失败。
  langs=(zh en)
  for lang in "${langs[@]}"; do
    any_try=1
    err_file="$(mktemp)"

    if ! run_yt_dlp \
      --skip-download \
      --write-subs \
      --write-auto-subs \
      --convert-subs vtt \
      --sub-langs "$lang" \
      --sub-format "vtt/srt" \
      "$URL" 2>"$err_file"; then
      if rg -qi "confirm you're not a bot|Sign in to confirm|403 Forbidden|HTTP Error 429|Too Many Requests" "$err_file"; then
        bot_hit=1
      fi
    fi
    rm -f "$err_file"

    subtitle_file="$(find "$OUT_DIR" -type f \( -name '*.vtt' -o -name '*.srt' \) -newer "$marker" | sort | head -n1 || true)"
    if [[ -n "$subtitle_file" ]]; then
      break
    fi
  done

  subtitle_file="$(find "$OUT_DIR" -type f \( -name '*.vtt' -o -name '*.srt' \) -newer "$marker" | sort | head -n1 || true)"
  rm -f "$marker"

  if [[ -z "$subtitle_file" ]]; then
    if [[ "$any_try" -eq 1 && "$bot_hit" -eq 1 ]]; then
      print_bot_guidance
    fi
    echo "未获取到字幕文件（vtt/srt）。" >&2
    return 1
  fi

  text_file="${subtitle_file%.*}.txt"
  subtitle_to_text "$subtitle_file" "$text_file"
  echo "完成: mode=subtitle, subtitle=$subtitle_file, text=$text_file"
}

run_whisper_mode() {
  local marker audio_file base text_file

  if ! command -v whisper >/dev/null 2>&1; then
    echo "缺少依赖: whisper" >&2
    echo "安装示例: pip install -U openai-whisper" >&2
    return 1
  fi

  marker="$(mktemp "$OUT_DIR/.audio-marker.XXXXXX")"
  run_yt_dlp \
    --format "bestaudio/best" \
    --extract-audio \
    --audio-format mp3 \
    --audio-quality 0 \
    "$URL"

  audio_file="$(find "$OUT_DIR" -type f -name '*.mp3' -newer "$marker" | sort | head -n1 || true)"
  rm -f "$marker"

  if [[ -z "$audio_file" ]]; then
    echo "whisper 模式失败：未找到新生成的 mp3 文件。" >&2
    return 1
  fi

  whisper "$audio_file" \
    --model base \
    --language zh \
    --task transcribe \
    --output_format srt \
    --output_dir "$OUT_DIR"

  base="$(basename "${audio_file%.*}")"
  srt_file="$OUT_DIR/$base.srt"
  text_file="$OUT_DIR/$base.txt"
  if [[ ! -f "$srt_file" ]]; then
    echo "whisper 已执行，但未找到转写结果: $srt_file" >&2
    return 1
  fi

  subtitle_to_text "$srt_file" "$text_file"
  echo "完成: mode=whisper, audio=$audio_file, text=$text_file"
}

case "$MODE" in
  dryrun)
    run_yt_dlp --simulate --print title --print id "$URL"
    ;;
  audio)
    run_yt_dlp \
      --format "bestaudio/best" \
      --extract-audio \
      --audio-format mp3 \
      --audio-quality 0 \
      "$URL"
    ;;
  video)
    run_yt_dlp \
      --format "bv*+ba/b" \
      --merge-output-format mp4 \
      "$URL"
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
