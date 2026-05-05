#!/usr/bin/env node
'use strict';

/**
 * Slide IR 校验脚本
 * 用法: node validate_slide_ir.js <slide-ir.json>
 * 不依赖外部 npm 包，使用 Node.js 标准库。
 */

const fs = require('fs');
const path = require('path');

// --- 枚举定义（与 schema 保持一致） ---
const LAYOUT_PATTERNS = [
  'architecture-map',
  'layered-stack',
  'flow-diagram',
  'comparison-matrix',
  'roadmap-timeline',
  'metrics-dashboard',
  'decision-tree',
  'capability-map'
];

const REGION_ROLES = [
  'header', 'primary_visual', 'side_panel', 'evidence_zone',
  'takeaway_bar', 'footer', 'kpi_row', 'insight_panel'
];

const ELEMENT_KINDS = [
  'text', 'component_node', 'connector', 'step_marker',
  'table', 'matrix', 'kpi_card', 'note', 'legend', 'footer_note'
];

const SEMANTIC_ROLES = [
  'title', 'subtitle', 'takeaway', 'system_component',
  'process_step', 'data_flow', 'explanation', 'risk',
  'evidence', 'source_note'
];

const REQUIRED_TOP_FIELDS = [
  'version', 'slide_id', 'language', 'audience', 'canvas',
  'layout_pattern', 'source_summary', 'takeaway', 'regions',
  'elements', 'constraints', 'provenance'
];

// --- 主流程 ---
const filePath = process.argv[2];
if (!filePath) {
  console.error('用法: node validate_slide_ir.js <slide-ir.json>');
  process.exit(1);
}

const resolvedPath = path.resolve(filePath);
let raw;
try {
  raw = fs.readFileSync(resolvedPath, 'utf-8');
} catch (e) {
  console.error(`错误: 无法读取文件 ${resolvedPath}`);
  console.error(e.message);
  process.exit(1);
}

let doc;
try {
  doc = JSON.parse(raw);
} catch (e) {
  console.error(`错误: JSON 解析失败`);
  console.error(e.message);
  process.exit(1);
}

let errors = [];
let warnings = [];

// --- 1. 必填字段检查 ---
for (const field of REQUIRED_TOP_FIELDS) {
  if (!(field in doc)) {
    errors.push(`缺少必填顶层字段: ${field}`);
  }
}

if (errors.length > 0) {
  console.log(`\n校验结果: 失败`);
  errors.forEach(e => console.log(`  [错误] ${e}`));
  process.exit(1);
}

// --- 2. version 检查 ---
if (doc.version !== 'v1') {
  errors.push(`version 必须为 "v1"，当前为 "${doc.version}"`);
}

// --- 3. layout_pattern 枚举检查 ---
if (!LAYOUT_PATTERNS.includes(doc.layout_pattern)) {
  errors.push(`layout_pattern "${doc.layout_pattern}" 不在允许枚举中: ${LAYOUT_PATTERNS.join(', ')}`);
}

// --- 4. canvas 检查 ---
const canvas = doc.canvas;
if (typeof canvas.width_in !== 'number' || canvas.width_in <= 0) {
  errors.push('canvas.width_in 必须为正数');
}
if (typeof canvas.height_in !== 'number' || canvas.height_in <= 0) {
  errors.push('canvas.height_in 必须为正数');
}
if (!canvas.safe_margin_in) {
  errors.push('canvas.safe_margin_in 必须存在');
}

// --- 5. source_summary 检查 ---
if (!Array.isArray(doc.source_summary) || doc.source_summary.length === 0) {
  errors.push('source_summary 必须为非空数组');
} else {
  const sourceIds = new Set();
  for (const s of doc.source_summary) {
    if (!s.source_id) {
      errors.push(`source_summary 条目缺少 source_id`);
    } else {
      if (sourceIds.has(s.source_id)) {
        errors.push(`source_summary 中 source_id "${s.source_id}" 重复`);
      }
      sourceIds.add(s.source_id);
    }
    if (!s.content_type) {
      warnings.push(`source_summary 条目 "${s.source_id}" 缺少 content_type`);
    }
  }
  // 保存 sourceIds 供后续 provenance 检查使用
  doc._sourceIds = sourceIds;
}

