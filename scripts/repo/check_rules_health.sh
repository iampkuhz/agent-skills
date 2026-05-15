#!/usr/bin/env bash
# scripts/repo/check_rules_health.sh
# 检查 rules/ 目录健康度：规则文件存在性、内容、死链、空目录
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
REPO_ROOT="$(find_git_root)"

warns=0
blocks=0

# --- 1. rules/ 目录存在性 ---
if [[ -d "$REPO_ROOT/rules" ]]; then
  log_pass "rules/" "directory exists"
else
  log_block "rules/" "directory not found"
  ((blocks++))
  exit_with_status "$warns" "$blocks"
fi

# --- 2. rules/README.md 存在性 ---
if [[ -f "$REPO_ROOT/rules/README.md" ]] && file_has_content "$REPO_ROOT/rules/README.md"; then
  log_pass "rules/README.md" "exists and has content"
else
  log_warn "rules/README.md" "missing or empty"
  ((warns++))
fi

# --- 3. 空目录检测 ---
for subdir in "$REPO_ROOT"/rules/*/; do
  [[ -d "$subdir" ]] || continue
  rel_dir="${subdir#$REPO_ROOT/}"
  has_md=false
  for f in "$subdir"*.md; do
    [[ -f "$f" ]] && has_md=true && break
  done
  if ! $has_md; then
    log_warn "$rel_dir" "empty rule directory (no .md files)"
    ((warns++))
  else
    log_pass "$rel_dir" "contains rule files"
  fi
done

# --- 4. 规则文件内容检测 ---
while IFS= read -r -d '' rule_md; do
  rel_path="${rule_md#$REPO_ROOT/}"
  if file_has_content "$rule_md"; then
    log_pass "$rel_path" "has content"
  else
    log_warn "$rel_path" "empty or only frontmatter/comments"
    ((warns++))
  fi
done < <(find "$REPO_ROOT/rules" -name "*.md" -type f -print0 2>/dev/null)

# --- 5. 内部路径引用检测（死链） ---
while IFS= read -r -d '' rule_md; do
  rel_path="${rule_md#$REPO_ROOT/}"
  rule_dir="$(dirname "$rule_md")"
  while IFS= read -r link; do
    # 解析相对路径
    target="$(cd "$rule_dir" 2>/dev/null && cd "$(dirname "$link")" 2>/dev/null && pwd)/$(basename "$link")"
    # 移除锚点
    target="${target%%#*}"
    if [[ -e "$target" ]]; then
      log_pass "$rel_path" "link '$link' -> valid"
    else
      log_warn "$rel_path" "references non-existent path: $link"
      ((warns++))
    fi
  done < <(extract_markdown_links "$rule_md")
done < <(find "$REPO_ROOT/rules" -name "*.md" -type f -print0 2>/dev/null)

# --- 6. global/language.md 唯一真实规则确认 ---
if [[ -f "$REPO_ROOT/rules/global/language.md" ]]; then
  log_pass "rules/global/language.md" "exists (the only active rule)"
else
  log_block "rules/global/language.md" "not found — this is the primary rule file"
  ((blocks++))
fi

exit_with_status "$warns" "$blocks"
