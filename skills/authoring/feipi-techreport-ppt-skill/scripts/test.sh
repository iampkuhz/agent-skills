#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

required_files=(
  "$SKILL_DIR/SKILL.md"
  "$SKILL_DIR/agents/openai.yaml"
  "$SKILL_DIR/references/input-sufficiency.md"
  "$SKILL_DIR/references/page-contract.md"
  "$SKILL_DIR/references/layout-patterns.md"
  "$SKILL_DIR/references/visual-style.md"
  "$SKILL_DIR/references/visual-qa.md"
  "$SKILL_DIR/references/repair-policy.md"
  "$SKILL_DIR/references/executable-framework.md"
  "$SKILL_DIR/references/slide-ir.md"
  "$SKILL_DIR/references/backend-selection.md"
  "$SKILL_DIR/references/qa-gates.md"
  "$SKILL_DIR/references/auto-iteration.md"
)

for file in "${required_files[@]}"; do
  [[ -f "$file" ]]
done

! rg -Fq '{{' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/agents/openai.yaml" "$SKILL_DIR/scripts/test.sh"

rg -q 'Composition Blueprint|质量目标|环境与验证要求' "$SKILL_DIR/SKILL.md"
rg -q '大表|降维|版面预算|视觉预算' "$SKILL_DIR/references/layout-patterns.md" "$SKILL_DIR/references/visual-style.md" "$SKILL_DIR/references/page-contract.md"
rg -q '硬失败|重叠|截断|溢出|脚注' "$SKILL_DIR/references/visual-qa.md" "$SKILL_DIR/references/repair-policy.md"
rg -q 'pptxgenjs|playwright|sharp|html2pptx' "$SKILL_DIR/SKILL.md"

# Framework-level checks
rg -q 'Slide IR' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references/executable-framework.md" "$SKILL_DIR/references/slide-ir.md"
rg -q 'Static QA' "$SKILL_DIR/references/qa-gates.md" "$SKILL_DIR/references/executable-framework.md"
rg -q 'Render QA' "$SKILL_DIR/references/qa-gates.md" "$SKILL_DIR/references/executable-framework.md"
rg -q 'backend' "$SKILL_DIR/references/backend-selection.md" "$SKILL_DIR/references/executable-framework.md"
rg -q 'auto iteration|自动迭代' "$SKILL_DIR/references/auto-iteration.md" "$SKILL_DIR/SKILL.md"

NODE_BIN="$(command -v node 2>/dev/null || echo /opt/homebrew/bin/node)"

# Slide IR schema validation (valid fixtures must pass)
"$NODE_BIN" "$SKILL_DIR/scripts/validate_slide_ir.js" "$SKILL_DIR/fixtures/architecture-map.slide-ir.json"
"$NODE_BIN" "$SKILL_DIR/scripts/validate_slide_ir.js" "$SKILL_DIR/fixtures/comparison-matrix.slide-ir.json"
"$NODE_BIN" "$SKILL_DIR/scripts/validate_slide_ir.js" "$SKILL_DIR/fixtures/flow-diagram.slide-ir.json"

# Schema file check
[[ -f "$SKILL_DIR/schemas/slide-ir.schema.json" ]]

# Page Contract → Slide IR alignment check
rg -q 'Slide IR' "$SKILL_DIR/references/page-contract.md"

# Static QA layout inspection: good fixtures must pass
"$NODE_BIN" "$SKILL_DIR/scripts/inspect_slide_ir_layout.js" "$SKILL_DIR/fixtures/architecture-map.slide-ir.json" > /dev/null
"$NODE_BIN" "$SKILL_DIR/scripts/inspect_slide_ir_layout.js" "$SKILL_DIR/fixtures/comparison-matrix.slide-ir.json" > /dev/null
"$NODE_BIN" "$SKILL_DIR/scripts/inspect_slide_ir_layout.js" "$SKILL_DIR/fixtures/flow-diagram.slide-ir.json" > /dev/null

# Static QA: connector endpoint false positive test — should pass (acceptable_intentional, not hard_fail)
"$NODE_BIN" "$SKILL_DIR/scripts/inspect_slide_ir_layout.js" "$SKILL_DIR/fixtures/connector-endpoint-test.slide-ir.json" > /dev/null

