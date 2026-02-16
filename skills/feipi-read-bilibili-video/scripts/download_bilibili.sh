#!/usr/bin/env bash
set -euo pipefail

# Bilibili 下载脚本（简化版）
#
# 用法：
#   bash scripts/download_bilibili.sh <url> [output_dir] [mode]
#
# mode: video | audio | dryrun | subtitle | whisper
#
# 认证配置：
# - 仅支持 AGENT_CHROME_PROFILE（浏览器 profile）
# - 默认不提示；仅在触发权限/风控问题时给出配置建议

URL="${1:-}"
OUT_DIR="${2:-./downloads}"
MODE="${3:-video}"

# whisper.cpp（Mac 质量优先）固定参数区
WHISPER_CPP_BIN_DEFAULT="/opt/homebrew/opt/whisper-cpp/bin/whisper-cli"
WHISPER_MODEL_DIR_DEFAULT="$HOME/Library/Caches/whisper.cpp/models"
WHISPER_MODEL_FILE_DEFAULT="$WHISPER_MODEL_DIR_DEFAULT/ggml-large-v3-q5_0.bin"
WHISPER_MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin"
WHISPER_THREADS=4
WHISPER_PROCESSORS=1
WHISPER_BEAM_SIZE=8
WHISPER_BEST_OF=8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

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

if [[ -z "$URL" ]]; then
  echo "用法: bash scripts/download_bilibili.sh <url> [output_dir] [video|audio|dryrun|subtitle|whisper]" >&2
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

