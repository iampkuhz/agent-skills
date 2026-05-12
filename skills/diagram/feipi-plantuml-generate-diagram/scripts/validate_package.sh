#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# validate_package.sh - 统一 diagram package 验证入口
# =============================================================================
# 用法:
#   Fallback 模式:
#     bash scripts/validate_package.sh --diagram <diagram.puml> --out-dir <dir>
#     bash scripts/validate_package.sh --diagram <diagram.puml> --out-dir <dir> --diagram-type fallback
#
#   Typed profile 模式:
#     bash scripts/validate_package.sh --diagram-type <type> --brief <brief.yaml> --diagram <diagram.puml> --out-dir <dir>
#
# 产出物 (在 <out-dir> 中):
#   - diagram.puml           (输入的 diagram 原样复制)
#   - diagram.svg            (仅 render 成功时存在)
#   - validation.json        (验证结果合同)
#   - brief.normalized.yaml  (仅 typed profile，brief 复制)
#
# 退出码:
#   0 - final_status=success (所有校验通过且 render_result=ok)
#   1 - final_status=blocked (任一校验失败)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# 默认参数
DIAGRAM_TYPE="fallback"
BRIEF_FILE=""
DIAGRAM_FILE=""
OUT_DIR=""

# 解析参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --diagram-type)
      DIAGRAM_TYPE="$2"
      shift 2
      ;;
    --brief)
      BRIEF_FILE="$2"
      shift 2
      ;;
    --diagram)
      DIAGRAM_FILE="$2"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      cat <<'USAGE'
用法:
  Fallback 模式:
    bash scripts/validate_package.sh --diagram <diagram.puml> --out-dir <dir>
  Typed profile 模式:
    bash scripts/validate_package.sh --diagram-type <type> --brief <brief.yaml> --diagram <diagram.puml> --out-dir <dir>
USAGE
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      exit 1
      ;;
  esac
done

# 参数校验
if [[ -z "$DIAGRAM_FILE" || -z "$OUT_DIR" ]]; then
  echo "缺少必需参数：--diagram, --out-dir" >&2
  exit 1
fi

if [[ ! -f "$DIAGRAM_FILE" ]]; then
  echo "diagram 文件不存在：$DIAGRAM_FILE" >&2
  exit 1
fi

# Typed profile 必须有 brief
IS_TYPED=false
if [[ "$DIAGRAM_TYPE" != "fallback" ]]; then
  IS_TYPED=true
  if [[ -z "$BRIEF_FILE" ]]; then
    echo "typed profile 缺少必需参数：--brief" >&2
    exit 1
  fi
  if [[ ! -f "$BRIEF_FILE" ]]; then
    echo "brief 文件不存在：$BRIEF_FILE" >&2
    exit 1
  fi
fi

# 创建输出目录
mkdir -p "$OUT_DIR"

# 输出文件路径
DIAGRAM_OUT="$OUT_DIR/diagram.puml"
SVG_OUT="$OUT_DIR/diagram.svg"
VALIDATION_OUT="$OUT_DIR/validation.json"
BRIEF_OUT=""

# 复制输入文件到输出目录
cp -f "$DIAGRAM_FILE" "$DIAGRAM_OUT"
if [[ "$IS_TYPED" == "true" && -n "$BRIEF_FILE" ]]; then
  BRIEF_OUT="$OUT_DIR/brief.normalized.yaml"
  cp -f "$BRIEF_FILE" "$BRIEF_OUT"
fi

# =============================================================================
# 用 Python 写 validation.json，避免 shell 拼接 JSON
# =============================================================================
write_json() {
  local brief_path="${8:-}"
  python3 "$LIB_DIR/write_validation.py" \
    --output "$VALIDATION_OUT" \
    --skill-name "feipi-plantuml-generate-diagram" \
    --diagram-type "$DIAGRAM_TYPE" \
    --profile "$DIAGRAM_TYPE" \
    --diagram-path "$DIAGRAM_OUT" \
    --svg-path "$SVG_OUT" \
    --brief-path "$brief_path" \
    --brief-check "$1" \
    --coverage-check "$2" \
    --layout-check "$3" \
    --render-result "$4" \
    --render-server "${5:-}" \
    --final-status "$6" \
    --blocked-reason "${7:-}"
}