// --- 6. takeaway 检查 ---
if (typeof doc.takeaway !== 'string' || doc.takeaway.trim() === '') {
  errors.push('takeaway 必须为非空字符串');
}

// --- 7. regions 检查 ---
if (!Array.isArray(doc.regions) || doc.regions.length === 0) {
  errors.push('regions 必须为非空数组');
} else {
  const regionIds = new Set();
  for (const r of doc.regions) {
    if (!r.id) {
      errors.push('region 条目缺少 id');
    } else {
      if (regionIds.has(r.id)) {
        errors.push(`region id "${r.id}" 重复`);
      }
      regionIds.add(r.id);
    }
    if (!r.role) {
      errors.push(`region "${r.id || '(unknown)'}" 缺少 role`);
    } else if (!REGION_ROLES.includes(r.role)) {
      warnings.push(`region "${r.id}" 的 role "${r.role}" 不在预定义枚举中`);
    }
    if (!r.bounds) {
      errors.push(`region "${r.id || '(unknown)'}" 缺少 bounds`);
    } else {
      const b = r.bounds;
      if (typeof b.x !== 'number') errors.push(`region "${r.id}" bounds.x 必须为数字`);
      if (typeof b.y !== 'number') errors.push(`region "${r.id}" bounds.y 必须为数字`);
      if (typeof b.w !== 'number' || b.w <= 0) errors.push(`region "${r.id}" bounds.w 必须为正数`);
      if (typeof b.h !== 'number' || b.h <= 0) errors.push(`region "${r.id}" bounds.h 必须为正数`);
      // 检查是否超出 canvas
      if (canvas.width_in && canvas.height_in) {
        if (b.x + b.w > canvas.width_in + 0.01) {
          errors.push(`region "${r.id}" 超出 canvas 宽度 (${b.x} + ${b.w} = ${b.x + b.w} > ${canvas.width_in})`);
        }
        if (b.y + b.h > canvas.height_in + 0.01) {
          errors.push(`region "${r.id}" 超出 canvas 高度 (${b.y} + ${b.h} = ${b.y + b.h} > ${canvas.height_in})`);
        }
      }
    }
    if (typeof r.priority !== 'number') {
      warnings.push(`region "${r.id || '(unknown)'}" 缺少 priority`);
    }
  }
  doc._regionIds = regionIds;
}

// --- 8. elements 检查 ---
if (!Array.isArray(doc.elements) || doc.elements.length === 0) {
  errors.push('elements 必须为非空数组');
} else {
  const elemIds = new Set();
  for (const e of doc.elements) {
    if (!e.id) {
      errors.push('element 条目缺少 id');
      continue;
    }
    if (elemIds.has(e.id)) {
      errors.push(`element id "${e.id}" 重复`);
    }
    elemIds.add(e.id);

    if (!e.kind) {
      errors.push(`element "${e.id}" 缺少 kind`);
    } else if (!ELEMENT_KINDS.includes(e.kind)) {
      warnings.push(`element "${e.id}" 的 kind "${e.kind}" 不在预定义枚举中`);
    }

    if (!e.semantic_role) {
      errors.push(`element "${e.id}" 缺少 semantic_role`);
    } else if (!SEMANTIC_ROLES.includes(e.semantic_role)) {
      warnings.push(`element "${e.id}" 的 semantic_role "${e.semantic_role}" 不在预定义枚举中`);
    }

    // region 引用检查
    if (!e.region_id) {
      errors.push(`element "${e.id}" 缺少 region_id`);
    } else if (doc._regionIds && !doc._regionIds.has(e.region_id)) {
      errors.push(`element "${e.id}" 引用了不存在的 region "${e.region_id}"`);
    }

    // content 检查
    if (!e.content && e.content !== 0) {
      errors.push(`element "${e.id}" 缺少 content`);
    }

    // source_refs 检查
    if (!e.source_refs || !Array.isArray(e.source_refs) || e.source_refs.length === 0) {
      warnings.push(`element "${e.id}" 缺少 source_refs 或为空数组`);
    } else if (doc._sourceIds) {
      for (const ref of e.source_refs) {
        if (!doc._sourceIds.has(ref)) {
          errors.push(`element "${e.id}" 的 source_ref "${ref}" 在 source_summary 中不存在`);
        }
      }
    }
  }
}

