#!/usr/bin/env bash
# pre-commit hook: 校验 SKILL.md frontmatter 格式
# 规则: 必须有 --- 包裹, name 和 description 非空, 不含 XML 标签
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHANGED_FILES="$(git diff --cached --name-only --diff-filter=AM 2>/dev/null | grep -E '(^|/)SKILL\.md$' || true)"

if [[ -z "$CHANGED_FILES" ]]; then
  exit 0
fi

FAIL=0
while IFS= read -r skill_file; do
  full_path="$REPO_ROOT/$skill_file"
  [[ ! -f "$full_path" ]] && continue

  # 检查 frontmatter 包裹
  if ! head -1 "$full_path" | grep -q '^---$'; then
    echo "[FAIL] SKILL.md 必须以 --- 开头: $skill_file" >&2
    FAIL=1
    continue
  fi

  # 提取 frontmatter (到第二个 ---)
  frontmatter="$(sed -n '1,/^---$/p' "$full_path")"

  # 检查 name 非空
  if ! echo "$frontmatter" | grep -qE '^name:[[:space:]]+.+'; then
    echo "[FAIL] frontmatter name 为空或缺失: $skill_file" >&2
    FAIL=1
  fi

  # 检查 description 非空
  if ! echo "$frontmatter" | grep -qE '^description:[[:space:]]+.+'; then
    echo "[FAIL] frontmatter description 为空或缺失: $skill_file" >&2
    FAIL=1
  fi

  # 检查 description 长度 (硬上限 1024 字符)
  desc_line="$(echo "$frontmatter" | grep '^description:' | head -1 || true)"
  if [[ -n "$desc_line" ]]; then
    desc_value="${desc_line#description:[[:space:]]}"
    if [[ ${#desc_value} -gt 1024 ]]; then
      echo "[FAIL] frontmatter description 超过 1024 字符 (${#desc_value}): $skill_file" >&2
      FAIL=1
    fi
  fi

  # 检查不含 XML 标签
  if echo "$frontmatter" | grep -qE '<[a-zA-Z][^>]*>'; then
    echo "[FAIL] frontmatter 包含 XML 标签: $skill_file" >&2
    FAIL=1
  fi

done <<< "$CHANGED_FILES"

if [[ $FAIL -ne 0 ]]; then
  echo "[hook] frontmatter 校验失败" >&2
  exit 1
fi

echo "[hook] frontmatter 校验通过"