# =============================================================================
# Step 0: 基础结构校验（所有类型都必须通过）
# =============================================================================
echo "Step 0: Validating basic structure..."

DIAGRAM_CONTENT="$(cat "$DIAGRAM_FILE")"
if ! printf '%s\n' "$DIAGRAM_CONTENT" | grep -qE '^[[:space:]]*@startuml[[:space:]]*$'; then
  write_json "skipped" "skipped" "skipped" "skipped" "" "blocked" "missing_startuml"
  echo "[FAIL] diagram 缺少 @startuml" >&2
  exit 1
fi

if ! printf '%s\n' "$DIAGRAM_CONTENT" | grep -qE '^[[:space:]]*@enduml[[:space:]]*$'; then
  write_json "skipped" "skipped" "skipped" "skipped" "" "blocked" "missing_enduml"
  echo "[FAIL] diagram 缺少 @enduml" >&2
  exit 1
fi

echo "[OK] basic structure passed"

# =============================================================================
# Step 1: Validate Brief (仅 typed profile)
# =============================================================================
BRIEF_CHECK="skipped"
COVERAGE_CHECK="skipped"
LAYOUT_CHECK="skipped"

if [[ "$IS_TYPED" == "true" ]]; then
  echo "Step 1/4: Validating brief..."

  # 查找 schema 文件
  SCHEMA_FILE="$SKILL_DIR/assets/validation/types/${DIAGRAM_TYPE}-brief.schema.json"
  if [[ ! -f "$SCHEMA_FILE" ]]; then
    echo "[WARN] schema 文件不存在：$SCHEMA_FILE，跳过 brief 校验" >&2
    BRIEF_CHECK="skipped"
  else
    BRIEF_OUTPUT="$(python3 "$LIB_DIR/validate_brief_cli.py" "$BRIEF_FILE" --schema "$SCHEMA_FILE" 2>&1)" || {
      write_json "failed" "skipped" "skipped" "skipped" "" "blocked" "brief_validation_failed" "$BRIEF_OUT"
      echo "[FAIL] brief validation failed" >&2
      echo "$BRIEF_OUTPUT" >&2
      exit 1
    }
    BRIEF_CHECK="ok"
    echo "[OK] brief validation passed"
  fi

  # =============================================================================
  # Step 2: Check Coverage (仅 typed profile)
  # =============================================================================
  echo "Step 2/4: Checking coverage..."

  COVERAGE_SCRIPT="$SKILL_DIR/scripts/check_coverage.py"
  if [[ -f "$COVERAGE_SCRIPT" ]]; then
    COVERAGE_OUTPUT="$(python3 "$COVERAGE_SCRIPT" --type "$DIAGRAM_TYPE" --brief "$BRIEF_FILE" --diagram "$DIAGRAM_FILE" 2>&1)" || {
      write_json "$BRIEF_CHECK" "failed" "skipped" "skipped" "" "blocked" "coverage_validation_failed" "$BRIEF_OUT"
      echo "[FAIL] coverage check failed" >&2
      echo "$COVERAGE_OUTPUT" >&2
      exit 1
    }
    COVERAGE_CHECK="ok"
    echo "[OK] coverage check passed"
  else
    echo "[WARN] check_coverage.py 不存在，跳过覆盖校验" >&2
    COVERAGE_CHECK="skipped"
  fi

  # =============================================================================
  # Step 3: Lint Layout (仅 typed profile)
  # =============================================================================
  echo "Step 3/4: Linting layout..."

  LINT_SCRIPT="$SKILL_DIR/scripts/lint_layout.sh"
  if [[ -f "$LINT_SCRIPT" ]]; then
    LAYOUT_OUTPUT="$(bash "$LINT_SCRIPT" --type "$DIAGRAM_TYPE" "$DIAGRAM_FILE" 2>&1)" || {
      write_json "$BRIEF_CHECK" "$COVERAGE_CHECK" "failed" "skipped" "" "blocked" "layout_validation_failed" "$BRIEF_OUT"
      echo "[FAIL] layout check failed" >&2
      echo "$LAYOUT_OUTPUT" >&2
      exit 1
    }
    LAYOUT_CHECK="ok"
    echo "[OK] layout check passed"
  else
    echo "[WARN] lint_layout.sh 不存在，跳过布局校验" >&2
    LAYOUT_CHECK="skipped"
  fi
