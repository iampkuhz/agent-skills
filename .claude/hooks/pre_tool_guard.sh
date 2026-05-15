#!/usr/bin/env bash
# PreToolUse(Bash) — 极端高危命令硬拦截
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

INPUT="${CLAUDE_TOOL_INPUT:-${CC_TOOL_INPUT:-${1:-}}}"

# 硬拦截模式（无 dry-run 豁免）
declare -a BLOCK_PATTERNS=(
  'rm[[:space:]]+-rf[[:space:]]+/'
  'chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+/'
  'mkfs\.'
  'dd[[:space:]]+if=.+of=/dev/'
)

for pattern in "${BLOCK_PATTERNS[@]}"; do
  if echo "$INPUT" | grep -qE "$pattern"; then
    hook_log "BLOCK" "检测到高危命令模式，已拦截: $pattern"
    exit $EXIT_BLOCK
  fi
done

exit $EXIT_OK