// --- 9. provenance 检查 ---
if (!Array.isArray(doc.provenance) || doc.provenance.length === 0) {
  errors.push('provenance 必须为非空数组');
} else {
  for (const p of doc.provenance) {
    if (!p.source_id) {
      errors.push('provenance 条目缺少 source_id');
    }
    if (!p.source_type) {
      errors.push(`provenance "${p.source_id || '(unknown)'}" 缺少 source_type`);
    } else if (!['user_input', 'derived', 'layout_only'].includes(p.source_type)) {
      errors.push(`provenance "${p.source_id || '(unknown)'}" 的 source_type "${p.source_type}" 无效`);
    }
    if (!p.quote_or_summary || typeof p.quote_or_summary !== 'string' || p.quote_or_summary.trim() === '') {
      errors.push(`provenance "${p.source_id || '(unknown)'}" 缺少 quote_or_summary`);
    }
    if (!p.used_by_elements || !Array.isArray(p.used_by_elements) || p.used_by_elements.length === 0) {
      errors.push(`provenance "${p.source_id || '(unknown)'}" 缺少 used_by_elements 或为空`);
    }
  }
}

// --- 10. constraints 基本检查 ---
if (doc.constraints && doc.constraints.min_font_pt) {
  const mfp = doc.constraints.min_font_pt;
  if (mfp.body && mfp.body < 1) {
    errors.push('constraints.min_font_pt.body 不得小于 1');
  }
}

// --- 11. backend_hints 可选检查 ---
if (doc.backend_hints && doc.backend_hints.preferred_backend) {
  const validBackends = ['pptxgenjs-native', 'template-placeholder', 'svg-to-drawingml', 'html-to-pptx'];
  if (!validBackends.includes(doc.backend_hints.preferred_backend)) {
    warnings.push(`backend_hints.preferred_backend "${doc.backend_hints.preferred_backend}" 不在允许枚举中`);
  }
}

// --- 输出结果 ---
console.log(`\n文件: ${resolvedPath}`);
console.log(`slide_id: ${doc.slide_id}`);
console.log(`layout_pattern: ${doc.layout_pattern}`);
console.log(`elements: ${doc.elements ? doc.elements.length : 0} 个`);
console.log(`regions: ${doc.regions ? doc.regions.length : 0} 个`);
console.log(`provenance: ${doc.provenance ? doc.provenance.length : 0} 条`);

if (errors.length === 0 && warnings.length === 0) {
  console.log(`\n校验结果: 通过`);
  console.log('  所有必填字段、枚举值、region 引用、source_refs/provenance 一致性检查通过。');
  process.exit(0);
}

if (errors.length > 0) {
  console.log(`\n校验结果: 失败 (${errors.length} 个错误, ${warnings.length} 个警告)`);
  errors.forEach(e => console.log(`  [错误] ${e}`));
  if (warnings.length > 0) {
    warnings.forEach(w => console.log(`  [警告] ${w}`));
  }
  process.exit(1);
}

// warnings only
console.log(`\n校验结果: 通过 (${warnings.length} 个警告)`);
warnings.forEach(w => console.log(`  [警告] ${w}`));
process.exit(0);
