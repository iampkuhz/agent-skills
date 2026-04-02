#!/usr/bin/env bash
set -euo pipefail

# feipi-gen-skills 的本地初始化封装。
# 目标：转发到仓库共享初始化脚本，并对生成结果做一次本地校验。

usage() {
  cat <<'USAGE'
用法:
  bash scripts/init_skill.sh <skill-name> [resources] [target]

示例:
  bash scripts/init_skill.sh gen-api-tests
  bash scripts/init_skill.sh gen-api-tests scripts,references,assets
  bash scripts/init_skill.sh gen-api-tests scripts,references /tmp/skills
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
SHARED_INIT="$REPO_ROOT/feipi-scripts/repo/init_skill.sh"
VALIDATE_SCRIPT="$SCRIPT_DIR/validate.sh"

if [[ ! -x "$SHARED_INIT" ]]; then
  echo "缺少共享初始化脚本: $SHARED_INIT" >&2
  exit 1
fi

if [[ ! -x "$VALIDATE_SCRIPT" ]]; then
  echo "缺少本地校验脚本: $VALIDATE_SCRIPT" >&2
  exit 1
fi

SKILL_INPUT="$1"
RESOURCES_INPUT="${2:-scripts,references}"
TARGET_INPUT="${3:-auto}"

normalize_skill_name() {
  local name="$1"
  if [[ "$name" == feipi-* ]]; then
    printf "%s" "$name"
  else
    printf "feipi-%s" "$name"
  fi
}

normalize_resources() {
  local raw="$1"
  local item=""
  local normalized=()
  local seen="|"

  if [[ -z "$raw" ]]; then
    raw="scripts,references"
  fi

  IFS=',' read -r -a items <<< "$raw"
  for item in "${items[@]}"; do
    item="$(printf "%s" "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -z "$item" ]] && continue
    if [[ "$seen" != *"|$item|"* ]]; then
      normalized+=("$item")
      seen="${seen}${item}|"
    fi
  done

  if [[ "$seen" != *"|scripts|"* ]]; then
    normalized=("scripts" "${normalized[@]}")
  fi

  local joined=""
  for item in "${normalized[@]}"; do
    if [[ -n "$joined" ]]; then
      joined+=","
    fi
    joined+="$item"
  done
  printf "%s" "$joined"
}

resolve_target_root() {
  local target="$1"
  case "$target" in
    auto)
      if [[ -d "$REPO_ROOT/skills" ]]; then
        echo "$REPO_ROOT/skills"
      else
        echo "$REPO_ROOT/.agents/skills"
      fi
      ;;
    skills)
      echo "$REPO_ROOT/skills"
      ;;
    repo)
      echo "$REPO_ROOT/.agents/skills"
      ;;
    /*)
      echo "$target"
      ;;
    *)
      echo "$REPO_ROOT/$target"
      ;;
  esac
}

SKILL_NAME="$(normalize_skill_name "$SKILL_INPUT")"
RESOURCES="$(normalize_resources "$RESOURCES_INPUT")"
TARGET_ROOT="$(resolve_target_root "$TARGET_INPUT")"
TARGET_SKILL_DIR="$TARGET_ROOT/$SKILL_NAME"

echo "=== 初始化 skill: $SKILL_NAME ==="
echo "资源: $RESOURCES"
echo "目标根目录: $TARGET_ROOT"

bash "$SHARED_INIT" "$SKILL_INPUT" --resources "$RESOURCES" --target "$TARGET_INPUT"
bash "$VALIDATE_SCRIPT" "$TARGET_SKILL_DIR" >/dev/null

echo "初始化并校验完成: $TARGET_SKILL_DIR"