run_yt_dlp() {
  local -a cmd
  local err_file

  err_file="$(mktemp)"
  cmd=(yt-dlp "${COMMON_ARGS[@]}")
  if [[ ${#AUTH_ARGS[@]} -gt 0 ]]; then
    cmd+=("${AUTH_ARGS[@]}")
  fi
  cmd+=("$@")

  if ! "${cmd[@]}" 2>"$err_file"; then
    if is_auth_related_error "$err_file"; then
      print_auth_guidance
    fi

    cat "$err_file" >&2
    rm -f "$err_file"
    return 1
  fi

  rm -f "$err_file"
  return 0
}

precheck_subtitle_auth() {
  local check_file
  local -a cmd
  check_file="$(mktemp)"

  cmd=(yt-dlp --skip-download --list-subs "$URL")
  if [[ ${#AUTH_ARGS[@]} -gt 0 ]]; then
    cmd+=("${AUTH_ARGS[@]}")
  fi

  # list-subs 主要用于探测是否存在“需登录才有字幕”的限制。
  "${cmd[@]}" >"$check_file" 2>&1 || true
  if is_auth_related_error "$check_file"; then
    print_auth_guidance
    cat "$check_file" >&2
    rm -f "$check_file"
    return 1
  fi

  rm -f "$check_file"
  return 0
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
  local marker subtitle_file text_file danmaku_file
  local -a langs
  local -a fallback_langs
  local lang err_file
  local auth_hit=0
  local any_try=0

  marker="$(mktemp "$OUT_DIR/.subtitle-marker.XXXXXX")"

  if ! precheck_subtitle_auth; then
    rm -f "$marker"
    return 1
  fi

  # 优先常见中文（含中国台湾/繁体/AI 字幕标签），再回退英文。
  langs=(zh-TW zh-Hant zh-HK zh-Hans zh-CN zh ai-zh ai-en en)
  for lang in "${langs[@]}"; do
    any_try=1
    err_file="$(mktemp)"

    cmd=(yt-dlp "${COMMON_ARGS[@]}")
    if [[ ${#AUTH_ARGS[@]} -gt 0 ]]; then
      cmd+=("${AUTH_ARGS[@]}")
    fi
    cmd+=(
      --skip-download
      --write-subs
      --write-auto-subs
      --convert-subs vtt
      --sub-langs "$lang"
      --sub-format "vtt/srt"
      "$URL"
    )

    if ! "${cmd[@]}" 2>"$err_file"; then
      if is_auth_related_error "$err_file"; then
        auth_hit=1
      fi
    fi
    rm -f "$err_file"

    subtitle_file="$(find "$OUT_DIR" -type f \( -name '*.vtt' -o -name '*.srt' \) -newer "$marker" | sort | head -n1 || true)"
    if [[ -n "$subtitle_file" ]]; then
      break
    fi
  done

  # 最后兜底：直接拉取全部字幕语言，避免站点语言标签差异导致漏抓。
  if [[ -z "${subtitle_file:-}" ]]; then
    fallback_langs=(all)
    for lang in "${fallback_langs[@]}"; do
      any_try=1
      err_file="$(mktemp)"

      cmd=(yt-dlp "${COMMON_ARGS[@]}")
      if [[ ${#AUTH_ARGS[@]} -gt 0 ]]; then
        cmd+=("${AUTH_ARGS[@]}")
      fi
      cmd+=(
        --skip-download
        --write-subs
        --write-auto-subs
        --convert-subs vtt
        --sub-langs "$lang"
        --sub-format "vtt/srt"
        "$URL"
      )

      if ! "${cmd[@]}" 2>"$err_file"; then
        if is_auth_related_error "$err_file"; then
          auth_hit=1
        fi
      fi
      rm -f "$err_file"

      subtitle_file="$(find "$OUT_DIR" -type f \( -name '*.vtt' -o -name '*.srt' \) -newer "$marker" | sort | head -n1 || true)"
      if [[ -n "$subtitle_file" ]]; then
        break
      fi
    done
  fi

  subtitle_file="$(find "$OUT_DIR" -type f \( -name '*.vtt' -o -name '*.srt' \) -newer "$marker" | sort | head -n1 || true)"
  danmaku_file="$(find "$OUT_DIR" -type f -name '*.danmaku.xml' -newer "$marker" | sort | head -n1 || true)"
  rm -f "$marker"

  if [[ -z "$subtitle_file" ]]; then
    if [[ "$any_try" -eq 1 && "$auth_hit" -eq 1 ]]; then
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
  subtitle_to_text "$subtitle_file" "$text_file"
  echo "完成: mode=subtitle, subtitle=$subtitle_file, text=$text_file"
}

resolve_whisper_cpp_cli() {
  if [[ -x "$WHISPER_CPP_BIN_DEFAULT" ]]; then
    echo "$WHISPER_CPP_BIN_DEFAULT"
    return 0
  fi
  if command -v whisper-cli >/dev/null 2>&1; then
    command -v whisper-cli
    return 0
  fi
  return 1
}

resolve_metal_resources_dir() {
  local prefix
  if command -v brew >/dev/null 2>&1; then
    prefix="$(brew --prefix whisper-cpp 2>/dev/null || true)"
    if [[ -n "$prefix" && -d "$prefix/share/whisper-cpp" ]]; then
      echo "$prefix/share/whisper-cpp"
      return 0
    fi
  fi

  if [[ -d "/opt/homebrew/opt/whisper-cpp/share/whisper-cpp" ]]; then
    echo "/opt/homebrew/opt/whisper-cpp/share/whisper-cpp"
    return 0
  fi

  return 1
}

print_whisper_cpp_setup_guidance() {
  echo "whisper.cpp 质量优先模式需要以下环境：" >&2
  echo "1) 安装 whisper-cpp: brew install whisper-cpp" >&2
  echo "2) 下载模型（一次性）:" >&2
  echo "   mkdir -p \"$WHISPER_MODEL_DIR_DEFAULT\"" >&2
  echo "   curl -L --fail \"$WHISPER_MODEL_URL\" -o \"$WHISPER_MODEL_FILE_DEFAULT\"" >&2
}

run_whisper_mode() {
  local marker audio_file base text_file srt_file output_prefix
  local whisper_cli metal_resources used_device
  local -a whisper_cpp_args
  local run_code

  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "whisper 模式当前仅支持 macOS + whisper.cpp。" >&2
    return 1
  fi

  whisper_cli="$(resolve_whisper_cpp_cli || true)"
  if [[ -z "$whisper_cli" ]]; then
    echo "缺少依赖: whisper-cli（whisper.cpp）" >&2
    print_whisper_cpp_setup_guidance
    return 1
  fi

  if [[ ! -f "$WHISPER_MODEL_FILE_DEFAULT" ]]; then
    echo "缺少模型文件: $WHISPER_MODEL_FILE_DEFAULT" >&2
    print_whisper_cpp_setup_guidance
    return 1
  fi

  metal_resources="$(resolve_metal_resources_dir || true)"
  if [[ -z "$metal_resources" ]]; then
    echo "未找到 whisper.cpp Metal 资源目录（share/whisper-cpp）。" >&2
    echo "请确认 whisper-cpp 通过 Homebrew 正常安装。" >&2
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

  base="$(basename "${audio_file%.*}")"
  output_prefix="$OUT_DIR/$base"
  srt_file="$output_prefix.srt"
  text_file="$output_prefix.txt"
  rm -f "$srt_file" "$text_file"

  whisper_cpp_args=(
    -m "$WHISPER_MODEL_FILE_DEFAULT"
    -f "$audio_file"
    -l zh
    -osrt
    -of "$output_prefix"
    -t "$WHISPER_THREADS"
    -p "$WHISPER_PROCESSORS"
    -bs "$WHISPER_BEAM_SIZE"
    -bo "$WHISPER_BEST_OF"
    -np
  )

  used_device="metal"
  set +e
  GGML_METAL_PATH_RESOURCES="$metal_resources" "$whisper_cli" "${whisper_cpp_args[@]}"
  run_code=$?
  set -e

  if [[ $run_code -ne 0 || ! -f "$srt_file" ]]; then
    echo "Metal 转写失败，回退 CPU 转写。" >&2
    rm -f "$srt_file"
    used_device="cpu"
    "$whisper_cli" "${whisper_cpp_args[@]}" -ng
  fi

  if [[ ! -f "$srt_file" ]]; then
    echo "whisper.cpp 已执行，但未找到转写结果: $srt_file" >&2
    return 1
  fi

  subtitle_to_text "$srt_file" "$text_file"
  echo "完成: mode=whisper, engine=whisper.cpp, model=$(basename "$WHISPER_MODEL_FILE_DEFAULT"), device=$used_device, audio=$audio_file, text=$text_file"
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
