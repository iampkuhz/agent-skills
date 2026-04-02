#!/usr/bin/env bash
set -euo pipefail

# Skill 目录结构校验脚本
# 用法：bash scripts/validate.sh <skill-dir>

usage() {
  cat <<'USAGE'
用法:
  bash scripts/validate.sh <skill-dir>
USAGE
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SKILL_INPUT="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_TOOL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_TOOL_DIR/../.." && pwd)"
SHARED_VALIDATE="$REPO_ROOT/feipi-scripts/repo/quick_validate.sh"

if [[ ! -x "$SHARED_VALIDATE" ]]; then
  echo "缺少共享校验脚本: $SHARED_VALIDATE" >&2
  exit 1
fi

if [[ -d "$SKILL_INPUT" ]]; then
  TARGET_DIR="$(cd "$SKILL_INPUT" && pwd)"
elif [[ -d "$REPO_ROOT/$SKILL_INPUT" ]]; then
  TARGET_DIR="$(cd "$REPO_ROOT/$SKILL_INPUT" && pwd)"
else
  echo "错误：目录不存在：$SKILL_INPUT" >&2
  exit 1
fi

SKILL_FILE="$TARGET_DIR/SKILL.md"
OPENAI_FILE="$TARGET_DIR/agents/openai.yaml"
TEST_SCRIPT="$TARGET_DIR/scripts/test.sh"

echo "=== 校验 skill 目录：$TARGET_DIR ==="

bash "$SHARED_VALIDATE" "$TARGET_DIR" >/dev/null
echo "[PASS] 共享结构校验通过"

if [[ ! -f "$OPENAI_FILE" ]]; then
  echo "[FAIL] 缺少 agents/openai.yaml" >&2
  exit 1
fi
echo "[PASS] agents/openai.yaml 存在"

if ! rg -q '^version:[[:space:]]*[0-9]+[[:space:]]*$' "$OPENAI_FILE"; then
  echo "[FAIL] agents/openai.yaml 的 version 必须是顶层整数" >&2
  exit 1
fi
echo "[PASS] version 字段为顶层整数"

for field in display_name short_description default_prompt; do
  if ! rg -q "^[[:space:]]+$field:[[:space:]]*.+$" "$OPENAI_FILE"; then
    echo "[FAIL] agents/openai.yaml 缺少非空字段: $field" >&2
    exit 1
  fi
done
echo "[PASS] interface 关键字段齐全"

if [[ ! -x "$TEST_SCRIPT" ]]; then
  echo "[FAIL] 缺少可执行测试脚本: $TEST_SCRIPT" >&2
  exit 1
fi
echo "[PASS] scripts/test.sh 可执行"

placeholders=()
for placeholder_name in \
  SKILL_NAME \
  SKILL_DESCRIPTION \
  TITLE \
  DISPLAY_NAME \
  SHORT_DESCRIPTION \
  DEFAULT_PROMPT
do
  placeholders+=("$(printf '%s%s%s' '{{' "$placeholder_name" '}}')")
done

for placeholder in "${placeholders[@]}"; do
  if rg -F "$placeholder" "$TARGET_DIR" >/dev/null 2>&1; then
    echo "[FAIL] 检测到未替换模板占位符: $placeholder" >&2
    rg -Fn "$placeholder" "$TARGET_DIR" >&2 || true
    exit 1
  fi
done
echo "[PASS] 无未替换模板占位符"

while IFS= read -r script_path; do
  [[ -z "$script_path" ]] && continue
  bash -n "$script_path"
done < <(find "$TARGET_DIR/scripts" -maxdepth 1 -type f -name '*.sh' | sort)
echo "[PASS] scripts/*.sh 语法检查通过"

while IFS= read -r ref_path; do
  [[ -z "$ref_path" ]] && continue
  if [[ ! -e "$TARGET_DIR/$ref_path" ]]; then
    echo "[FAIL] SKILL.md 引用了不存在的路径: $ref_path" >&2
    exit 1
  fi
done < <(rg -o 'references/[A-Za-z0-9._/-]+\.md|scripts/[A-Za-z0-9._/-]+\.sh' "$SKILL_FILE" | sort -u)
echo "[PASS] SKILL.md 中的资源路径可解析"

if [[ "$(basename "$TARGET_DIR")" == "feipi-gen-skills" ]]; then
  for shared_path in \
    "$REPO_ROOT/templates/SKILL.template.md" \
    "$REPO_ROOT/templates/openai.template.yaml" \
    "$REPO_ROOT/templates/test.template.sh" \
    "$REPO_ROOT/feipi-scripts/repo/init_skill.sh" \
    "$REPO_ROOT/feipi-scripts/repo/quick_validate.sh"
  do
    if [[ ! -e "$shared_path" ]]; then
      echo "[FAIL] 缺少直接关联的共享文件: $shared_path" >&2
      exit 1
    fi
  done
  echo "[PASS] 直接关联的共享脚手架文件齐全"
fi

echo "校验通过: $TARGET_DIR"
