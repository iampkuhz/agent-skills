#!/usr/bin/env bash
set -euo pipefail

# 将当前仓库的 skills 目录下所有技能，以软链接方式安装到用户目录。
# 默认目标目录：~/.agents/skills
# 通过环境变量 AGENT 选择目标：codex | qoder | claudecode | openclaw

usage() {
  cat <<'USAGE'
用法:
  scripts/repo/install_skills_links.sh

说明:
  把仓库内 skills/* 安装到目标目录。
  - 默认目标：~/.agents/skills（AGENT 未设置时）
  - 通过环境变量 AGENT 指定 agent：codex | qoder | claudecode | openclaw
  - codex -> $CODEX_HOME/skills（默认 ~/.codex/skills）
  - qoder -> ~/.qoder/skills
  - claudecode -> ~/.claude/skills
  - openclaw -> $OPENCLAW_HOME/skills（默认 ~/.openclaw/skills）
USAGE
}

if [[ $# -ne 0 ]]; then
  echo "本脚本不接受任何参数。" >&2
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_ROOT="$REPO_ROOT/skills"

if [[ ! -d "$SRC_ROOT" ]]; then
  echo "未找到 skills 目录: $SRC_ROOT" >&2
  exit 1
fi

AGENT_NAME="${AGENT:-}"
DEST_ROOT=""

case "$AGENT_NAME" in
  "")
    DEST_ROOT="$HOME/.agents/skills"
    ;;
  codex)
    CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
    DEST_ROOT="$CODEX_HOME_DIR/skills"
    ;;
  qoder)
    DEST_ROOT="$HOME/.qoder/skills"
    ;;
  claudecode)
    DEST_ROOT="$HOME/.claude/skills"
    ;;
  openclaw)
    OPENCLAW_HOME_DIR="${OPENCLAW_HOME:-$HOME/.openclaw}"
    DEST_ROOT="$OPENCLAW_HOME_DIR/skills"
    ;;
  *)
    echo "未知 AGENT: ${AGENT_NAME}（支持 codex | qoder | claudecode | openclaw）" >&2
    usage
    exit 1
    ;;
esac

mkdir -p "$DEST_ROOT"

echo "源目录: $SRC_ROOT"
echo "目标目录($AGENT_NAME): $DEST_ROOT"

FOUND=0
for src in "$SRC_ROOT"/*; do
  if [[ ! -d "$src" ]]; then
    continue
  fi
  FOUND=1

  name="$(basename "$src")"
  dest="$DEST_ROOT/$name"

  if [[ -L "$dest" ]]; then
    # 若已是指向同一路径的链接则跳过。
    current_target="$(readlink "$dest")"
    if [[ "$current_target" == "$src" ]]; then
      echo "已存在且正确，跳过: $name"
      continue
    fi
    rm -f "$dest"
  elif [[ -e "$dest" ]]; then
    rm -rf "$dest"
  fi

  ln -s "$src" "$dest"
  echo "已安装: $name"
done

if [[ "$FOUND" -eq 0 ]]; then
  echo "未发现可安装 skill（$SRC_ROOT 下没有目录）。"
  exit 0
fi

echo "完成。"
