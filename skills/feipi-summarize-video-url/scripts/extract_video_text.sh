#!/usr/bin/env bash
set -euo pipefail

# 依据 URL 来源调用依赖技能，提取文本。
# 用法：bash scripts/extract_video_text.sh <url> [output_dir] [auto|subtitle|whisper] [--check-deps]

URL="${1:-}"
OUT_DIR="${2:-./tmp/video-text}"
MODE="${3:-auto}"
CHECK_ONLY="0"

if [[ "${4:-}" == "--check-deps" || "${3:-}" == "--check-deps" ]]; then
  CHECK_ONLY="1"
  if [[ "${3:-}" == "--check-deps" ]]; then
    MODE="auto"
  fi
fi

if [[ -z "$URL" ]]; then
  echo "用法: bash scripts/extract_video_text.sh <url> [output_dir] [auto|subtitle|whisper] [--check-deps]" >&2
  exit 1
fi

if [[ "$MODE" != "auto" && "$MODE" != "subtitle" && "$MODE" != "whisper" ]]; then
  echo "mode 仅支持 auto|subtitle|whisper，当前: $MODE" >&2
  exit 1
fi

detect_source() {
  local url="$1"
  if [[ "$url" =~ ^https?://([a-zA-Z0-9-]+\.)?(youtube\.com|youtu\.be)(/|$) ]]; then
    echo "youtube"
    return 0
  fi
  if [[ "$url" =~ ^https?://([a-zA-Z0-9-]+\.)?(bilibili\.com|b23\.tv)(/|$) ]]; then
    echo "bilibili"
    return 0
  fi
  echo "不支持的视频来源: $url（仅支持 YouTube / Bilibili）" >&2
  return 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_ROOT_DEFAULT="$(cd "$SKILL_DIR/.." && pwd)"
SKILLS_ROOT="${AGENT_SKILLS_ROOT:-$SKILLS_ROOT_DEFAULT}"

SOURCE="$(detect_source "$URL")"

if [[ "$SOURCE" == "youtube" ]]; then
  DEP_SKILL_DIR="$SKILLS_ROOT/feipi-read-youtube-video"
  DEP_SCRIPT="$DEP_SKILL_DIR/scripts/download_youtube.sh"
elif [[ "$SOURCE" == "bilibili" ]]; then
  DEP_SKILL_DIR="$SKILLS_ROOT/feipi-read-bilibili-video"
  DEP_SCRIPT="$DEP_SKILL_DIR/scripts/download_bilibili.sh"
else
  echo "未知来源: $SOURCE" >&2
  exit 1
fi

if [[ ! -d "$DEP_SKILL_DIR" ]]; then
  echo "缺少依赖 skill 目录: $DEP_SKILL_DIR" >&2
  echo "请先配置依赖技能后再运行。" >&2
  exit 1
fi

if [[ ! -x "$DEP_SCRIPT" ]]; then
  echo "缺少依赖脚本或不可执行: $DEP_SCRIPT" >&2
  echo "请先配置依赖技能后再运行。" >&2
  exit 1
fi

if [[ "$CHECK_ONLY" == "1" ]]; then
  echo "dependency_ok=1"
  echo "source=$SOURCE"
  echo "script=$DEP_SCRIPT"
  exit 0
fi

mkdir -p "$OUT_DIR"
LOG_DIR="$OUT_DIR/logs"
mkdir -p "$LOG_DIR"

run_mode() {
  local mode="$1"
  local marker log_file newest_txt
  marker="$(mktemp "$OUT_DIR/.txt-marker.XXXXXX")"
  log_file="$LOG_DIR/${SOURCE}-${mode}.log"

  set +e
  bash "$DEP_SCRIPT" "$URL" "$OUT_DIR" "$mode" >"$log_file" 2>&1
  local code=$?
  set -e

  newest_txt="$(find "$OUT_DIR" -type f -name '*.txt' -newer "$marker" | sort | tail -n1 || true)"
  rm -f "$marker"

  if [[ $code -eq 0 && -n "$newest_txt" ]]; then
    echo "$newest_txt"
    return 0
  fi

  return 1
}

TEXT_FILE=""
USED_MODE=""

if [[ "$MODE" == "auto" || "$MODE" == "subtitle" ]]; then
  if TEXT_FILE="$(run_mode subtitle)"; then
    USED_MODE="subtitle"
  fi
fi

if [[ -z "$TEXT_FILE" && ( "$MODE" == "auto" || "$MODE" == "whisper" ) ]]; then
  if TEXT_FILE="$(run_mode whisper)"; then
    USED_MODE="whisper"
  fi
fi

if [[ -z "$TEXT_FILE" ]]; then
  echo "文本提取失败: source=$SOURCE mode=$MODE" >&2
  echo "请检查日志目录: $LOG_DIR" >&2
  exit 1
fi

echo "source=$SOURCE"
echo "mode=$USED_MODE"
echo "text_path=$TEXT_FILE"
echo "log_dir=$LOG_DIR"
