#!/usr/bin/env bash
# .claude/hooks/lib/common.sh
# 所有 hook 脚本的 source 文件

# --- 退出码约定 ---
EXIT_OK=0          # 检查通过，允许继续
EXIT_WARN=1        # 检查有告警，记录但不阻塞（dry-run 模式总是此码）
EXIT_BLOCK=2       # 检查失败，阻塞操作
EXIT_SKIP=3        # 不适用当前文件/上下文，跳过

# --- 环境变量 ---
# HOOK_DRY_RUN=1 时所有检查降级为 WARN，不阻塞
HOOK_DRY_RUN="${HOOK_DRY_RUN:-1}"  # 默认 dry-run

# --- 日志函数 ---
hook_log() {
  local level="$1"; shift
  echo "[hook:$(basename "${BASH_SOURCE[1]:-unknown}")] [$level] $*" >&2
}

# --- 文件匹配辅助 ---
matches_glob() {
  local file="$1" pattern="$2"
  [[ "$file" == $pattern ]]
}

matches_any() {
  local file="$1"; shift
  for pattern in "$@"; do
    matches_glob "$file" "$pattern" && return 0
  done
  return 1
}
