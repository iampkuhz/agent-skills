#!/usr/bin/env bash
set -euo pipefail

# 将当前仓库的 skills 目录下所有技能安装到目标目录。
# 支持两种模式：
# 1. 软链接模式：安装到用户级 agent 目录（~/.claude/skills 等）
# 2. 拷贝模式：安装到项目目录内（<project>/.agents/skills 等）
#
# 用法：
#   ./scripts/install_skills.sh
#     软链接到所有已存在的用户级 agent 目录
#   ./scripts/install_skills.sh --agent claudecode
#     软链接到 ~/.claude/skills
#   ./scripts/install_skills.sh --dir /path/to/project
#     拷贝到 /path/to/project/.agents/skills
#   ./scripts/install_skills.sh --agent qwen --dir /path/to/project
#     拷贝到 /path/to/project/.qwen/skills

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_ROOT="$REPO_ROOT/skills"

AGENT_NAME=""
TARGET_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      echo "用法: $0 [--agent <name>] [--dir <path>]"
      echo ""
      echo "选项:"
      echo "  --agent <name>  指定 agent 类型（codex | qwen | qoder | claudecode | openclaw）"
      echo "  --dir <path>    指定目标路径"
      echo ""
      echo "示例:"
      echo "  $0                              # 软链接到所有已存在的用户级目录"
      echo "  $0 --agent claudecode           # 软链接到 ~/.claude/skills"
      echo "  $0 --dir /path/to/project       # 拷贝到 /path/to/project/.agents/skills"
      echo "  $0 --agent qwen --dir /path     # 拷贝到 /path/to/project/.qwen/skills"
      exit 0
      ;;
    --agent)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--agent 缺少参数。" >&2
        exit 1
      fi
      AGENT_NAME="$1"
      ;;
    --dir)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--dir 缺少参数。" >&2
        exit 1
      fi
      TARGET_DIR="$1"
      ;;
    -*)
      echo "未知参数：$1" >&2
      exit 1
      ;;
    *)
      echo "多余参数：$1" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ ! -d "$SRC_ROOT" ]]; then
  echo "未找到 skills 目录：$SRC_ROOT" >&2
  exit 1
fi

get_user_dest_root() {
  local agent="$1"
  case "$agent" in
    codex)
      local codex_home_dir="${CODEX_HOME:-$HOME/.codex}"
      echo "$codex_home_dir/skills"
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
      local openclaw_home_dir="${OPENCLAW_HOME:-$HOME/.openclaw}"
      echo "$openclaw_home_dir/skills"
      ;;
    "")
      echo "$HOME/.agents/skills"
      ;;
    *)
      echo ""
      ;;
  esac
}

get_project_dest_root() {
  local agent="$1"
  local project="$2"
  case "$agent" in
    codex)
      echo "$project/.codex/skills"
      ;;
    qoder)
      echo "$project/.qoder/skills"
      ;;
    qwen)
      echo "$project/.qwen/skills"
      ;;
    claudecode)
      echo "$project/.claude/skills"
      ;;
    openclaw)
      echo "$project/.openclaw/skills"
      ;;
    "")
      echo "$project/.agents/skills"
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
    dest="$(get_user_dest_root "$agent")"
    if [[ -d "$dest" ]] || [[ -d "$(dirname "$dest")" ]]; then
      existing="$existing $agent"
    fi
  done
  echo "$existing" | xargs
}

collect_shared_roots() {
  local root_name=""

  rg -o --no-filename '\$REPO_ROOT/[A-Za-z0-9._/-]+' "$SRC_ROOT" -g '*.sh' 2>/dev/null \
    | sed -E 's#^\$REPO_ROOT/##' \
    | cut -d'/' -f1 \
    | sort -u \
    | while IFS= read -r root_name; do
      [[ -z "$root_name" ]] && continue
      [[ "$root_name" == "skills" ]] && continue
      [[ "$root_name" == .* ]] && continue
      [[ -e "$REPO_ROOT/$root_name" ]] || continue
      printf '%s\n' "$root_name"
    done
}

