#!/usr/bin/env bash
# pre-commit hook: 校验 skill 命名规范
# 规则: feipi-<domain>-<action>-<object...>，skill 目录名以 feipi- 开头
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHANGED_DIRS="$(git diff --cached --name-only --diff-filter=AM 2>/dev/null \
  | grep '^skills/' \
  | sed 's|/.*||' \
  | sort -u \
  | while read -r dir; do
      full="$REPO_ROOT/$dir"
      # 只检查第二层（layer/<skill-name>）
      if [[ "$(echo "$dir" | tr '/' '\n' | wc -l)" -ge 3 ]]; then
        dirname "$dir"
      fi
    done | sort -u || true)"

if [[ -z "$CHANGED_DIRS" ]]; then
  exit 0
fi

FAIL=0
while IFS= read -r skill_dir_rel; do
  skill_dir="$REPO_ROOT/$skill_dir_rel"
  [[ ! -d "$skill_dir" ]] && continue
  skill_name="$(basename "$skill_dir")"

  # 检查以 feipi- 开头
  if [[ ! "$skill_name" =~ ^feipi- ]]; then
    echo "[FAIL] skill 目录名必须以 feipi- 开头: $skill_dir_rel" >&2
    FAIL=1
  fi

  # 检查不包含 {{ 模板占位符
  if [[ -f "$skill_dir/SKILL.md" ]]; then
    if rg -Fq '{{' "$skill_dir/SKILL.md" 2>/dev/null; then
      echo "[FAIL] SKILL.md 包含未替换模板占位符: $skill_dir_rel" >&2
      FAIL=1
    fi
  fi

done <<< "$CHANGED_DIRS"

if [[ $FAIL -ne 0 ]]; then
  echo "[hook] 命名规范检查失败" >&2
  exit 1
fi

echo "[hook] 命名规范检查通过"