fi

# =============================================================================
# Step 4: Check Render
# =============================================================================
echo "Step 4/4: Checking render..."

RENDER_SCRIPT="$SCRIPT_DIR/check_render.sh"
if [[ -f "$RENDER_SCRIPT" ]]; then
  RENDER_OUTPUT="$(bash "$RENDER_SCRIPT" "$DIAGRAM_FILE" --svg-output "$SVG_OUT" 2>&1)" || {
    render_exit=$?
    if [[ "$render_exit" -eq 2 ]]; then
      write_json "$BRIEF_CHECK" "$COVERAGE_CHECK" "$LAYOUT_CHECK" "syntax_error" "" "blocked" "render_syntax_error" "$BRIEF_OUT"
      echo "[FAIL] render syntax error" >&2
      echo "$RENDER_OUTPUT" >&2
      exit 1
    elif [[ "$render_exit" -eq 4 ]]; then
      write_json "$BRIEF_CHECK" "$COVERAGE_CHECK" "$LAYOUT_CHECK" "skipped" "" "render_server_unavailable" "render_server_unavailable" "$BRIEF_OUT"
      echo "[FAIL] no render server available" >&2
      echo "$RENDER_OUTPUT" >&2
      exit 1
    else
      write_json "$BRIEF_CHECK" "$COVERAGE_CHECK" "$LAYOUT_CHECK" "failed" "" "blocked" "render_failed" "$BRIEF_OUT"
      echo "[FAIL] render failed" >&2
      echo "$RENDER_OUTPUT" >&2
      exit 1
    fi
  }

  if echo "$RENDER_OUTPUT" | grep -q "render_result=ok"; then
    RENDER_RESULT="ok"
    RENDER_SERVER="$(echo "$RENDER_OUTPUT" | grep "render_server=" | cut -d'=' -f2 || true)"
    echo "[OK] render passed, server: $RENDER_SERVER"
  else
    write_json "$BRIEF_CHECK" "$COVERAGE_CHECK" "$LAYOUT_CHECK" "failed" "" "blocked" "render_failed" "$BRIEF_OUT"
    echo "[FAIL] render failed" >&2
    exit 1
  fi
else
  echo "[WARN] check_render.sh 不存在，跳过渲染校验" >&2
  RENDER_RESULT="skipped"
  RENDER_SERVER=""
fi

# =============================================================================
# All checks passed
# =============================================================================
write_json "$BRIEF_CHECK" "$COVERAGE_CHECK" "$LAYOUT_CHECK" "$RENDER_RESULT" "$RENDER_SERVER" "success" "" "$BRIEF_OUT"

echo ""
echo "=== Validation Complete ==="
echo "Package output: $OUT_DIR"
echo "  - diagram.puml"
if [[ "$IS_TYPED" == "true" ]]; then
  echo "  - brief.normalized.yaml"
fi
if [[ "$RENDER_RESULT" == "ok" ]]; then
  echo "  - diagram.svg"
fi
echo "  - validation.json"
echo ""
echo "final_status=success"

exit 0
