#!/usr/bin/env bash
set -euo pipefail

# 一键安装/检查 feipi-read-youtube-video 所需依赖
# 依赖：yt-dlp, ffmpeg, whisper
#
# 用法：
#   bash scripts/install_deps.sh            # 自动安装缺失依赖（支持 macOS + Homebrew）
#   bash scripts/install_deps.sh --check    # 仅检查，不安装

usage() {
  cat <<'USAGE'
用法:
  bash scripts/install_deps.sh [--check]

参数:
  --check   仅检查依赖，不执行安装
USAGE
}

CHECK_ONLY=0
if [[ $# -gt 0 ]]; then
  case "$1" in
    --check)
      CHECK_ONLY=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage
      exit 1
      ;;
  esac
fi

need_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1
}

install_with_brew() {
  local pkg="$1"
  if ! command -v brew >/dev/null 2>&1; then
    echo "未安装 Homebrew，无法自动安装 $pkg。" >&2
    echo "请先安装 Homebrew 或手动安装 $pkg。" >&2
    return 1
  fi
  brew list "$pkg" >/dev/null 2>&1 || brew install "$pkg"
}

install_whisper() {
  if need_cmd whisper; then
    return 0
  fi

  if need_cmd pip3; then
    pip3 install -U openai-whisper
    return 0
  fi

  echo "未找到 pip3，无法自动安装 whisper。" >&2
  echo "请先安装 Python3/pip3，然后执行: pip3 install -U openai-whisper" >&2
  return 1
}

install_yt_dlp() {
  install_with_brew yt-dlp
}

install_ffmpeg() {
  install_with_brew ffmpeg
}

check_and_install() {
  local cmd="$1"
  local installer="$2"

  if need_cmd "$cmd"; then
    echo "[OK] $cmd"
    return 0
  fi

  echo "[MISS] $cmd"
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    return 1
  fi

  echo "正在安装 $cmd ..."
  if "$installer"; then
    if need_cmd "$cmd"; then
      echo "[OK] $cmd 安装完成"
      return 0
    fi
  fi

  echo "[FAIL] $cmd 安装失败" >&2
  return 1
}

FAILED=0

check_and_install yt-dlp install_yt_dlp || FAILED=1
check_and_install ffmpeg install_ffmpeg || FAILED=1
check_and_install whisper install_whisper || FAILED=1

if [[ "$FAILED" -ne 0 ]]; then
  echo "依赖检查/安装未完全通过。" >&2
  exit 1
fi

echo "依赖已就绪。"
