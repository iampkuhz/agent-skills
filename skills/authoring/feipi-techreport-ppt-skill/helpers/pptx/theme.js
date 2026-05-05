/**
 * PPTX 主题定义
 * 中文技术汇报默认主题：克制、清晰、结构化、高信息密度。
 */

'use strict';

// --- 颜色 token ---
const COLORS = {
  navy:    '#1B2A4A',
  blue:    '#1A73E8',
  green:   '#0D652D',
  orange:  '#E37400',
  red:     '#C5221F',
  gray:    '#5F6368',
  border:  '#DADCE0',
  pale:    '#F8F9FA',
  paleBlue:'#E8F0FE',
  paleOrange:'#FEF7E0',
  paleRed: '#FCE8E6',
  paleGreen:'#E6F4EA',
  white:   '#FFFFFF',
  black:   '#000000'
};

// --- 字号 token (pt) ---
const FONT_SIZES = {
  title:     28,
  subtitle:  14,
  regionTitle: 13,
  body:      10,
  label:     9,
  caption:   9,
  takeaway:  13,
  footer:    8.5,
  kpiValue:  14,
  kpiLabel:  10,
  tableHeader: 10,
  tableCell:  9,
  stepMarker: 9
};

// --- 字体 fallback 链 ---
const FONT_FACES = {
  default: ['Kaiti SC', 'PingFang SC', 'Microsoft YaHei', 'SimHei', 'sans-serif'],
  title:   ['Kaiti SC', 'PingFang SC', 'Microsoft YaHei', 'SimHei', 'sans-serif'],
  monospace: ['Menlo', 'Consolas', 'Monaco', 'monospace']
};

function resolveFontFace(family) {
  const faces = FONT_FACES[family] || FONT_FACES.default;
  return faces[0];
}

// --- Canvas 预设 ---
const CANVAS_PRESETS = {
  wide_16_9: { width_in: 13.33, height_in: 7.5 }
};

/**
 * 从 Slide IR canvas 获取尺寸。
 */
function getCanvasSize(canvas) {
  if (!canvas) return CANVAS_PRESETS.wide_16_9;
  const preset = CANVAS_PRESETS[canvas.preset];
  if (preset) return preset;
  if (canvas.width_in && canvas.height_in) {
    return { width_in: canvas.width_in, height_in: canvas.height_in };
  }
  return CANVAS_PRESETS.wide_16_9;
}

/**
 * 根据语义角色选择文本颜色。
 */
function textColorForRole(role, isHighlighted) {
  if (isHighlighted) return COLORS.blue;
  switch (role) {
    case 'risk':         return COLORS.red;
    case 'takeaway':     return COLORS.blue;
    case 'source_note':  return COLORS.gray;
    case 'title':        return COLORS.navy;
    default:             return COLORS.navy;
  }
}

/**
 * 根据语义角色选择背景色。
 */
function bgColorForRole(role) {
  switch (role) {
    case 'risk':         return COLORS.paleRed;
    case 'evidence':     return COLORS.paleBlue;
    case 'explanation':  return COLORS.pale;
    default:             return COLORS.paleBlue;
  }
}

module.exports = {
  COLORS,
  FONT_SIZES,
  FONT_FACES,
  resolveFontFace,
  CANVAS_PRESETS,
  getCanvasSize,
  textColorForRole,
  bgColorForRole
};
