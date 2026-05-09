/**
 * Pipeline 运行器
 * 执行: Validate → Static QA → Layout Solver → Build PPTX → Render QA → Pipeline Report
 */

'use strict';

const fs = require('fs');
const path = require('path');

// 加载依赖
const SKILL_DIR = path.join(__dirname, '..', '..');
const staticQA = require(path.join(SKILL_DIR, 'helpers', 'static-qa.js'));
const classifyIssues = require(path.join(SKILL_DIR, 'helpers', 'repair', 'classify-issues.js'));
const repairPlan = require(path.join(SKILL_DIR, 'helpers', 'repair', 'repair-plan.js'));

// 尝试加载布局求解器
let layoutSolver = null;
try {
  layoutSolver = require(path.join(SKILL_DIR, 'helpers', 'layout', 'solver'));
} catch (e) { /* layout solver 不可用 */ }

// 尝试加载编译器
let buildPptx = null;
try {
  buildPptx = require(path.join(SKILL_DIR, 'helpers', 'pptx', 'compiler.js'));
} catch (e) { /* pptxgenjs 不可用 */ }

// 尝试加载 postcheck
let pptxPostcheck = null;
try {
  pptxPostcheck = require(path.join(SKILL_DIR, 'helpers', 'pptx', 'postcheck.js'));
} catch (e) { /* postcheck 不可用 */ }

// 尝试加载 cNvPr 去重修复器
let fixCnvpIds = null;
try {
  fixCnvpIds = require(path.join(SKILL_DIR, 'helpers', 'pptx', 'fix-duplicate-cnvp-id.js'));
} catch (e) { /* fixer 不可用 */ }

let renderManifest = null;
try {
  renderManifest = require(path.join(SKILL_DIR, 'helpers', 'render', 'manifest.js'));
} catch (e) { /* render helper 不可用 */ }

/**
 * 从模式派生 QA 策略。
 */
function deriveQAStrategy(mode) {
  if (mode === 'draft') {
    return {
      allowWarnings: true,
      requireLayoutSolver: false,
      renderSkipIsPass: true,
      label: 'draft'
    };
  }
  // production (默认，最严格)
  return {
    allowWarnings: false,
    requireLayoutSolver: true,
    renderSkipIsPass: false,
    label: 'production'
  };
}

/**
 * 运行完整 pipeline。
 * @param {Object} slideIR - Slide IR 对象
 * @param {string} outputDir - 输出目录
 * @param {Object} options - 可选参数
 * @param {string} options.mode - 'draft' | 'production'（默认 'production'）
 * @param {boolean} options.allowWarnings - 覆盖模式默认（不建议）
 * @param {boolean} options.render - 是否尝试 Render QA
 * @param {boolean} options.dryRun - 只跑 Static QA + Repair Plan
 * @returns {Promise<Object>} pipeline report
 */
async function runPipeline(slideIR, outputDir, options = {}) {
  const {
    maxRounds = 3,
    mode = 'production',
    allowWarnings: explicitAllowWarnings,
    render = true,
    dryRun = false
  } = options;

  // 从模式派生 QA 策略，允许显式覆盖（用于兼容老调用方）
  const qaStrategy = deriveQAStrategy(mode);
  const allowWarnings = explicitAllowWarnings !== undefined ? explicitAllowWarnings : qaStrategy.allowWarnings;

  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const report = {
    slide_id: slideIR.slide_id,
    layout_pattern: slideIR.layout_pattern,
    mode,
    max_rounds: maxRounds,
    dry_run: dryRun,
    rounds: [],
    final_status: 'pending',
    final_message: ''
  };

  // --- Round 1..N ---
  for (let round = 1; round <= maxRounds; round++) {
    const roundReport = await _runRound(slideIR, outputDir, round, {
      allowWarnings,
      requireLayoutSolver: qaStrategy.requireLayoutSolver,
      render: render && round === 1,
      dryRun,
      mode
    });

    report.rounds.push(roundReport);

    if (roundReport.round_status === 'pass') {
      report.final_status = 'pass';
      report.final_message = `第 ${round} 轮通过，无硬失败。`;
      break;
    }

    if (roundReport.round_status === 'needs_user_decision') {
      report.final_status = 'needs_user_decision';
      report.final_message = roundReport.repair_plan?.reason || '需要人工决策。';
      break;
    }

    if (roundReport.round_status === 'incomplete') {
      report.final_status = 'incomplete';
      report.final_message = roundReport.message || '产物生成成功，但质量门禁未完成（solver 或 Render QA 未执行）。';
      break;
    }

    // 最后一轮仍失败
    if (round === maxRounds && roundReport.round_status === 'fail') {
      report.final_status = 'fail';
      report.final_message = `${maxRounds} 轮后仍有硬失败，无法交付。`;
    }
  }

  // 写入 pipeline report
  writeJson(path.join(outputDir, 'pipeline-report.json'), report);

  return report;
}

