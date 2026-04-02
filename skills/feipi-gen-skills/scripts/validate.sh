#!/usr/bin/env bash
set -euo pipefail

# Skill 目录结构校验脚本
# 用法：bash scripts/validate.sh <skill-dir>

SKILL_DIR="${1:-.}"

if [[ ! -d "$SKILL_DIR" ]]; then
  echo "错误：目录不存在：$SKILL_DIR" >&2
  exit 1
fi

echo "=== 校验 skill 目录：$SKILL_DIR ==="

FAILED=0

# 必需文件检查
if [[ ! -f "$SKILL_DIR/SKILL.md" ]]; then
  echo "[FAIL] 缺少 SKILL.md" >&2
  FAILED=1
else
  echo "[PASS] SKILL.md 存在"
fi

if [[ ! -f "$SKILL_DIR/agents/openai.yaml" ]]; then
  echo "[FAIL] 缺少 agents/openai.yaml" >&2
  FAILED=1
else
  echo "[PASS] agents/openai.yaml 存在"
fi

# Frontmatter 检查
if grep -q "^---$" "$SKILL_DIR/SKILL.md" && \
   grep -q "^name:" "$SKILL_DIR/SKILL.md" && \
   grep -q "^description:" "$SKILL_DIR/SKILL.md"; then
  echo "[PASS] Frontmatter 格式正确"
else
  echo "[FAIL] Frontmatter 缺少 name 或 description" >&2
  FAILED=1
fi

# version 字段检查
if grep -q "^version:" "$SKILL_DIR/agents/openai.yaml"; then
  echo "[PASS] version 字段存在"
else
  echo "[FAIL] 缺少 version 字段" >&2
  FAILED=1
fi

# scripts/test.sh 存在性检查
if [[ -f "$SKILL_DIR/scripts/test.sh" ]]; then
  echo "[PASS] scripts/test.sh 存在"
else
  echo "[WARN] 缺少 scripts/test.sh（建议添加）"
fi

echo "=== 校验完成 ==="
if [[ $FAILED -eq 0 ]]; then
  echo "结果：通过"
  exit 0
else
  echo "结果：失败" >&2
  exit 1
fi
