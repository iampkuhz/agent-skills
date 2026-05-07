#!/usr/bin/env node
'use strict';

/**
 * Slide IR → PPTX 编译入口
 * 用法: node build_pptx_from_ir.js <slide-ir.json> <output.pptx> [--allow-warnings]
 * 先做 schema 校验和静态 QA 检查，再通过后才编译 PPTX。
 */

const fs = require('fs');
const path = require('path');

// 解析参数
const args = process.argv.slice(2);
const allowWarnings = args.includes('--allow-warnings');
const fileArgs = args.filter(a => !a.startsWith('--'));

if (fileArgs.length < 2) {
  console.error('用法: node build_pptx_from_ir.js <slide-ir.json> <output.pptx> [--allow-warnings]');
  process.exit(1);
}

const irPath = path.resolve(fileArgs[0]);
const outputPath = path.resolve(fileArgs[1]);

// --- 读取 Slide IR ---
let raw;
try {
  raw = fs.readFileSync(irPath, 'utf-8');
} catch (e) {
  console.error(`错误: 无法读取文件 ${irPath}`);
  process.exit(1);
}

let slideIR;
try {
  slideIR = JSON.parse(raw);
} catch (e) {
  console.error('错误: JSON 解析失败');
  console.error(e.message);
  process.exit(1);
}

// --- 前置校验: Slide IR schema 等价检查 ---
console.log(`\n文件: ${irPath}`);
console.log(`slide_id: ${slideIR.slide_id}`);
console.log(`layout_pattern: ${slideIR.layout_pattern}`);

const REQUIRED_TOP_FIELDS = ['version', 'slide_id', 'language', 'audience', 'canvas', 'layout_pattern', 'source_summary', 'takeaway', 'regions', 'elements', 'constraints', 'provenance'];
for (const field of REQUIRED_TOP_FIELDS) {
  if (!(field in slideIR)) {
    console.error(`\n错误: Slide IR 缺少必填字段 "${field}"`);
    process.exit(1);
  }
}

// layout_pattern 枚举
const LAYOUT_PATTERNS = ['architecture-map', 'layered-stack', 'flow-diagram', 'comparison-matrix', 'roadmap-timeline', 'metrics-dashboard', 'decision-tree', 'capability-map'];
if (!LAYOUT_PATTERNS.includes(slideIR.layout_pattern)) {
  console.error(`\n错误: layout_pattern "${slideIR.layout_pattern}" 不在允许枚举中`);
  process.exit(1);
}

// source_refs 一致性检查
const sourceIds = new Set((slideIR.source_summary || []).map(s => s.source_id));
const regionIds = new Set((slideIR.regions || []).map(r => r.id));
for (const elem of slideIR.elements || []) {
  if (elem.region_id && !regionIds.has(elem.region_id)) {
    console.error(`\n错误: 元素 "${elem.id}" 引用了不存在的 region "${elem.region_id}"`);
    process.exit(1);
  }
  if (elem.source_refs) {
    for (const ref of elem.source_refs) {
      if (!sourceIds.has(ref)) {
        console.error(`\n错误: 元素 "${elem.id}" 的 source_ref "${ref}" 不存在`);
        process.exit(1);
      }
    }
  }
}

// --- 静态 QA 检查 ---
let staticQA;
try {
  const staticQAPath = path.join(__dirname, '..', 'helpers', 'static-qa.js');
  staticQA = require(staticQAPath);
} catch (e) {
  console.error('警告: 无法加载静态 QA 引擎，跳过 QA 检查');
  console.error(e.message);
}

if (staticQA) {
  const report = staticQA.runStaticQA(slideIR);

  if (report.summary.hard_fail > 0) {
    console.log('\n静态 QA 发现硬失败，拒绝生成 PPTX:');
    for (const issue of report.issues) {
      if (issue.severity === 'hard_fail') {
        console.log(`  [✗] ${issue.message}`);
      }
    }
    console.log('\n如需跳过硬失败检查，请先修复 Slide IR 中的布局问题。');
    process.exit(1);
  }

  if (report.summary.warning > 0 && !allowWarnings) {
    console.log('\n静态 QA 发现警告:');
    for (const issue of report.issues) {
      if (issue.severity === 'warning') {
        console.log(`  [!] ${issue.message}`);
      }
    }
    console.log('\n如需在存在警告的情况下继续生成，请添加 --allow-warnings 参数。');
    process.exit(1);
  }
}

// --- 编译 PPTX ---
let compiler;
try {
  const compilerPath = path.join(__dirname, '..', 'helpers', 'pptx', 'compiler.js');
  compiler = require(compilerPath);
} catch (e) {
  if (e.message.includes('pptxgenjs') || e.code === 'MODULE_NOT_FOUND') {
    console.error('\n错误: pptxgenjs 未安装');
    console.error('请运行以下命令安装:');
    console.error('  npm install pptxgenjs');
    console.error('\n当前环境下无法编译 PPTX。');
    process.exit(1);
  }
  console.error('错误: 无法加载编译器');
  console.error(e.message);
  process.exit(1);
}

const depCheck = compiler.checkDependency();
if (!depCheck.available) {
  console.error(`\n错误: ${depCheck.error}`);
  process.exit(1);
}

(async () => {
  console.log('\n开始编译 PPTX...');
  const result = await compiler.compile(slideIR, outputPath);

  if (result.success) {
    console.log(`\nPPTX 编译成功!`);
    console.log(`  输出文件: ${outputPath}`);
    console.log(`  slide_id: ${result.summary.slide_id}`);
    console.log(`  版式: ${result.summary.layout_pattern}`);
    console.log(`  渲染元素数: ${result.summary.elements_rendered}`);
    console.log(`  画布尺寸: ${result.summary.canvas.width_in}" × ${result.summary.canvas.height_in}"`);
    process.exit(0);
  } else {
    console.error(`\nPPTX 编译失败:`);
    console.error(`  ${result.error}`);
    process.exit(1);
  }
})();
