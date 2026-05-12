#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="$SCRIPT_DIR/tests"

PASS=0
FAIL=0

pass() {
  echo "[PASS] $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "[FAIL] $1" >&2
  FAIL=$((FAIL + 1))
}

check_json_field() {
  local json_file="$1"
  local field="$2"
  local expected="$3"
  local label="$4"
  local actual
  actual="$(python3 -c "import json; print(json.load(open('${json_file}'))['${field}'])")"
  if [[ "$actual" == "$expected" ]]; then
    pass "${label}"
  else
    fail "${label}：期望 '${expected}'，实际 '${actual}'"
  fi
}

check_json_field_in() {
  local json_file="$1"
  local field="$2"
  local label="$3"
  shift 3
  local values=("$@")
  local actual
  actual="$(python3 -c "import json; print(json.load(open('${json_file}'))['${field}'])")"
  local found=false
  for v in "${values[@]}"; do
    if [[ "$actual" == "$v" ]]; then
      found=true
      break
    fi
  done
  if [[ "$found" == "true" ]]; then
    pass "${label}：${actual}"
  else
    fail "${label}：期望 ${values[*]}，实际 '${actual}'"
  fi
}

run_validate() {
  local out_dir="$1"; shift
  rm -rf "$out_dir"
  bash "$SCRIPT_DIR/validate_package.sh" "$@" --out-dir "$out_dir" 2>/dev/null || true
}

# =============================================================================
# Step 1: 结构校验
# =============================================================================
echo "=== Step 1: 结构校验 ==="
bash "$SCRIPT_DIR/validate.sh" "$SKILL_DIR" >/dev/null && pass "结构校验" || fail "结构校验"

# =============================================================================
# Step 2: 样例文件存在
# =============================================================================
echo "=== Step 2: 样例文件 ==="
FALLBACK_DIAGRAM="$SKILL_DIR/assets/examples/fallback/fallback-diagram.example.puml"
ARCH_BRIEF="$SKILL_DIR/assets/examples/architecture/architecture-brief.example.yaml"
ARCH_DIAGRAM="$SKILL_DIR/assets/examples/architecture/architecture-diagram.example.puml"
SEQ_BRIEF="$SKILL_DIR/assets/examples/sequence/sequence-brief.example.yaml"
SEQ_DIAGRAM="$SKILL_DIR/assets/examples/sequence/sequence-diagram.example.puml"
SERVER_CANDIDATES="$SKILL_DIR/assets/server_candidates.txt"
for f in "$FALLBACK_DIAGRAM" "$ARCH_BRIEF" "$ARCH_DIAGRAM" "$SEQ_BRIEF" "$SEQ_DIAGRAM" "$SERVER_CANDIDATES"; do
  if [[ -f "$f" ]]; then
    pass "文件存在：$(basename "$f")"
  else
    fail "缺少文件：$f"
  fi
done

# =============================================================================
# Step 3: Fallback 正向验证
# =============================================================================
echo "=== Step 3: Fallback 正向验证 ==="
FALLBACK_OUT="/tmp/plantuml-fallback-smoke-test"
run_validate "$FALLBACK_OUT" --diagram "$FALLBACK_DIAGRAM" --diagram-type fallback

if [[ -f "$FALLBACK_OUT/validation.json" ]]; then
  pass "validation.json 已生成"
  check_json_field "$FALLBACK_OUT/validation.json" skill_name "feipi-plantuml-generate-diagram" "skill_name"
  check_json_field "$FALLBACK_OUT/validation.json" diagram_type "fallback" "diagram_type"
  check_json_field "$FALLBACK_OUT/validation.json" profile "fallback" "profile"
  check_json_field_in "$FALLBACK_OUT/validation.json" final_status "final_status" "success" "render_server_unavailable"
else
  fail "validation.json 未生成"
fi

# =============================================================================
# Step 4: Fallback 负向验证（缺 @enduml）
# =============================================================================
echo "=== Step 4: Fallback 负向验证 ==="
INVALID_DIAGRAM="$TEST_DIR/invalid-missing-enduml.puml"
INVALID_OUT="/tmp/plantuml-fallback-invalid-test"
rm -rf "$INVALID_OUT"

if bash "$SCRIPT_DIR/validate_package.sh" \
  --diagram "$INVALID_DIAGRAM" \
  --diagram-type fallback \
  --out-dir "$INVALID_OUT" 2>/dev/null; then
  fail "负向用例应该被拦截"
else
  if [[ -f "$INVALID_OUT/validation.json" ]]; then
    check_json_field "$INVALID_OUT/validation.json" final_status "blocked" "负向用例正确拦截"
  else
    fail "负向用例未生成 validation.json"
  fi
fi

# =============================================================================
# Step 5: Architecture 正向验证
# =============================================================================
echo "=== Step 5: Architecture 正向验证 ==="
ARCH_OUT="/tmp/plantuml-arch-smoke-test"
run_validate "$ARCH_OUT" \
  --diagram-type architecture \
  --brief "$ARCH_BRIEF" \
  --diagram "$ARCH_DIAGRAM"

if [[ -f "$ARCH_OUT/validation.json" ]]; then
  pass "architecture validation.json 已生成"
  check_json_field "$ARCH_OUT/validation.json" diagram_type "architecture" "diagram_type"
  check_json_field "$ARCH_OUT/validation.json" profile "architecture" "profile"
  check_json_field "$ARCH_OUT/validation.json" brief_check "ok" "brief_check"
  check_json_field "$ARCH_OUT/validation.json" coverage_check "ok" "coverage_check"
  check_json_field "$ARCH_OUT/validation.json" layout_check "ok" "layout_check"
  check_json_field_in "$ARCH_OUT/validation.json" final_status "final_status" "success" "render_server_unavailable"