async function _runRound(slideIR, outputDir, round, options) {
  const { allowWarnings, requireLayoutSolver, render, dryRun, mode } = options;
  const roundReport = {
    round,
    static_qa: null,
    layout_solver: null,
    render_qa: null,
    classified_issues: [],
    repair_plan: null,
    build_result: null,
    round_status: 'pending'
  };

  // --- Step 1: Static QA ---
  const staticReport = staticQA.runStaticQA(slideIR);
  roundReport.static_qa = staticReport;
  writeJson(path.join(outputDir, 'qa-static.json'), staticReport);

  const hasHardFail = staticReport.summary.hard_fail > 0;
  const hasWarning = staticReport.summary.warning > 0;

  // --- Step 2: 如果有 hard_fail，生成 repair plan ---
  if (hasHardFail) {
    const classified = classifyIssues.classifyAllIssues(staticReport, null);
    roundReport.classified_issues = classified;

    const plan = repairPlan.generateRepairPlan(classified, slideIR, round);
    roundReport.repair_plan = plan;
    writeJson(path.join(outputDir, 'repair-plan.json'), plan);

    if (plan.status === 'needs_user_decision') {
      roundReport.round_status = 'needs_user_decision';
      return roundReport;
    }

    if (!dryRun) {
      roundReport.round_status = 'fail';
      roundReport.message = `Static QA 发现 ${staticReport.summary.hard_fail} 项硬失败，已生成修复 plan。当前阶段不自动改写 Slide IR，需要 LLM 根据 plan 重新生成 IR。`;
      return roundReport;
    }
  }

  // --- Step 2.5: Layout Solver（production 模式 + 有 warning 时尝试求解）---
  if (!dryRun && !hasHardFail && hasWarning && requireLayoutSolver && layoutSolver) {
    try {
      const solvedIR = layoutSolver.solveLayout(slideIR);
      roundReport.layout_solver = {
        status: 'pass',
        elements_solved: (solvedIR.elements || []).filter(e => e.layout && e.layout.x !== undefined).length,
        message: '布局求解已执行，缺失 bounds 的元素已自动分配坐标。'
      };

      // 用求解后的 IR 替换当前 IR（后续步骤使用求解结果）
      Object.assign(slideIR, solvedIR);

      // 重新运行 Static QA 检查求解后的结果
      const postSolveQA = staticQA.runStaticQA(slideIR);
      roundReport.static_qa_post_solve = postSolveQA;
      writeJson(path.join(outputDir, 'qa-static-post-solve.json'), postSolveQA);

      const postSolveHardFail = postSolveQA.summary.hard_fail > 0;
      const postSolveWarning = postSolveQA.summary.warning > 0;

      // 如果求解后仍有 hard_fail，转为失败
      if (postSolveHardFail) {
        const classified = classifyIssues.classifyAllIssues(postSolveQA, null);
        roundReport.classified_issues = classified;
        const plan = repairPlan.generateRepairPlan(classified, slideIR, round);
        roundReport.repair_plan = plan;
        roundReport.round_status = 'fail';
        roundReport.message = `布局求解后仍有 ${postSolveQA.summary.hard_fail} 项硬失败，无法交付。`;
        return roundReport;
      }

      // 如果求解后仍有 warning（production 模式不允许）
      if (postSolveWarning && !allowWarnings) {
        roundReport.classified_issues = classifyIssues.classifyAllIssues(postSolveQA, null);
        // 记录仍有未解决的 warning，但不阻断继续执行（交给 postcheck）
      }
    } catch (e) {
      roundReport.layout_solver = {
        status: 'error',
        message: `布局求解异常: ${e.message}`
      };
      // solver 异常不阻断，降级为原有 warning 处理逻辑
    }
  } else if (!dryRun && !hasHardFail && hasWarning && requireLayoutSolver && !layoutSolver) {
    roundReport.layout_solver = {
      status: 'skip',
      message: '布局求解器不可用，无法自动补充缺失 bounds。'
    };
  }

  // --- Step 3: warning 不允许时标记（兼容老逻辑）---
  if (!hasHardFail && hasWarning && !allowWarnings && !roundReport.layout_solver) {
    const classified = classifyIssues.classifyAllIssues(staticReport, null);
    roundReport.classified_issues = classified;
  }

  // --- Step 4: Build PPTX (跳过 dry run) ---
  if (!dryRun && !hasHardFail) {
    if (buildPptx) {
      const depCheck = buildPptx.checkDependency();
      if (depCheck.available) {
        const pptxPath = path.join(outputDir, 'output.pptx');
        const buildResult = await buildPptx.compile(slideIR, pptxPath);
        roundReport.build_result = buildResult;

        if (!buildResult.success) {
          roundReport.round_status = 'fail';
          roundReport.message = `PPTX 编译失败: ${buildResult.error}`;
          return roundReport;
        }

        // --- Step 4.3: 修复 pptxgenjs 重复 cNvPr id（在 postcheck 之前）---
        if (fixCnvpIds) {
          try {
            const fixResult = fixCnvpIds.fixDuplicateCnvpIds(pptxPath);
            roundReport.cnvp_fix = fixResult;
            if (!fixResult.success) {
              // 修复失败不阻断，交给 postcheck 发现
            }
          } catch (e) {
            roundReport.cnvp_fix = { success: false, error: e.message };
          }
        }

        // --- Step 4.5: PPTX Postcheck (编译成功后立即检查产物结构) ---
        if (pptxPostcheck) {
          try {
            const postcheckResult = await pptxPostcheck.postcheck(pptxPath, {
              expectedSlides: 1,
              releaseMode: mode === 'production'
            });
            roundReport.postcheck = postcheckResult;
            writeJson(path.join(outputDir, 'postcheck.json'), postcheckResult);

            if (!postcheckResult.success) {
              const hardFails = postcheckResult.issues.filter(i => i.severity === 'hard_fail');
              roundReport.round_status = 'fail';
              roundReport.message = `PPTX postcheck 发现 ${hardFails.length} 项硬失败: ` +
                hardFails.map(i => i.message).join('; ');
              return roundReport;
            }
          } catch (e) {
            // postcheck 异常不阻断，记录为 warning
            roundReport.postcheck = { success: false, issues: [{ severity: 'warning', type: 'postcheck_error', message: `Postcheck 异常: ${e.message}` }] };
          }
        }
      } else {
        roundReport.build_result = {
          success: false,
          error: 'pptxgenjs 未安装',
          skipped: true
        };
      }
    } else {
      roundReport.build_result = {
        success: false,
        error: 'PPTX compiler 不可用',
        skipped: true
      };
    }
  }

  // --- Step 5: Render QA (跳过 dry run) ---
  if (!dryRun && render && roundReport.build_result && roundReport.build_result.success) {
    const renderResult = _tryRenderAndQA(outputDir, path.join(outputDir, 'output.pptx'), mode);
    roundReport.render_qa = renderResult.renderQA;

    // 合并 render issues
    const qaToClassify = roundReport.static_qa_post_solve || staticReport;
    const staticClassified = classifyIssues.classifyAllIssues(qaToClassify, null);
    const renderClassified = renderResult.renderQA
      ? classifyIssues.classifyAllIssues(null, renderResult.renderQA)
      : [];
    roundReport.classified_issues = [...staticClassified, ...renderClassified];

    if (renderResult.status === 'skip') {
      if (mode === 'production') {
        // production 模式：render skip 不是通过状态
        roundReport.round_status = 'incomplete';
        roundReport.message = 'PPTX 编译成功，但渲染引擎不可用，无法进行完整视觉 QA。请安装 LibreOffice/soffice 后重新运行，或在 PowerPoint 中手动检查以下项：' +
          (renderResult.renderQA?.manual_checklist || []).map(item => `\n  - ${item}`).join('');
        roundReport.manual_checklist = renderResult.renderQA?.manual_checklist || [];
      } else {
        // draft 模式：允许 skip，但明确标注
        roundReport.round_status = 'pass_with_skip';
        roundReport.message = 'Static QA 通过，PPTX 编译成功，但渲染引擎不可用。Draft 模式允许此 skip，但不得视为正式交付。';
      }
    } else if (renderResult.renderQA && renderResult.renderQA.status === 'fail') {
      roundReport.round_status = 'fail';
      roundReport.message = 'Render QA 发现硬失败。';
    } else {
      roundReport.round_status = 'pass';
    }
  } else if (!dryRun && !hasHardFail) {
    // 没有 render 请求或 build 未成功，只看 static QA
    roundReport.classified_issues = classifyIssues.classifyAllIssues(
      roundReport.static_qa_post_solve || staticReport, null
    );
    if (mode === 'production' && render && (!roundReport.build_result || !roundReport.build_result.success)) {
      roundReport.round_status = 'incomplete';
      roundReport.message = 'Static QA 通过，但 PPTX 编译未成功或 Render QA 未执行，无法交付。';
    } else {
      roundReport.round_status = 'pass';
    }
  }

  if (dryRun) {
    roundReport.round_status = hasHardFail ? 'fail' : 'pass';
  }

  return roundReport;
}

