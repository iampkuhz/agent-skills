#!/usr/bin/env bash
# scripts/repo/lib/common.sh
# 共享库：供 scripts/repo/ 下所有检查脚本使用

# --- 退出码约定 ---
EXIT_OK=0          # 检查通过
EXIT_WARN=1        # 存在告警（不阻塞）
EXIT_BLOCK=2       # 存在阻塞问题
EXIT_SKIP=3        # 不适用/跳过

# --- 仓库根目录 ---
_repo_root=""
find_git_root() {
  local env_root="${REPO_ROOT:-}"
  if [[ -n "$env_root" && -d "$env_root" ]]; then
    _repo_root="$env_root"
  elif git rev-parse --show-toplevel >/dev/null 2>&1; then
    _repo_root="$(git rev-parse --show-toplevel)"
  else
    _repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  fi
  echo "$_repo_root"
}

# --- 日志函数：统一输出格式 [STATUS] path message ---
log_pass() {
  echo "[PASS] ${1:-} ${2:-}"
}

log_warn() {
  echo "[WARN] ${1:-} ${2:-}"
}

log_block() {
  echo "[BLOCK] ${1:-} ${2:-}"
}

log_skip() {
  echo "[SKIP] ${1:-} ${2:-}"
}

log_info() {
  echo "[INFO] ${1:-} ${2:-}"
}

# --- 根据收集到的告警/阻塞数量计算退出码 ---
# 用法：exit_with_status <warn_count> <block_count>
exit_with_status() {
  local warns="${1:-0}" blocks="${2:-0}"
  if [[ "$blocks" -gt 0 ]]; then
    exit $EXIT_BLOCK
  elif [[ "$warns" -gt 0 ]]; then
    exit $EXIT_WARN
  else
    exit $EXIT_OK
  fi
}

# --- 路径存在性检查 ---
check_path_exists() {
  local path="$1"
  [[ -e "$path" ]]
}

# --- 提取 markdown 内部链接（返回本地相对路径） ---
# 输出格式：每行一个路径，排除 http(s):// 和纯锚点 # 链接
extract_markdown_links() {
  local file="$1"
  grep -oE '\[([^]]*)\]\(([^)]+)\)' "$file" 2>/dev/null \
    | sed -E 's/\[.*\]\(([^)]+)\)/\1/' \
    | grep -vE '^(https?://|#)' \
    | grep -vE '^\s*$' \
    || true
}

# --- 提取 YAML frontmatter 字段值 ---
# 用法：extract_frontmatter <file> <field_name>
extract_frontmatter() {
  local file="$1" field="$2"
  awk -v f="$field" '
    /^---$/ { if (n==0) {n=1; next} else {exit} }
    n==1 && $0 ~ "^"f":" { sub(/^"[^"]*":[ ]*/, ""); print; found=1; exit }
  ' "$file" 2>/dev/null
}

# --- 文件非空检查（去除空行和注释后是否还有内容） ---
file_has_content() {
  local file="$1"
  [[ ! -f "$file" ]] && return 1
  grep -qvE '^\s*(#.*)?$' "$file" 2>/dev/null
}