else
  fail "architecture validation.json 未生成"
fi

# =============================================================================
# Step 6: Architecture 负向验证（缺组件/缺流程）
# =============================================================================
echo "=== Step 6: Architecture 负向验证 ==="
ARCH_NEG_OUT="/tmp/plantuml-arch-neg-test"
rm -rf "$ARCH_NEG_OUT"

if bash "$SCRIPT_DIR/validate_package.sh" \
  --diagram-type architecture \
  --brief "$ARCH_BRIEF" \
  --diagram "$TEST_DIR/architecture-invalid-diagram.puml" \
  --out-dir "$ARCH_NEG_OUT" 2>/dev/null; then
  fail "architecture 负向用例应该被拦截"
else
  if [[ -f "$ARCH_NEG_OUT/validation.json" ]]; then
    STATUS="$(python3 -c "import json; print(json.load(open('$ARCH_NEG_OUT/validation.json'))['final_status'])")"
    if [[ "$STATUS" == "blocked" ]]; then
      pass "architecture 负向用例正确拦截"
    else
      fail "architecture 负向用例 final_status 不是 blocked：$STATUS"
    fi
  else
    fail "architecture 负向用例未生成 validation.json"
  fi
fi

# =============================================================================
# Step 7: Sequence 正向验证
# =============================================================================
echo "=== Step 7: Sequence 正向验证 ==="
SEQ_OUT="/tmp/plantuml-seq-smoke-test"
run_validate "$SEQ_OUT" \
  --diagram-type sequence \
  --brief "$SEQ_BRIEF" \
  --diagram "$SEQ_DIAGRAM"

if [[ -f "$SEQ_OUT/validation.json" ]]; then
  pass "sequence validation.json 已生成"
  check_json_field "$SEQ_OUT/validation.json" diagram_type "sequence" "diagram_type"
  check_json_field "$SEQ_OUT/validation.json" profile "sequence" "profile"
  check_json_field "$SEQ_OUT/validation.json" brief_check "ok" "brief_check"
  check_json_field "$SEQ_OUT/validation.json" coverage_check "ok" "coverage_check"
  check_json_field "$SEQ_OUT/validation.json" layout_check "ok" "layout_check"
  check_json_field_in "$SEQ_OUT/validation.json" final_status "final_status" "success" "render_server_unavailable"
else
  fail "sequence validation.json 未生成"
fi

# =============================================================================
# Step 8: Sequence 负向验证（额外消息/缺 separator）
# =============================================================================
echo "=== Step 8: Sequence 负向验证 ==="
SEQ_NEG_EXTRA="/tmp/plantuml-seq-neg-extra-test"
rm -rf "$SEQ_NEG_EXTRA"

if bash "$SCRIPT_DIR/validate_package.sh" \
  --diagram-type sequence \
  --brief "$SEQ_BRIEF" \
  --diagram "$TEST_DIR/sequence-extra-message-diagram.puml" \
  --out-dir "$SEQ_NEG_EXTRA" 2>/dev/null; then
  fail "sequence 额外消息用例应该被拦截"
else
  if [[ -f "$SEQ_NEG_EXTRA/validation.json" ]]; then
    check_json_field "$SEQ_NEG_EXTRA/validation.json" final_status "blocked" "sequence 额外消息正确拦截"
  else
    fail "sequence 额外消息用例未生成 validation.json"
  fi
fi

SEQ_NEG_SEP="/tmp/plantuml-seq-neg-sep-test"
rm -rf "$SEQ_NEG_SEP"

if bash "$SCRIPT_DIR/validate_package.sh" \
  --diagram-type sequence \
  --brief "$SEQ_BRIEF" \
  --diagram "$TEST_DIR/sequence-missing-separator-diagram.puml" \
  --out-dir "$SEQ_NEG_SEP" 2>/dev/null; then
  fail "sequence 缺 separator 用例应该被拦截"
else
  if [[ -f "$SEQ_NEG_SEP/validation.json" ]]; then
    check_json_field "$SEQ_NEG_SEP/validation.json" final_status "blocked" "sequence 缺 separator 正确拦截"
  else
    fail "sequence 缺 separator 用例未生成 validation.json"
  fi
fi

# =============================================================================
# Step 9: Python 语法与 Shell 语法检查
# =============================================================================
echo "=== Step 9: 脚本语法检查 ==="
if python3 -m py_compile $(find "$SCRIPT_DIR" -type f -name '*.py' | sort) 2>/dev/null; then
  pass "Python 语法检查"
else
  fail "Python 语法检查"
fi
if find "$SCRIPT_DIR" -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n 2>/dev/null; then
  pass "Shell 语法检查"
else
  fail "Shell 语法检查"
fi

# =============================================================================
# Step 10: 触发边界一致 & 旧 skill 保护
# =============================================================================
echo "=== Step 10: 触发边界 & 旧 skill 保护 ==="
if rg -q 'fallback' "$SKILL_DIR/SKILL.md"; then
  pass "SKILL.md 包含 fallback"
else
  fail "SKILL.md 缺少 fallback"
fi
ARCH_OLD_SKILL="skills/diagram/feipi-plantuml-generate-architecture-diagram/SKILL.md"
SEQ_OLD_SKILL="skills/diagram/feipi-plantuml-generate-sequence-diagram/SKILL.md"
if [[ -f "$ARCH_OLD_SKILL" && -f "$SEQ_OLD_SKILL" ]]; then
  pass "旧 skill 未被删除"
else
  fail "旧 skill 已被删除"
fi

# =============================================================================
# 总结
# =============================================================================
echo ""
echo "=== 测试总结 ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  echo "测试失败" >&2
  exit 1
fi

echo "测试通过：feipi-plantuml-generate-diagram"
