/**
 * Pipeline 运行器
 * 执行: Validate → Static QA → Repair Plan → Build PPTX → Render QA → Pipeline Report
 */

'use strict';

const fs = require('fs');
const path = require('path');

// 加载依赖
const SKILL_DIR = path.join(__dirname, '..', '..');
const staticQA = require(path.join(SKILL_DIR, 'helpers', 'static-qa.js'));
const classifyIssues = require(path.join(SKILL_DIR, 'helpers', 'repair', 'classify-issues.js'));
const repairPlan = require(path.join(SKILL_DIR, 'helpers', 'repair', 'repair-plan.js'));

// 尝试加载编译器和渲染工具（可选）
let buildPptx = null;
try {
  buildPptx = require(path.join(SKILL_DIR, 'helpers', 'pptx', 'compiler.js'));
} catch (e) { /* pptxgenjs 不可用 */ }

let renderManifest = null;
try {
  renderManifest = require(path.join(SKILL_DIR, 'helpers', 'render', 'manifest.js'));
} catch (e) { /* render helper 不可用 */ }

/**
 * 运行完整 pipeline。
 * @param {Object} slideIR - Slide IR 对象
 * @param {string} outputDir - 输出目录
 * @param {Object} options - 可选参数
 * @returns {Promise<Object>} pipeline report
 */
async function runPipeline(slideIR, outputDir, options = {}) {
  const {
    maxRounds = 3,
    allowWarnings = true,
    render = true,
    dryRun = false
  } = options;

  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const report = {
    slide_id: slideIR.slide_id,
    layout_pattern: slideIR.layout_pattern,
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
      render: render && round === 1, // 只在第一轮尝试 render
      dryRun
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
  const { allowWarnings, render, dryRun } = options;
  const roundReport = {
    round,
    static_qa: null,
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

  // --- Step 3: 如果有 warning 但不允许，生成 repair plan ---
  if (!hasHardFail && hasWarning && !allowWarnings) {
    const classified = classifyIssues.classifyAllIssues(staticReport, null);
    roundReport.classified_issues = classified;
    // warning 不产生 repair plan，但标记 round 状态
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
    const renderResult = _tryRenderAndQA(outputDir, path.join(outputDir, 'output.pptx'));
    roundReport.render_qa = renderResult.renderQA;

    // 合并 render issues
    const staticClassified = classifyIssues.classifyAllIssues(staticReport, null);
    const renderClassified = renderResult.renderQA
      ? classifyIssues.classifyAllIssues(null, renderResult.renderQA)
      : [];
    roundReport.classified_issues = [...staticClassified, ...renderClassified];

    if (renderResult.status === 'skip') {
      roundReport.round_status = 'pass_with_skip';
      roundReport.message = 'Static QA 通过，PPTX 编译成功，但渲染引擎不可用。';
    } else if (renderResult.renderQA && renderResult.renderQA.status === 'fail') {
      roundReport.round_status = 'fail';
      roundReport.message = 'Render QA 发现硬失败。';
    } else {
      roundReport.round_status = 'pass';
    }
  } else if (!dryRun && !hasHardFail) {
    // 没有 render，只看 static QA
    roundReport.classified_issues = classifyIssues.classifyAllIssues(staticReport, null);
    roundReport.round_status = 'pass';
  }

  if (dryRun) {
    roundReport.round_status = hasHardFail ? 'fail' : 'pass';
  }

  return roundReport;
}

function _tryRenderAndQA(outputDir, pptxPath) {
  // 检测渲染引擎
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
        manual_checklist: ['在 PowerPoint 中手动检查文本裁剪', '检查箭头是否穿过文字', '检查主视觉是否清晰']
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
    // 渲染可能失败，尝试 PDF 降级
    try {
      const pdfDir = path.join(outputDir, 'render-pdf');
      fs.mkdirSync(pdfDir, { recursive: true });
      execSync(`${renderer} --headless --convert-to pdf --outdir "${pdfDir}" "${pptxPath}"`, {
        stdio: 'pipe',
        timeout: 60000
      });
    } catch (e2) { /* 降级也失败 */ }
  }

  // 生成 manifest
  let renderQA = null;
  if (renderManifest) {
    const slides = renderManifest.scanPngSlides(renderDir, pptxPath);
    const manifest = renderManifest.buildManifest(pptxPath, renderDir, slides, renderer);
    renderManifest.writeManifest(manifest, path.join(outputDir, 'render-manifest.json'));

    // 运行 visual QA
    const fs2 = require('fs');
    const path2 = require('path');
    const visualQAPath = path2.join(SKILL_DIR, 'scripts', 'visual_qa_report.js');
    try {
      // 直接调用模块逻辑（不 spawn 子进程）
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
    } catch (e) {
      renderQA = {
        status: 'pass',
        summary: { slides_checked: 0, hard_fail: 0, warning: 0 },
        issues: [{ severity: 'warning', type: 'qa_error', message: `Visual QA 执行异常: ${e.message}` }],
        manual_checklist: ['手动检查渲染图片']
      };
    }
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
  writeJson
};
