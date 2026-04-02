#!/usr/bin/env bash
set -euo pipefail

# 将当前仓库的 skills 目录下所有技能，以软链接方式安装到用户目录。
# 同时自动检测 skill 对仓库根目录共享脚本（如 feipi-scripts/）的依赖，并安装同级软链接。
# 默认行为：检测所有 agent 目标目录，存在即安装。
# 通过环境变量 AGENT 选择目标：codex | qwen | qoder | claudecode | openclaw

AGENT_NAME="${AGENT:-}"

get_dest_root() {
  local agent="$1"
  case "$agent" in
    codex)
      local CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
      echo "$CODEX_HOME_DIR/skills"
      ;;
    qoder)
      echo "$HOME/.qoder/skills"
      ;;
    qwen)
      echo "$HOME/.qwen/skills"
      ;;
    claudecode)
      echo "$HOME/.claude/skills"
      ;;
    openclaw)
      local OPENCLAW_HOME_DIR="${OPENCLAW_HOME:-$HOME/.openclaw}"
      echo "$OPENCLAW_HOME_DIR/skills"
      ;;
    "")
      echo "$HOME/.agents/skills"
      ;;
    *)
      echo ""
      ;;
  esac
}

get_all_agents() {
  echo "codex qwen qoder claudecode openclaw"
}

find_existing_agents() {
  local existing=""
  for agent in $(get_all_agents); do
    local dest
    dest="$(get_dest_root "$agent")"
    if [[ -d "$dest" ]] || [[ -d "$(dirname "$dest")" ]]; then
      existing="$existing $agent"
    fi
  done
  echo "$existing" | xargs
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_ROOT="$REPO_ROOT/skills"

if [[ ! -d "$SRC_ROOT" ]]; then
  echo "未找到 skills 目录：$SRC_ROOT" >&2
  exit 1
fi

# 确定要安装的目标 agents
declare -a TARGET_AGENTS=()

if [[ -n "$AGENT_NAME" ]]; then
  # 用户指定了 AGENT
  dest="$(get_dest_root "$AGENT_NAME")"
  if [[ -z "$dest" ]]; then
    echo "未知 AGENT: ${AGENT_NAME}（支持 codex | qwen | qoder | claudecode | openclaw）" >&2
    exit 1
  fi
  # 确保父目录存在
  mkdir -p "$(dirname "$dest")"
  TARGET_AGENTS+=("$AGENT_NAME:$dest")
else
  # 默认：查找所有已存在的 agent 目录
  existing="$(find_existing_agents)"
  if [[ -z "$existing" ]]; then
    # 如果没有发现任何 agent 目录，使用默认值
    dest="$(get_dest_root "")"
    mkdir -p "$(dirname "$dest")"
    TARGET_AGENTS+=(":$dest")
    echo "未发现任何 agent 目标目录，使用默认：$dest"
  else
    for agent in $existing; do
      dest="$(get_dest_root "$agent")"
      mkdir -p "$(dirname "$dest")"
      TARGET_AGENTS+=("$agent:$dest")
    done
    echo "检测到已存在的 agent 目录：$existing"
  fi
fi

link_item() {
  local src="$1"
  local dest="$2"
  local label="$3"
  local current_target=""

  if [[ -L "$dest" ]]; then
    current_target="$(readlink "$dest")"
    if [[ "$current_target" == "$src" ]]; then
      echo "  已存在，跳过：$label"
      return 0
    fi
    rm -f "$dest"
  elif [[ -e "$dest" ]]; then
    echo "  警告：目标已存在且非软链接，跳过：$dest" >&2
    return 1
  fi

  ln -s "$src" "$dest"
  echo "  已安装：$label"
  return 0
}

collect_shared_roots() {
  rg -o --no-filename '\$REPO_ROOT/[A-Za-z0-9._/-]+' "$SRC_ROOT" -g '*.sh' 2>/dev/null \
    | sed -E 's#^\$REPO_ROOT/##' \
    | cut -d'/' -f1 \
    | rg -v '^[[:space:]]*$' \
    | sort -u || true
}

TOTAL_INSTALLED=0
TOTAL_SKIPPED=0

for agent_entry in "${TARGET_AGENTS[@]}"; do
  agent="${agent_entry%%:*}"
  DEST_ROOT="${agent_entry#*:}"

  if [[ -n "$agent" ]]; then
    echo ""
    echo "=== 安装到 $agent -> $DEST_ROOT ==="
  else
    echo ""
    echo "=== 安装到 $DEST_ROOT ==="
  fi

  DEST_BASE="$(cd "$DEST_ROOT/.." && pwd)"

  echo "源目录：$SRC_ROOT"
  echo "目标目录：$DEST_ROOT"

  INSTALLED=0
  SKIPPED=0

  for src in "$SRC_ROOT"/*; do
    if [[ ! -d "$src" ]]; then
      continue
    fi

    name="$(basename "$src")"
    dest="$DEST_ROOT/$name"
    if link_item "$src" "$dest" "$name"; then
      INSTALLED=$((INSTALLED + 1))
    else
      SKIPPED=$((SKIPPED + 1))
    fi
  done

  SHARED_ROOTS_TEXT="$(collect_shared_roots)"
  if [[ -n "$SHARED_ROOTS_TEXT" ]]; then
    while IFS= read -r root_name; do
      [[ -z "$root_name" ]] && continue
      src="$REPO_ROOT/$root_name"
      dest="$DEST_BASE/$root_name"

      if [[ "$dest" == "$DEST_ROOT" ]]; then
        continue
      fi

      if [[ ! -e "$src" ]]; then
        echo "  警告：共享路径不存在，跳过：$src" >&2
        SKIPPED=$((SKIPPED + 1))
        continue
      fi

      if link_item "$src" "$dest" "$root_name"; then
        INSTALLED=$((INSTALLED + 1))
      else
        SKIPPED=$((SKIPPED + 1))
      fi
    done <<< "$SHARED_ROOTS_TEXT"
  fi

  echo "完成：安装 ${INSTALLED}，跳过 ${SKIPPED}"
  TOTAL_INSTALLED=$((TOTAL_INSTALLED + INSTALLED))
  TOTAL_SKIPPED=$((TOTAL_SKIPPED + SKIPPED))
done

echo ""
echo "========================================"
echo "总计：安装/更新 ${TOTAL_INSTALLED}，跳过 ${TOTAL_SKIPPED}"