link_item() {
  local src="$1"
  local dest="$2"
  local label="$3"

  if [[ -L "$dest" ]]; then
    local current_target
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

copy_dir() {
  local src="$1"
  local dest="$2"
  local label="$3"

  if [[ -e "$dest" ]]; then
    rm -rf "$dest"
  fi

  cp -R -p "$src" "$dest"
  echo "  已安装：$label"
}

install_skills() {
  local mode="$1"
  local dest_root="$2"
  local install_func="$3"
  local label="$4"

  echo "=== $label ==="
  echo "源目录：$SRC_ROOT"
  echo "目标目录：$dest_root"

  mkdir -p "$dest_root"

  local installed=0
  local skipped=0

  for src in "$SRC_ROOT"/*; do
    if [[ ! -d "$src" ]]; then
      continue
    fi

    local name
    name="$(basename "$src")"
    local dest="$dest_root/$name"
    if $install_func "$src" "$dest" "$name"; then
      installed=$((installed + 1))
    else
      skipped=$((skipped + 1))
    fi
  done

  local dest_base
  dest_base="$(cd "$dest_root/.." && pwd)"

  local shared_roots_text
  shared_roots_text="$(collect_shared_roots)"
  if [[ -n "$shared_roots_text" ]]; then
    while IFS= read -r root_name; do
      [[ -z "$root_name" ]] && continue
      local src="$REPO_ROOT/$root_name"
      local dest="$dest_base/$root_name"

      if [[ "$dest" == "$dest_root" ]]; then
        continue
      fi

      if [[ ! -e "$src" ]]; then
        echo "  警告：共享路径不存在，跳过：$src" >&2
        skipped=$((skipped + 1))
        continue
      fi

      if $install_func "$src" "$dest" "$root_name"; then
        installed=$((installed + 1))
      else
        skipped=$((skipped + 1))
      fi
    done <<< "$shared_roots_text"
  fi

  echo "完成：安装 ${installed}，跳过 ${skipped}"
  echo "$installed $skipped"
}

total_installed=0
total_skipped=0

if [[ -n "$TARGET_DIR" ]]; then
  if [[ ! -d "$TARGET_DIR" ]]; then
    echo "项目路径不存在或不是目录：$TARGET_DIR" >&2
    exit 1
  fi

  project_root="$(cd "$TARGET_DIR" && pwd)"
  dest_root="$(get_project_dest_root "$AGENT_NAME" "$project_root")"

  if [[ -z "$dest_root" ]]; then
    if [[ -n "$AGENT_NAME" ]]; then
      echo "未知 AGENT: ${AGENT_NAME}（支持 codex | qwen | qoder | claudecode | openclaw）" >&2
    else
      echo "无法确定目标目录" >&2
    fi
    exit 1
  fi

  if [[ "$dest_root" != "$project_root"/* ]]; then
    echo "目标路径不在项目目录内，已拒绝：$dest_root" >&2
    exit 1
  fi

  result="$(install_skills "copy" "$dest_root" "copy_dir" "安装到项目：$dest_root")"
  installed="$(echo "$result" | tail -1 | cut -d' ' -f1)"
  skipped="$(echo "$result" | tail -1 | cut -d' ' -f2)"
  total_installed=$((total_installed + installed))
  total_skipped=$((total_skipped + skipped))
else
  declare -a target_agents=()

  if [[ -n "$AGENT_NAME" ]]; then
    dest="$(get_user_dest_root "$AGENT_NAME")"
    if [[ -z "$dest" ]]; then
      echo "未知 AGENT: ${AGENT_NAME}（支持 codex | qwen | qoder | claudecode | openclaw）" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$dest")"
    target_agents+=("$AGENT_NAME:$dest")
  else
    existing="$(find_existing_agents)"
    if [[ -z "$existing" ]]; then
      dest="$(get_user_dest_root "")"
      mkdir -p "$(dirname "$dest")"
      target_agents+=(":$dest")
      echo "未发现任何 agent 目标目录，使用默认：$dest"
    else
      for agent in $existing; do
        dest="$(get_user_dest_root "$agent")"
        mkdir -p "$(dirname "$dest")"
        target_agents+=("$agent:$dest")
      done
      echo "检测到已存在的 agent 目录：$existing"
    fi
  fi

  for agent_entry in "${target_agents[@]}"; do
    agent="${agent_entry%%:*}"
    dest_root="${agent_entry#*:}"

    if [[ -n "$agent" ]]; then
      result="$(install_skills "link" "$dest_root" "link_item" "安装到 $agent -> $dest_root")"
    else
      result="$(install_skills "link" "$dest_root" "link_item" "安装到 $dest_root")"
    fi
    installed="$(echo "$result" | tail -1 | cut -d' ' -f1)"
    skipped="$(echo "$result" | tail -1 | cut -d' ' -f2)"
    total_installed=$((total_installed + installed))
    total_skipped=$((total_skipped + skipped))
  done
fi

echo ""
echo "========================================"
echo "总计：安装/更新 ${total_installed}，跳过 ${total_skipped}"
