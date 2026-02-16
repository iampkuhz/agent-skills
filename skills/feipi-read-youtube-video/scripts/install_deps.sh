#!/usr/bin/env bash
set -euo pipefail

# YouTube skill 依赖入口（薄封装）
# 统一依赖安装逻辑由仓库级脚本维护：
# - scripts/video/install_video_deps.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
COMMON_INSTALL="$REPO_ROOT/scripts/video/install_video_deps.sh"

if [[ ! -x "$COMMON_INSTALL" ]]; then
  echo "缺少仓库级依赖脚本: $COMMON_INSTALL" >&2
  exit 1
fi

exec bash "$COMMON_INSTALL" "$@"
