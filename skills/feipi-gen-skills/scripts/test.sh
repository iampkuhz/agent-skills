#!/usr/bin/env bash
set -euo pipefail

# feipi-gen-skills 自测入口。
# 目标：校验当前 skill 的结构有效，且"版本递增/同日合并/changelog 极简"规则保持一致。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 测试项内联，避免过度工程化
echo "=== feipi-gen-skills 自测 ==="

FAILED=0

# Test 1: validate-self - 检查 SKILL.md 存在
if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
  echo "[PASS] validate-self: SKILL.md 存在"
else
  echo "[FAIL] validate-self: SKILL.md 不存在" >&2
  FAILED=1
fi

# Test 2: check-version-rule - 检查版本规则描述存在
if grep -q "当天首次修改时递增" "$SKILL_DIR/SKILL.md" && \
   grep -q "当天首次修改时递增" "$SKILL_DIR/agents/openai.yaml" && \
   grep -q "当天首次修改时递增" "$SKILL_DIR/references/repo-constraints.md"; then
  echo "[PASS] check-version-rule: 版本规则描述一致"
else
  echo "[FAIL] check-version-rule: 版本规则描述缺失" >&2
  FAILED=1
fi

# Test 3: check-changelog-rule - 检查 changelog 极简规则存在
if grep -q "极致精简（强制）" "$SKILL_DIR/references/changelog-policy.md" && \
   grep -q "同一天同一个 skill 只允许" "$SKILL_DIR/references/changelog-policy.md" && \
   grep -q "18 个汉字" "$SKILL_DIR/references/changelog-policy.md"; then
  echo "[PASS] check-changelog-rule: changelog 极简规则存在"
else
  echo "[FAIL] check-changelog-rule: changelog 极简规则缺失" >&2
  FAILED=1
fi

echo "=== 自测完成 ==="
if [[ $FAILED -eq 0 ]]; then
  echo "结果：全部通过"
  exit 0
else
  echo "结果：存在失败" >&2
  exit 1
fi
