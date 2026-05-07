/**
 * PPTX 编译器
 * 根据 Slide IR 的 layout_pattern 选择 builder，生成 PPTX 文件。
 */

'use strict';

const path = require('path');
const fs = require('fs');
const theme = require('./theme');

// Builder 注册表
const BUILDERS = {
  'architecture-map':  require('./builders/architecture-map'),
  'flow-diagram':       require('./builders/flow-diagram'),
  'comparison-matrix':  require('./builders/comparison-matrix'),
  'layered-stack':      require('./builders/layered-stack'),
  'roadmap-timeline':   require('./builders/roadmap-timeline'),
  'metrics-dashboard':  require('./builders/metrics-dashboard'),
  'decision-tree':      require('./builders/decision-tree'),
  'capability-map':     require('./builders/capability-map')
};

/**
 * 检查 pptxgenjs 是否可用。
 */
function checkDependency() {
  try {
    require('pptxgenjs');
    return { available: true, error: null };
  } catch (e) {
    return {
      available: false,
      error: `pptxgenjs 未安装。请运行: npm install pptxgenjs\n错误详情: ${e.message}`
    };
  }
}

/**
 * 编译 Slide IR 为 PPTX。
 * @param {Object} slideIR - Slide IR 对象
 * @param {string} outputPath - 输出文件路径
 * @returns {Promise<{success: boolean, summary: Object|null, error: string|null}>}
 */
async function compile(slideIR, outputPath) {
  const depCheck = checkDependency();
  if (!depCheck.available) {
    return { success: false, summary: null, error: depCheck.error };
  }

  const PptxGenJS = require('pptxgenjs');

  const layoutPattern = slideIR.layout_pattern;
  const builder = BUILDERS[layoutPattern];

  if (!builder) {
    const supported = Object.keys(BUILDERS).join(', ');
    return {
      success: false,
      summary: null,
      error: `不支持的 layout_pattern "${layoutPattern}"。当前支持的版式: ${supported}`
    };
  }

  try {
    const pres = new PptxGenJS();
    const canvasSize = theme.getCanvasSize(slideIR.canvas);
    pres.defineLayout({ name: 'Custom', width: canvasSize.width_in, height: canvasSize.height_in });

    const summary = builder.build(pres, slideIR, theme);

    // 确保输出目录存在
    const outputDir = path.dirname(outputPath);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    // writeFile returns a Promise when using nodefs — must await
    await pres.writeFile({ outputType: 'nodefs', fileName: outputPath });

    // Verify output file exists and is non-empty
    if (!fs.existsSync(outputPath)) {
      return { success: false, summary: null, error: `PPTX 文件未生成: ${outputPath}` };
    }
    const stat = fs.statSync(outputPath);
    if (stat.size === 0) {
      return { success: false, summary: null, error: `PPTX 文件大小为 0: ${outputPath}` };
    }

    return {
      success: true,
      summary,
      error: null
    };
  } catch (e) {
    return {
      success: false,
      summary: null,
      error: `PPTX 编译失败: ${e.message}`
    };
  }
}

module.exports = {
  compile,
  checkDependency,
  BUILDERS,
  getSupportedPatterns: () => Object.keys(BUILDERS)
};
