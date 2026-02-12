#!/usr/bin/env bash
set -euo pipefail

# 将当前仓库的 skills 目录下所有技能，以软链接方式安装到用户目录。
# 默认目标目录：$CODEX_HOME/skills（若未设置 CODEX_HOME，则使用 ~/.codex/skills）
#
# 用法：
#   scripts/install_skills_links.sh [--force] [--dry-run]
#
# 参数：
#   --force   : 目标已存在时强制覆盖（先删除再创建链接）
#   --dry-run : 仅打印将执行的操作，不实际修改文件

usage() {
  cat <<'USAGE'
用法:
  scripts/install_skills_links.sh [--force] [--dry-run]

说明:
  把仓库内 skills/* 安装到 $CODEX_HOME/skills（默认 ~/.codex/skills）。
USAGE
}

FORCE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
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
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_ROOT="$REPO_ROOT/skills"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
DEST_ROOT="$CODEX_HOME_DIR/skills"

if [[ ! -d "$SRC_ROOT" ]]; then
  echo "未找到 skills 目录: $SRC_ROOT" >&2
  exit 1
fi

# 统一执行入口，支持 dry-run
run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

run_cmd mkdir -p "$DEST_ROOT"

echo "源目录: $SRC_ROOT"
echo "目标目录: $DEST_ROOT"

FOUND=0
for src in "$SRC_ROOT"/*; do
  if [[ ! -d "$src" ]]; then
    continue
  fi
  FOUND=1

  name="$(basename "$src")"
  dest="$DEST_ROOT/$name"

  if [[ -L "$dest" ]]; then
    # 若已是指向同一路径的链接则跳过
    current_target="$(readlink "$dest")"
    if [[ "$current_target" == "$src" ]]; then
      echo "已存在且正确，跳过: $name"
      continue
    fi

    if [[ "$FORCE" -eq 1 ]]; then
      run_cmd rm -f "$dest"
    else
      echo "已存在不同链接，跳过: $name -> $current_target"
      echo "如需覆盖请使用 --force"
      continue
    fi
  elif [[ -e "$dest" ]]; then
    if [[ "$FORCE" -eq 1 ]]; then
      run_cmd rm -rf "$dest"
    else
      echo "目标已存在且不是链接，跳过: $dest"
      echo "如需覆盖请使用 --force"
      continue
    fi
  fi

  run_cmd ln -s "$src" "$dest"
  echo "已安装: $name"
done

if [[ "$FOUND" -eq 0 ]]; then
  echo "未发现可安装 skill（$SRC_ROOT 下没有目录）。"
  exit 0
fi

echo "完成。"
