#!/usr/bin/env node
/**
 * Style lock 校验：检查必填 token、颜色格式、字号下限、禁止项。
 *
 * 用法:
 *   node scripts/validate_style_lock.js <style-lock.json>
 */
'use strict';

const fs = require('fs');
const path = require('path');

function isValidHex(s) {
  return typeof s === 'string' && /^#[0-9A-Fa-f]{6}$/.test(s);
}

function validate(filePath) {
  const errors = [];
  const warnings = [];

  if (!fs.existsSync(filePath)) {
    process.stderr.write(`错误: 文件不存在: ${filePath}\n`);
    process.exit(1);
  }

  let lock;
  try {
    lock = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
  } catch (e) {
    process.stderr.write(`错误: JSON 解析失败: ${e.message}\n`);
    process.exit(1);
  }

  // Required fields
  const requiredTop = ['name', 'canvas', 'colors', 'min_font_sizes', 'prohibited'];
  for (const key of requiredTop) {
    if (!lock[key]) errors.push(`缺少必填字段: ${key}`);
  }

  // Canvas
  if (lock.canvas) {
    if (typeof lock.canvas.width_in !== 'number' || lock.canvas.width_in < 1)
      errors.push('canvas.width_in 必须是正数');
    if (typeof lock.canvas.height_in !== 'number' || lock.canvas.height_in < 1)
      errors.push('canvas.height_in 必须是正数');
  }

  // Colors — check hex format for top-level color values
  if (lock.colors) {
    const hexFields = ['primary', 'secondary', 'accent', 'text', 'text_secondary', 'background', 'surface', 'border'];
    for (const f of hexFields) {
      if (lock.colors[f] && !isValidHex(lock.colors[f])) {
        errors.push(`colors.${f} 不是合法 hex 颜色: ${lock.colors[f]}`);
      }
    }
    // Check semantic colors
    if (lock.colors.semantic && typeof lock.colors.semantic === 'object') {
      for (const [k, v] of Object.entries(lock.colors.semantic)) {
        if (!isValidHex(v)) errors.push(`colors.semantic.${k} 不是合法 hex 颜色: ${v}`);
      }
    }
    if (lock.colors.pale && typeof lock.colors.pale === 'object') {
      for (const [k, v] of Object.entries(lock.colors.pale)) {
        if (!isValidHex(v)) errors.push(`colors.pale.${k} 不是合法 hex 颜色: ${v}`);
      }
    }
  }

  // Min font sizes — must be positive numbers
  if (lock.min_font_sizes) {
    for (const [k, v] of Object.entries(lock.min_font_sizes)) {
      if (typeof v !== 'number' || v < 1) errors.push(`min_font_sizes.${k} 必须是正数: ${v}`);
    }
    // Hard rules: title >= 24, body >= 10, table_cell >= 8.5, footer >= 7.5
    if (lock.min_font_sizes.title !== undefined && lock.min_font_sizes.title < 24)
      warnings.push('min_font_sizes.title 低于推荐下限 24pt');
    if (lock.min_font_sizes.body !== undefined && lock.min_font_sizes.body < 10)
      errors.push('min_font_sizes.body 不能低于 10pt');
    if (lock.min_font_sizes.table_cell !== undefined && lock.min_font_sizes.table_cell < 8.5)
      errors.push('min_font_sizes.table_cell 不能低于 8.5pt');
    if (lock.min_font_sizes.footer !== undefined && lock.min_font_sizes.footer < 7.5)
      errors.push('min_font_sizes.footer 不能低于 7.5pt');
  }

  // Prohibited — must be non-empty array
  if (!Array.isArray(lock.prohibited) || lock.prohibited.length === 0)
    errors.push('prohibited 必须是非空数组');

  // Schema reference check
  if (lock['$schema']) {
    const schemaPath = path.resolve(path.dirname(filePath), lock['$schema']);
    if (!fs.existsSync(schemaPath)) {
      warnings.push(`引用的 schema 文件不存在: ${schemaPath}`);
    }
  }

  return { errors, warnings, name: lock.name || 'unknown' };
}

function main() {
  const args = process.argv.slice(2);
  if (args.length < 1) {
    process.stderr.write('用法: node scripts/validate_style_lock.js <style-lock.json>\n');
    process.exit(1);
  }

  const filePath = path.resolve(args[0]);
  const result = validate(filePath);

  if (result.warnings.length > 0) {
    result.warnings.forEach(w => process.stdout.write(`警告: ${w}\n`));
  }
  if (result.errors.length > 0) {
    result.errors.forEach(e => process.stderr.write(`错误: ${e}\n`));
    process.stderr.write(`\n校验失败: ${result.name}（${result.errors.length} 个错误）\n`);
    process.exit(1);
  }

  process.stdout.write(`校验通过: ${result.name}\n`);
}

main();
