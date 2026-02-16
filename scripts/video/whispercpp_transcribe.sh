#!/usr/bin/env bash
set -euo pipefail

# whisper.cpp 转写共享脚本（仓库级）
#
# 用法：
#   bash scripts/video/whispercpp_transcribe.sh <audio_file> <output_prefix> [language]
#
# 说明：
# - 固定使用质量优先模型：ggml-large-v3-q5_0.bin
# - 先尝试 Metal（GPU），失败自动回退 CPU
# - 输出文件：<output_prefix>.srt

AUDIO_FILE="${1:-}"
OUTPUT_PREFIX="${2:-}"
LANGUAGE="${3:-zh}"

WHISPER_CPP_BIN_DEFAULT="/opt/homebrew/opt/whisper-cpp/bin/whisper-cli"
WHISPER_MODEL_DIR_DEFAULT="$HOME/Library/Caches/whisper.cpp/models"
WHISPER_MODEL_FILE_DEFAULT="$WHISPER_MODEL_DIR_DEFAULT/ggml-large-v3-q5_0.bin"
WHISPER_MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin"
WHISPER_THREADS=4
WHISPER_PROCESSORS=1
WHISPER_BEAM_SIZE=8
WHISPER_BEST_OF=8

usage() {
  echo "用法: bash scripts/video/whispercpp_transcribe.sh <audio_file> <output_prefix> [language]" >&2
}

if [[ -z "$AUDIO_FILE" || -z "$OUTPUT_PREFIX" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$AUDIO_FILE" ]]; then
  echo "音频文件不存在: $AUDIO_FILE" >&2
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "当前脚本仅支持 macOS（whisper.cpp + Metal/CPU）。" >&2
  exit 1
fi

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

print_setup_guidance() {
  echo "whisper.cpp 质量优先模式需要以下环境：" >&2
  echo "1) 安装 whisper-cpp: brew install whisper-cpp" >&2
  echo "2) 下载模型（一次性）:" >&2
  echo "   mkdir -p \"$WHISPER_MODEL_DIR_DEFAULT\"" >&2
  echo "   curl -L --fail \"$WHISPER_MODEL_URL\" -o \"$WHISPER_MODEL_FILE_DEFAULT\"" >&2
}

WHISPER_CLI="$(resolve_whisper_cpp_cli || true)"
if [[ -z "$WHISPER_CLI" ]]; then
  echo "缺少依赖: whisper-cli（whisper.cpp）" >&2
  print_setup_guidance
  exit 1
fi

if [[ ! -f "$WHISPER_MODEL_FILE_DEFAULT" ]]; then
  echo "缺少模型文件: $WHISPER_MODEL_FILE_DEFAULT" >&2
  print_setup_guidance
  exit 1
fi

METAL_RESOURCES="$(resolve_metal_resources_dir || true)"
if [[ -z "$METAL_RESOURCES" ]]; then
  echo "未找到 whisper.cpp Metal 资源目录（share/whisper-cpp）。" >&2
  echo "请确认 whisper-cpp 通过 Homebrew 正常安装。" >&2
  exit 1
fi

SRT_FILE="${OUTPUT_PREFIX}.srt"
rm -f "$SRT_FILE"

WHISPER_ARGS=(
  -m "$WHISPER_MODEL_FILE_DEFAULT"
  -f "$AUDIO_FILE"
  -l "$LANGUAGE"
  -osrt
  -of "$OUTPUT_PREFIX"
  -t "$WHISPER_THREADS"
  -p "$WHISPER_PROCESSORS"
  -bs "$WHISPER_BEAM_SIZE"
  -bo "$WHISPER_BEST_OF"
  -np
)

USED_DEVICE="metal"
set +e
GGML_METAL_PATH_RESOURCES="$METAL_RESOURCES" "$WHISPER_CLI" "${WHISPER_ARGS[@]}"
RUN_CODE=$?
set -e

if [[ $RUN_CODE -ne 0 || ! -f "$SRT_FILE" ]]; then
  echo "Metal 转写失败，回退 CPU 转写。" >&2
  rm -f "$SRT_FILE"
  USED_DEVICE="cpu"
  "$WHISPER_CLI" "${WHISPER_ARGS[@]}" -ng
fi

if [[ ! -f "$SRT_FILE" ]]; then
  echo "whisper.cpp 已执行，但未找到转写结果: $SRT_FILE" >&2
  exit 1
fi

echo "device=$USED_DEVICE"
echo "model=$(basename "$WHISPER_MODEL_FILE_DEFAULT")"
echo "srt_path=$SRT_FILE"
