/**
 * Style lock 加载、校验和 drift 检查。
 * 所有 backend 和 QA 模块应通过本模块获取风格 token，不硬编码。
 */
'use strict';

const fs = require('fs');
const path = require('path');

const STYLE_LOCKS_DIR = path.join(__dirname, '..', '..', 'templates', 'style-locks');
const DEFAULT_STYLE_LOCK = 'cto-technical-report.style-lock.json';

function loadStyleLock(name) {
  const filePath = path.join(STYLE_LOCKS_DIR, name);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Style lock 未找到: ${name}（搜索路径: ${filePath}）`);
  }
  const raw = fs.readFileSync(filePath, 'utf-8');
  return JSON.parse(raw);
}

function loadDefaultStyleLock() {
  return loadStyleLock(DEFAULT_STYLE_LOCK);
}

/**
 * 从 Slide IR backend_hints 获取 style lock。
 * 若未指定，返回默认 style lock。
 */
function resolveStyleLock(slideIR) {
  const hints = slideIR.backend_hints || {};
  if (hints.style_lock && typeof hints.style_lock === 'string') {
    return loadStyleLock(hints.style_lock);
  }
  if (hints.style_lock && typeof hints.style_lock === 'object') {
    return hints.style_lock;
  }
  return loadDefaultStyleLock();
}

/**
 * 检查颜色值是否为合法 hex。
 */
function isValidHexColor(color) {
  if (typeof color !== 'string') return false;
  return /^#[0-9A-Fa-f]{6}$/.test(color);
}

/**
 * Style drift 检查：在生成后对实际元素进行检查。
 * 返回 { hard_fail: [...], warning: [...] }。
 */
function checkDrift(elements, styleLock) {
  const issues = { hard_fail: [], warning: [] };
  const { min_font_sizes, colors, prohibited, density_limits } = styleLock;

  if (!elements || !Array.isArray(elements)) return issues;

  // Check font size minimums
  for (const el of elements) {
    const fontSize = el.text_style?.font_size;
    const role = el.role || 'body';

    if (fontSize !== undefined && min_font_sizes) {
      const minKey = role === 'table_cell' ? 'table_cell' :
                     role === 'footer' || role === 'source_note' ? 'footer' :
                     role === 'label' || role === 'caption' ? 'label' : 'body';
      const minSize = min_font_sizes[minKey] || min_font_sizes.body;
      if (fontSize < minSize) {
        issues.hard_fail.push({
          type: 'font_size_below_minimum',
          element_id: el.id || 'unknown',
          message: `元素 "${el.id || 'unknown'}" 字号 ${fontSize}pt 低于最低要求 ${minSize}pt`,
        });
      }
    }

    // Check color tokens
    const bgColor = el.text_style?.bg_color || el.bg_color;
    if (bgColor && colors && isValidHexColor(bgColor)) {
      const allTokens = new Set();
      Object.values(colors).forEach(v => {
        if (typeof v === 'string' && v.startsWith('#')) allTokens.add(v.toUpperCase());
        if (typeof v === 'object') Object.values(v).forEach(v2 => {
          if (typeof v2 === 'string' && v2.startsWith('#')) allTokens.add(v2.toUpperCase());
        });
      });
      if (!allTokens.has(bgColor.toUpperCase())) {
        issues.warning.push({
          type: 'color_not_in_token',
          element_id: el.id || 'unknown',
          message: `元素 "${el.id || 'unknown'}" 使用颜色 ${bgColor} 不在 style lock token 中`,
        });
      }
    }
  }

  // Check primary color count
  const primaryColors = new Set();
  for (const el of elements) {
    const c = el.text_style?.color || el.text_color;
    if (c && isValidHexColor(c)) primaryColors.add(c.toUpperCase());
  }
  if (primaryColors.size > 3) {
    issues.warning.push({
      type: 'too_many_primary_colors',
      message: `同页主色过多（${primaryColors.size} 种），建议不超过 3 种`,
    });
  }

  // Check density limits
  if (density_limits) {
    const bulletCount = elements.filter(e => e.role === 'bullet').length;
    if (density_limits.max_bullets && bulletCount > density_limits.max_bullets) {
      issues.warning.push({
        type: 'density_bullet_exceeded',
        message: `bullet 数量 ${bulletCount} 超过上限 ${density_limits.max_bullets}`,
      });
    }
  }

  return issues;
}

module.exports = {
  loadStyleLock,
  loadDefaultStyleLock,
  resolveStyleLock,
  checkDrift,
  STYLE_LOCKS_DIR,
  DEFAULT_STYLE_LOCK,
};
