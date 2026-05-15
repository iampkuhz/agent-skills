#!/usr/bin/env bash
# scripts/repo/check_context_hygiene.sh
# 检查规约上下文卫生：入口文档大小、rules/ 内容、commands/ 结构、SKILL.md description 长度
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
REPO_ROOT="$(find_git_root)"

# --- 阈值（可环境变量覆盖） ---
MAX_AGENTS_LINES="${MAX_AGENTS_LINES:-100}"
MAX_CLAUDE_MD_LINES="${MAX_CLAUDE_MD_LINES:-80}"
MAX_README_LINES="${MAX_README_LINES:-150}"
MAX_SKILL_DESC_LENGTH="${MAX_SKILL_DESC_LENGTH:-200}"

warns=0
blocks=0

# --- 1. AGENTS.md 行数 ---
if [[ -f "$REPO_ROOT/AGENTS.md" ]]; then
  lines=$(wc -l < "$REPO_ROOT/AGENTS.md" | tr -d ' ')
  if [[ "$lines" -gt "$MAX_AGENTS_LINES" ]]; then
    log_warn "AGENTS.md" "has ${lines} lines (limit: ${MAX_AGENTS_LINES})"
    ((warns++))
  else
    log_pass "AGENTS.md" "${lines} lines (limit: ${MAX_AGENTS_LINES})"
  fi
else
  log_skip "AGENTS.md" "not found"
fi

# --- 2. CLAUDE.md 行数 ---
if [[ -f "$REPO_ROOT/CLAUDE.md" ]]; then
  lines=$(wc -l < "$REPO_ROOT/CLAUDE.md" | tr -d ' ')
  if [[ "$lines" -gt "$MAX_CLAUDE_MD_LINES" ]]; then
    log_warn "CLAUDE.md" "has ${lines} lines (limit: ${MAX_CLAUDE_MD_LINES})"
    ((warns++))
  else
    log_pass "CLAUDE.md" "${lines} lines (limit: ${MAX_CLAUDE_MD_LINES})"
  fi
else
  log_skip "CLAUDE.md" "not found"
fi

# --- 3. README.md 行数 ---
if [[ -f "$REPO_ROOT/README.md" ]]; then
  lines=$(wc -l < "$REPO_ROOT/README.md" | tr -d ' ')
  if [[ "$lines" -gt "$MAX_README_LINES" ]]; then
    log_warn "README.md" "has ${lines} lines (limit: ${MAX_README_LINES})"
    ((warns++))
  else
    log_pass "README.md" "${lines} lines (limit: ${MAX_README_LINES})"
  fi
else
  log_skip "README.md" "not found"
fi

# --- 4. rules/*/.gitkeep 非空检查 ---
for gitkeep in "$REPO_ROOT"/rules/*/.gitkeep; do
  [[ -f "$gitkeep" ]] || continue
  rel_path="${gitkeep#$REPO_ROOT/}"
  # 去除空行和注释后检查是否还有内容
  content_lines=$(grep -cvE '^\s*(#.*)?$' "$gitkeep" 2>/dev/null || true)
  content_lines=$(echo "$content_lines" | tr -d '[:space:]')
  if [[ -n "$content_lines" && "$content_lines" -gt 0 ]]; then
    byte_size=$(wc -c < "$gitkeep" | tr -d ' ')
    log_warn "$rel_path" "contains ${byte_size} bytes of rule text (should be empty or comments only)"
    ((warns++))
  else
    log_pass "$rel_path" "clean (no rule text)"
  fi
done

# --- 5. commands/ 空壳检查 ---
if [[ -d "$REPO_ROOT/commands" ]]; then
  has_actual=false
  for subdir in "$REPO_ROOT"/commands/*/; do
    [[ -d "$subdir" ]] || continue
    # 检查子目录中是否有除 .gitkeep 和 README* 之外的文件
    while IFS= read -r -d '' f; do
      base=$(basename "$f")
      if [[ "$base" != ".gitkeep" && ! "$base" =~ ^README ]]; then
        has_actual=true
        break
      fi
    done < <(find "$subdir" -maxdepth 2 -type f -print0 2>/dev/null)
    $has_actual && break
  done
  if $has_actual; then
    log_pass "commands/" "contains actual command files"
  else
    log_warn "commands/" "no actual command files found — shell only (by design if retired)"
    ((warns++))
  fi
else
  log_skip "commands/" "directory not found"
fi

# --- 6. SKILL.md description 长度 ---
while IFS= read -r -d '' skill_md; do
  rel_path="${skill_md#$REPO_ROOT/}"
  desc=$(extract_frontmatter "$skill_md" "description")
  if [[ -z "$desc" ]]; then
    log_warn "$rel_path" "missing description field in frontmatter"
    ((warns++))
    continue
  fi
  desc_len=${#desc}
  if [[ "$desc_len" -gt "$MAX_SKILL_DESC_LENGTH" ]]; then
    log_warn "$rel_path" "description is ${desc_len} chars (limit: ${MAX_SKILL_DESC_LENGTH})"
    ((warns++))
  else
    log_pass "$rel_path" "description ${desc_len} chars OK"
  fi
done < <(find "$REPO_ROOT" -name "SKILL.md" -type f -not -path "*/.venv/*" -not -path "*/node_modules/*" -print0 2>/dev/null)

exit_with_status "$warns" "$blocks"
