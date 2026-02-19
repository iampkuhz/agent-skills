#!/usr/bin/env bash
set -euo pipefail

# 统一 skill 测试调度入口：
# - 支持 SKILL 全名（feipi-xxx）
# - 支持短名（会自动补全 feipi- 前缀）

usage() {
  cat <<'USAGE'
用法:
  scripts/repo/run_skill_test.sh <skill-name> [--config <path>] [--output <path>]

示例:
  scripts/repo/run_skill_test.sh feipi-read-youtube-video
  scripts/repo/run_skill_test.sh read-youtube-video --output ./tmp/runs
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

SKILL_INPUT="$1"
shift

CONFIG=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
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
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_ROOTS=(
  "$REPO_ROOT/skills"
  "$REPO_ROOT/.agents/skills"
)

resolve_skill_name() {
  local name="$1"
  local root=""

  for root in "${SKILL_ROOTS[@]}"; do
    if [[ -d "$root/$name" ]]; then
      SKILL_NAME="$name"
      SKILLS_ROOT="$root"
      return 0
    fi

    if [[ "$name" != feipi-* ]] && [[ -d "$root/feipi-$name" ]]; then
      SKILL_NAME="feipi-$name"
      SKILLS_ROOT="$root"
      return 0
    fi
  done

  return 1
}

SKILL_NAME=""
SKILLS_ROOT=""
if ! resolve_skill_name "$SKILL_INPUT"; then
  echo "未找到 skill: $SKILL_INPUT" >&2
  exit 1
fi

TEST_SCRIPT="$SKILLS_ROOT/$SKILL_NAME/scripts/test.sh"
if [[ ! -x "$TEST_SCRIPT" ]]; then
  echo "缺少可执行测试脚本: $TEST_SCRIPT" >&2
  exit 1
fi

CMD=("$TEST_SCRIPT")
if [[ -n "$CONFIG" ]]; then
  CMD+=(--config "$CONFIG")
fi
if [[ -n "$OUTPUT" ]]; then
  CMD+=(--output "$OUTPUT")
fi

"${CMD[@]}"