# Static QA: text overflow test — should have warning (status: pass, but warning > 0)
TEXT_OVERFLOW_REPORT=$("$NODE_BIN" "$SKILL_DIR/scripts/inspect_slide_ir_layout.js" "$SKILL_DIR/fixtures/text-overflow-test.slide-ir.json" --json)
TEXT_OVERFLOW_WARNINGS=$(echo "$TEXT_OVERFLOW_REPORT" | "$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')); process.exit(d.summary.warning > 0 ? 0 : 1)")

# Static QA: bad fixtures must fail (expected behavior)
if "$NODE_BIN" "$SKILL_DIR/scripts/inspect_slide_ir_layout.js" "$SKILL_DIR/fixtures/bad-overlap.slide-ir.json" > /dev/null 2>&1; then
  echo "错误: bad-overlap 应该失败但通过了"
  exit 1
fi

if "$NODE_BIN" "$SKILL_DIR/scripts/inspect_slide_ir_layout.js" "$SKILL_DIR/fixtures/bad-font.slide-ir.json" > /dev/null 2>&1; then
  echo "错误: bad-font 应该失败但通过了"
  exit 1
fi

# --- PPTX dependency detection (consistent with doctor.js: skill-local node_modules first) ---
PPTXGENJS_AVAILABLE=$("$NODE_BIN" -e "
const fs = require('fs');
const path = require('path');
// Check skill-local node_modules first (same as doctor.js)
const localPath = path.join('$SKILL_DIR', 'node_modules', 'pptxgenjs', 'package.json');
if (fs.existsSync(localPath)) { console.log('yes'); process.exit(0); }
// Fall back to global/parent require
try { require('pptxgenjs'); console.log('yes'); } catch(e) { console.log('no'); }
" 2>/dev/null || echo "no")
TMPDIR_PPTX=$(mktemp -d)
trap "rm -rf $TMPDIR_PPTX" EXIT

if [[ "$PPTXGENJS_AVAILABLE" == "yes" ]]; then
  "$NODE_BIN" "$SKILL_DIR/scripts/build_pptx_from_ir.js" "$SKILL_DIR/fixtures/architecture-map.slide-ir.json" "$TMPDIR_PPTX/architecture-map.pptx" --allow-warnings > /dev/null
  [[ -s "$TMPDIR_PPTX/architecture-map.pptx" ]] || { echo "错误: architecture-map.pptx 未生成或为空"; exit 1; }

  "$NODE_BIN" "$SKILL_DIR/scripts/build_pptx_from_ir.js" "$SKILL_DIR/fixtures/flow-diagram.slide-ir.json" "$TMPDIR_PPTX/flow-diagram.pptx" --allow-warnings > /dev/null
  [[ -s "$TMPDIR_PPTX/flow-diagram.pptx" ]] || { echo "错误: flow-diagram.pptx 未生成或为空"; exit 1; }

  "$NODE_BIN" "$SKILL_DIR/scripts/build_pptx_from_ir.js" "$SKILL_DIR/fixtures/comparison-matrix.slide-ir.json" "$TMPDIR_PPTX/comparison-matrix.pptx" --allow-warnings > /dev/null
  [[ -s "$TMPDIR_PPTX/comparison-matrix.pptx" ]] || { echo "错误: comparison-matrix.pptx 未生成或为空"; exit 1; }

  # --- PPTX Postcheck on real artifact ---
  INSPECT_JSON=$("$NODE_BIN" "$SKILL_DIR/scripts/inspect_pptx_artifact.js" "$TMPDIR_PPTX/architecture-map.pptx" --json --expected-slides 1)
  INSPECT_SLIDE_COUNT=$(echo "$INSPECT_JSON" | "$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(String(d.slide_count))")
  [[ "$INSPECT_SLIDE_COUNT" == "1" ]] || { echo "错误: architecture-map.pptx 应有 1 张幻灯片，实际 $INSPECT_SLIDE_COUNT"; exit 1; }
  INSPECT_SUCCESS=$(echo "$INSPECT_JSON" | "$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(String(d.postcheck?.success ?? false))")
  [[ "$INSPECT_SUCCESS" == "true" ]] || { echo "错误: architecture-map.pptx postcheck 未通过"; exit 1; }

  # --- Render QA: PPTX → PNG → Visual QA Report ---
  TMPDIR_RENDER="$TMPDIR_PPTX/render"
  mkdir -p "$TMPDIR_RENDER"

  # 检测渲染引擎
  RENDERER=""
  if command -v soffice &>/dev/null; then
    RENDERER="soffice"
  elif command -v libreoffice &>/dev/null; then
    RENDERER="libreoffice"
  fi

  if [[ -n "$RENDERER" ]]; then
    # 渲染 architecture-map
    bash "$SKILL_DIR/scripts/render_pptx.sh" "$TMPDIR_PPTX/architecture-map.pptx" "$TMPDIR_RENDER" > /dev/null

    if [[ -f "$TMPDIR_RENDER/render-manifest.json" ]]; then
      RENDER_QA_REPORT=$("$NODE_BIN" "$SKILL_DIR/scripts/visual_qa_report.js" "$TMPDIR_RENDER/render-manifest.json" --json)
      RENDER_QA_STATUS=$(echo "$RENDER_QA_REPORT" | "$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')); process.stdout.write(d.status)")
      RENDER_QA_HARDFAIL=$(echo "$RENDER_QA_REPORT" | "$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')); process.stdout.write(d.summary.hard_fail)")

      if [[ "$RENDER_QA_STATUS" == "fail" ]] && [[ "$RENDER_QA_HARDFAIL" -gt 0 ]]; then
        echo "Render QA 发现硬失败:"
        echo "$RENDER_QA_REPORT" | "$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')); d.issues.filter(i=>i.severity==='hard_fail').forEach(i=>console.log('  [✗] '+i.message))"
        exit 1
      fi
    else
      echo "警告: render-manifest.json 未生成"
    fi
  else
    echo "跳过 Render QA 测试: LibreOffice/soffice 未安装"
    echo "  如需启用: brew install --cask libreoffice (macOS) 或 apt-get install libreoffice (Linux)"
    # 验证 skip manifest 也能被正确处理
    "$NODE_BIN" "$SKILL_DIR/scripts/render_pptx.js" --skip "$TMPDIR_PPTX/architecture-map.pptx" "$TMPDIR_RENDER" > /dev/null
    [[ -f "$TMPDIR_RENDER/render-manifest.json" ]] || { echo "错误: skip manifest 未生成"; exit 1; }
    SKIP_REPORT=$("$NODE_BIN" "$SKILL_DIR/scripts/visual_qa_report.js" "$TMPDIR_RENDER/render-manifest.json" --json)
    SKIP_STATUS=$(echo "$SKIP_REPORT" | "$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf-8')); process.stdout.write(d.status)")
    [[ "$SKIP_STATUS" == "skip" ]] || { echo "错误: skip manifest 状态应为 skip 但实际为 $SKIP_STATUS"; exit 1; }
  fi
else
  echo "跳过 PPTX 编译测试: pptxgenjs 未安装 (npm install pptxgenjs)"
fi

# --- Runtime capability checks ---
# doctor.js --json 必须输出可解析的 JSON
DOCTOR_JSON=$("$NODE_BIN" "$SKILL_DIR/scripts/doctor.js" --json 2>/dev/null)
"$NODE_BIN" -e "const d=JSON.parse(process.argv[1]); if(!d.pipeline_level) process.exit(1)" "$DOCTOR_JSON"

# runtime_capabilities.js 必须输出可解析的 JSON，且包含 pipeline_level
RUNTIME_JSON=$("$NODE_BIN" "$SKILL_DIR/scripts/runtime_capabilities.js" 2>/dev/null)
"$NODE_BIN" -e "const d=JSON.parse(process.argv[1]); if(!d.pipeline_level) process.exit(1)" "$RUNTIME_JSON"

# --- Benchmark smoke test (lightweight: validate + normalize + provenance only) ---
"$NODE_BIN" "$SKILL_DIR/scripts/validate_slide_ir.js" "$SKILL_DIR/fixtures/benchmarks/architecture-high-density/slide-ir.json" > /dev/null
"$NODE_BIN" "$SKILL_DIR/scripts/validate_slide_ir.js" "$SKILL_DIR/fixtures/benchmarks/flow-api-lifecycle/slide-ir.json" > /dev/null
"$NODE_BIN" "$SKILL_DIR/scripts/validate_slide_ir.js" "$SKILL_DIR/fixtures/benchmarks/comparison-competitive-matrix/slide-ir.json" > /dev/null

# --- Pipeline 测试 ---
TMPDIR_PIPELINE=$(mktemp -d)
trap "rm -rf $TMPDIR_PPTX $TMPDIR_PIPELINE" EXIT

# Pipeline dry-run: 合法 fixture 必须通过
"$NODE_BIN" "$SKILL_DIR/scripts/generate_pptx_pipeline.js" "$SKILL_DIR/fixtures/architecture-map.slide-ir.json" "$TMPDIR_PIPELINE/valid-dry-run" --dry-run --json > /dev/null
PIPELINE_VALID_STATUS=$("$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('$TMPDIR_PIPELINE/valid-dry-run/pipeline-report.json','utf-8')); process.stdout.write(d.final_status)")
[[ "$PIPELINE_VALID_STATUS" == "pass" ]] || { echo "错误: 合法 fixture dry-run 应该通过，实际状态为 $PIPELINE_VALID_STATUS"; exit 1; }
[[ -f "$TMPDIR_PIPELINE/valid-dry-run/qa-static.json" ]] || { echo "错误: qa-static.json 未生成"; exit 1; }
[[ -f "$TMPDIR_PIPELINE/valid-dry-run/pipeline-report.json" ]] || { echo "错误: pipeline-report.json 未生成"; exit 1; }

# Pipeline dry-run: bad fixture 应该产出 needs_user_decision 或 fail
"$NODE_BIN" "$SKILL_DIR/scripts/generate_pptx_pipeline.js" "$SKILL_DIR/fixtures/bad-overlap.slide-ir.json" "$TMPDIR_PIPELINE/bad-dry-run" --dry-run --json > /dev/null || true
PIPELINE_BAD_STATUS=$("$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('$TMPDIR_PIPELINE/bad-dry-run/pipeline-report.json','utf-8')); process.stdout.write(d.final_status)")
if [[ "$PIPELINE_BAD_STATUS" != "fail" ]] && [[ "$PIPELINE_BAD_STATUS" != "needs_user_decision" ]]; then
  echo "错误: bad fixture dry-run 应该产出 fail 或 needs_user_decision，实际为 $PIPELINE_BAD_STATUS"
  exit 1
fi
# 验证 repair plan 被正确生成
[[ -f "$TMPDIR_PIPELINE/bad-dry-run/repair-plan.json" ]] || { echo "错误: bad fixture 应该生成 repair-plan.json"; exit 1; }

# Pipeline 完整运行 (no-render): 如果 pptxgenjs 可用
if [[ "$PPTXGENJS_AVAILABLE" == "yes" ]]; then
  "$NODE_BIN" "$SKILL_DIR/scripts/generate_pptx_pipeline.js" "$SKILL_DIR/fixtures/architecture-map.slide-ir.json" "$TMPDIR_PIPELINE/valid-full" --no-render --json > /dev/null
  PIPELINE_FULL_STATUS=$("$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('$TMPDIR_PIPELINE/valid-full/pipeline-report.json','utf-8')); process.stdout.write(d.final_status)")
  [[ "$PIPELINE_FULL_STATUS" == "pass" ]] || { echo "错误: 合法 fixture 完整 pipeline 应该通过，实际状态为 $PIPELINE_FULL_STATUS"; exit 1; }
  [[ -f "$TMPDIR_PIPELINE/valid-full/output.pptx" ]] || { echo "错误: output.pptx 未生成"; exit 1; }

  # 如果 render 工具可用，测试带 render 的 pipeline
  if command -v soffice &>/dev/null || command -v libreoffice &>/dev/null; then
    "$NODE_BIN" "$SKILL_DIR/scripts/generate_pptx_pipeline.js" "$SKILL_DIR/fixtures/architecture-map.slide-ir.json" "$TMPDIR_PIPELINE/valid-render" --json > /dev/null
    PIPELINE_RENDER_STATUS=$("$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('$TMPDIR_PIPELINE/valid-render/pipeline-report.json','utf-8')); process.stdout.write(d.final_status)")
    [[ "$PIPELINE_RENDER_STATUS" == "pass" || "$PIPELINE_RENDER_STATUS" == "pass_with_skip" ]] || { echo "错误: 带 render 的 pipeline 状态异常: $PIPELINE_RENDER_STATUS"; exit 1; }
  else
    echo "跳过 Render Pipeline 测试: LibreOffice/soffice 未安装"
  fi
fi

bash -n "$SKILL_DIR/scripts/test.sh"

# --- Regression: pipeline level consistency between doctor.js and runtime_capabilities.js ---
DOCTOR_LEVEL=$("$NODE_BIN" "$SKILL_DIR/scripts/doctor.js" --json 2>/dev/null | "$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d.pipeline_level)")
RUNTIME_LEVEL=$("$NODE_BIN" "$SKILL_DIR/scripts/runtime_capabilities.js" 2>/dev/null | "$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d.pipeline_level)")
[[ "$DOCTOR_LEVEL" == "$RUNTIME_LEVEL" ]] || { echo "错误: doctor.js pipeline_level=$DOCTOR_LEVEL 与 runtime_capabilities.js pipeline_level=$RUNTIME_LEVEL 不一致"; exit 1; }

# --- Regression: needs_user_decision without real capacity evidence must fail ---
# Use score_quality_report.js directly with a synthetic result
TMP_SCORE=$(mktemp -d)
cat > "$TMP_SCORE/result.json" << 'REOF'
{
  "name": "test-clean-pass",
  "checks": {
    "static_qa": {
      "summary": { "hard_fail": 0, "warning": 1 },
      "issues": [{ "type": "layout_unsolved", "severity": "warning", "message": "test" }]
    },
    "provenance": { "status": "pass", "summary": { "hard_fail": 0 } },
    "capacity": []
  },
  "score": 95
}
REOF
cat > "$TMP_SCORE/expected-report.json" << 'EXPEOF'
{
  "benchmark_name": "test-clean-pass",
  "layout_pattern": "architecture-map",
  "expected_status": "needs_user_decision",
  "expected_qa_static": { "hard_fail_max": 0, "warning_max": 5 },
  "expected_score_min": 60
}
EXPEOF

# This should FAIL because there's no real capacity/split evidence
SCORE_RESULT=$("$NODE_BIN" "$SKILL_DIR/scripts/score_quality_report.js" "$TMP_SCORE" --json 2>/dev/null) || true
SCORE_ACTUAL=$(echo "$SCORE_RESULT" | "$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d.actual_status)" 2>/dev/null || echo "error")
[[ "$SCORE_ACTUAL" == "fail" ]] || { echo "错误: 无容量证据的 needs_user_decision 应该 fail，实际为 $SCORE_ACTUAL"; rm -rf "$TMP_SCORE"; exit 1; }
rm -rf "$TMP_SCORE"

# --- Regression: full benchmark missing expected-report.json must fail ---
# Use --single to run a benchmark from an arbitrary directory that has slide-ir.json but no expected-report.json
TMP_BENCH_NO_EXPECTED=$(mktemp -d)
mkdir -p "$TMP_BENCH_NO_EXPECTED/test-missing-expected"
cp "$SKILL_DIR/fixtures/benchmarks/architecture-high-density/slide-ir.json" "$TMP_BENCH_NO_EXPECTED/test-missing-expected/slide-ir.json"
# Intentionally do NOT create expected-report.json

# Run benchmark with --single pointing to the temp directory
# In --full mode, missing expected-report.json should cause a failure
BENCH_NO_EXPECTED_EXIT=0
"$NODE_BIN" "$SKILL_DIR/scripts/run_benchmarks.js" --dry-run --full --single "$TMP_BENCH_NO_EXPECTED/test-missing-expected" --json > "$TMP_BENCH_NO_EXPECTED/result.json" 2>/dev/null || BENCH_NO_EXPECTED_EXIT=$?
# In full mode, missing expected should cause exit non-zero
[[ $BENCH_NO_EXPECTED_EXIT -ne 0 ]] || { echo "错误: 缺少 expected-report.json 的 benchmark 在 full 模式下应该 exit 非 0"; rm -rf "$TMP_BENCH_NO_EXPECTED"; exit 1; }
# Verify the result status is "fail"
BENCH_NO_EXPECTED_STATUS=$("$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('$TMP_BENCH_NO_EXPECTED/result.json','utf8')); const r=d.results[0]; process.stdout.write(r?r.status:'missing')" 2>/dev/null || echo "error")
[[ "$BENCH_NO_EXPECTED_STATUS" == "fail" ]] || { echo "错误: 缺少 expected-report.json 应该导致 status=fail，实际为 $BENCH_NO_EXPECTED_STATUS"; rm -rf "$TMP_BENCH_NO_EXPECTED"; exit 1; }
rm -rf "$TMP_BENCH_NO_EXPECTED"

# --- Regression: overload-should-split must have real capacity evidence ---
# Check for actual capacity/split evidence, not just hard_fail >= 0 (which is always true)
OVERLOAD_RESULT=$("$NODE_BIN" "$SKILL_DIR/scripts/run_benchmarks.js" --dry-run --full --filter "overload" --json 2>/dev/null)
OVERLOAD_ACTUAL=$(echo "$OVERLOAD_RESULT" | "$NODE_BIN" -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); const r=d.results.find(x=>x.name==='overload-should-split'); process.stdout.write(r?r.actual_status:'missing')")
[[ "$OVERLOAD_ACTUAL" == "needs_user_decision" ]] || { echo "错误: overload-should-split 应该返回 needs_user_decision，实际为 $OVERLOAD_ACTUAL"; exit 1; }
# Verify real capacity evidence by reading the result file (stdout JSON doesn't include full checks)
OVERLOAD_RESULT_FILE=$(find "$SKILL_DIR/../../../tmp/ppt-skill-v2-run/benchmarks/overload-should-split" -name "result.json" 2>/dev/null | head -1)
if [[ -n "$OVERLOAD_RESULT_FILE" ]]; then
  OVERLOAD_CAPACITY=$("$NODE_BIN" -e "
const d=JSON.parse(require('fs').readFileSync('$OVERLOAD_RESULT_FILE','utf8'));
const capItems = d.checks?.capacity || [];
const hasCapacityDecision = capItems.some(i => i.severity === 'needs_user_decision');
process.stdout.write(hasCapacityDecision ? 'has-evidence' : 'no-evidence');
" 2>/dev/null || echo "no-evidence")
else
  # If result file not found, run benchmarks to generate it
  "$NODE_BIN" "$SKILL_DIR/scripts/run_benchmarks.js" --dry-run --full --filter "overload" --json > /dev/null 2>&1 || true
  OVERLOAD_RESULT_FILE=$(find "$SKILL_DIR/../../../tmp/ppt-skill-v2-run/benchmarks/overload-should-split" -name "result.json" 2>/dev/null | head -1)
  if [[ -n "$OVERLOAD_RESULT_FILE" ]]; then
    OVERLOAD_CAPACITY=$("$NODE_BIN" -e "
const d=JSON.parse(require('fs').readFileSync('$OVERLOAD_RESULT_FILE','utf8'));
const capItems = d.checks?.capacity || [];
const hasCapacityDecision = capItems.some(i => i.severity === 'needs_user_decision');
process.stdout.write(hasCapacityDecision ? 'has-evidence' : 'no-evidence');
" 2>/dev/null || echo "no-evidence")
  else
    OVERLOAD_CAPACITY="no-evidence"
  fi
fi
[[ "$OVERLOAD_CAPACITY" == "has-evidence" ]] || { echo "错误: overload-should-split 缺少真实容量证据（capacity needs_user_decision）"; exit 1; }

# --- Regression: inspect_pptx_artifact.js --help must exit 0 ---
if [[ "$PPTXGENJS_AVAILABLE" == "yes" ]]; then
  "$NODE_BIN" "$SKILL_DIR/scripts/inspect_pptx_artifact.js" --help > /dev/null 2>&1 || { echo "错误: inspect_pptx_artifact.js --help 应该 exit 0"; exit 1; }
  "$NODE_BIN" "$SKILL_DIR/scripts/inspect_pptx_artifact.js" -h > /dev/null 2>&1 || { echo "错误: inspect_pptx_artifact.js -h 应该 exit 0"; exit 1; }
  # No args should exit 1
  "$NODE_BIN" "$SKILL_DIR/scripts/inspect_pptx_artifact.js" > /dev/null 2>&1 && { echo "错误: inspect_pptx_artifact.js 无参数应该 exit 1"; exit 1; } || true
  # Non-existent file should exit 1
  "$NODE_BIN" "$SKILL_DIR/scripts/inspect_pptx_artifact.js" /tmp/nonexistent-file-$$$.pptx > /dev/null 2>&1 && { echo "错误: inspect_pptx_artifact.js 不存在的文件应该 exit 1"; exit 1; } || true
fi

# --- Regression: release_gate.sh --strict must exit non-zero when missing dependencies ---
if [[ "$DOCTOR_LEVEL" == "static-only" ]]; then
  bash "$SKILL_DIR/scripts/release_gate.sh" --strict > /dev/null 2>&1 || STRICT_EXIT_CODE=$?
  STRICT_EXIT_CODE=${STRICT_EXIT_CODE:-0}
  [[ $STRICT_EXIT_CODE -ne 0 ]] || { echo "错误: release_gate.sh --strict 在 static-only 环境下应该 exit 非 0，实际为 0"; exit 1; }
fi

echo "测试通过: feipi-techreport-ppt-skill"