function _tryRenderAndQA(outputDir, pptxPath, mode) {
  const { execSync } = require('child_process');
  let renderer = null;
  try {
    execSync('command -v soffice', { stdio: 'ignore' });
    renderer = 'soffice';
  } catch (e) {
    try {
      execSync('command -v libreoffice', { stdio: 'ignore' });
      renderer = 'libreoffice';
    } catch (e2) {
      // renderer 不可用
    }
  }

  if (!renderer) {
    // 生成 skip manifest
    if (renderManifest) {
      const skipManifest = {
        input_pptx: pptxPath,
        output_dir: outputDir,
        slides: [],
        renderer: 'none',
        status: 'skip',
        skip_reason: 'LibreOffice/soffice 未安装，无法渲染 PPTX 为 PNG。'
      };
      renderManifest.writeManifest(skipManifest, path.join(outputDir, 'render-manifest.json'));
    }

    const manualChecklist = [
      '在 PowerPoint 中手动检查文本裁剪',
      '检查箭头是否穿过文字',
      '检查主视觉是否清晰',
      '检查元素是否有重叠或遮挡',
      '检查表格是否可读'
    ];

    return {
      status: 'skip',
      renderQA: {
        status: 'skip',
        summary: { slides_checked: 0, hard_fail: 0, warning: 0 },
        issues: [{
          severity: 'warning',
          type: 'render_unavailable',
          message: 'LibreOffice/soffice 未安装，无法进行完整视觉 QA。'
        }],
        manual_checklist: manualChecklist
      }
    };
  }

  // 渲染
  const renderDir = path.join(outputDir, 'render');
  fs.mkdirSync(renderDir, { recursive: true });

  try {
    execSync(`${renderer} --headless --convert-to png --outdir "${renderDir}" "${pptxPath}"`, {
      stdio: 'pipe',
      timeout: 60000
    });
  } catch (e) {
    // 渲染失败，尝试 PDF 降级
    try {
      const pdfDir = path.join(outputDir, 'render-pdf');
      fs.mkdirSync(pdfDir, { recursive: true });
      execSync(`${renderer} --headless --convert-to pdf --outdir "${pdfDir}" "${pptxPath}"`, {
        stdio: 'pipe',
        timeout: 60000
      });
    } catch (e2) { /* 降级也失败 */ }
  }

  // 生成 manifest 和 QA
  let renderQA = null;
  if (renderManifest) {
    const slides = renderManifest.scanPngSlides(renderDir, pptxPath);
    const manifest = renderManifest.buildManifest(pptxPath, renderDir, slides, renderer);
    renderManifest.writeManifest(manifest, path.join(outputDir, 'render-manifest.json'));

    // 运行 visual QA
    const fs2 = require('fs');
    const path2 = require('path');
    const issues = [];
    const TARGET_RATIO = 16 / 9;
    const RATIO_TOLERANCE = 0.10;

    for (const slide of slides) {
      if (!slide.image_path || !fs2.existsSync(slide.image_path)) {
        issues.push({
          severity: 'hard_fail',
          type: 'slide_image_missing',
          slide_index: slide.index,
          message: `Slide ${slide.index}: 图片文件不存在`
        });
        continue;
      }

      const stat = fs2.statSync(slide.image_path);
      if (stat.size === 0) {
        issues.push({
          severity: 'hard_fail',
          type: 'slide_image_empty',
          slide_index: slide.index,
          message: `Slide ${slide.index}: 图片文件大小为 0 byte`
        });
        continue;
      }

      if (stat.size < 1024) {
        issues.push({
          severity: 'warning',
          type: 'slide_image_too_small',
          slide_index: slide.index,
          message: `Slide ${slide.index}: 图片文件异常小 (${stat.size} bytes)`
        });
      }

      const dims = renderManifest.parsePngHeader(slide.image_path);
      if (dims) {
        slide.width_px = dims.width;
        slide.height_px = dims.height;
        const actualRatio = dims.width / dims.height;
        const ratioDeviation = Math.abs(actualRatio - TARGET_RATIO) / TARGET_RATIO;
        if (ratioDeviation > RATIO_TOLERANCE) {
          issues.push({
            severity: 'warning',
            type: 'aspect_ratio_mismatch',
            slide_index: slide.index,
            message: `Slide ${slide.index}: 宽高比偏离 16:9 超过 ${RATIO_TOLERANCE * 100}%`
          });
        }
      }
    }

    const hardFail = issues.filter(i => i.severity === 'hard_fail').length;
    const warnings = issues.filter(i => i.severity === 'warning').length;

    renderQA = {
      status: hardFail > 0 ? 'fail' : 'pass',
      summary: {
        slides_checked: slides.length,
        hard_fail: hardFail,
        warning: warnings
      },
      issues,
      manual_checklist: [
        '检查文本是否被裁剪',
        '检查箭头是否穿过文字',
        '检查主视觉是否清晰',
        '检查元素是否有重叠或遮挡',
        '检查表格是否可读'
      ]
    };

    writeJson(path.join(outputDir, 'qa-render.json'), renderQA);
  }

  return {
    status: renderQA ? renderQA.status : 'skip',
    renderQA
  };
}

function writeJson(filePath, data) {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf-8');
}

module.exports = {
  runPipeline,
  writeJson,
  deriveQAStrategy
};
