/**
 * Semantic Token Resolver — 将 design kit 的 token path 解析为实际值。
 *
 * Token path 示例: "brand.primarySoft" → theme.colors.brand.primarySoft → "#DBEAFE"
 */

'use strict';

/**
 * 解析点分 token path 为 theme 中的实际值。
 * @param {string} tokenPath - e.g. "brand.primarySoft"
 * @param {Object} themeData - theme JSON (含 colors 字段)
 * @returns {string|null} hex 颜色或 null
 */
function resolveToken(tokenPath, themeData) {
  if (!tokenPath || typeof tokenPath !== 'string') return null;

  // 如果已经是 hex 颜色，直接返回
  if (/^#[0-9A-Fa-f]{6}$/.test(tokenPath)) return tokenPath;

  const parts = tokenPath.split('.');
  // 优先在 colors 下查找
  let value = themeData.colors;
  for (const part of parts) {
    if (value === null || value === undefined || typeof value !== 'object') return null;
    value = value[part];
  }

  return typeof value === 'string' ? value : null;
}

/**
 * 解析 variant 中所有 token path 为实际 hex 值。
 * @param {Object} componentSpec - 组件 spec JSON
 * @param {string} variantName - e.g. "primary", "done"
 * @param {Object} themeData - theme JSON
 * @returns {Object} { fill, stroke, titleColor, bodyColor }
 */
function resolveVariant(componentSpec, variantName, themeData) {
  const variants = componentSpec.variants || {};
  const variant = variants[variantName] || variants.neutral || {};

  const resolved = {};
  for (const [key, tokenPath] of Object.entries(variant)) {
    resolved[key] = resolveToken(tokenPath, themeData) || tokenPath;
  }

  // 确保关键字段存在
  return {
    fill: resolved.fill || null,
    stroke: resolved.stroke || null,
    titleColor: resolved.titleColor || '#0F172A',
    bodyColor: resolved.bodyColor || '#334155',
    ...resolved
  };
}

/**
 * 获取组件在特定 size preset 下的尺寸数值。
 * @param {Object} componentSpec - 组件 spec JSON
 * @param {string} sizePreset - e.g. "sm", "md", "lg"
 * @returns {Object|null} size 配置或 null
 */
function resolveSize(componentSpec, sizePreset) {
  const sizes = componentSpec.sizes || {};
  return sizes[sizePreset] || sizes.md || sizes.sm || null;
}

/**
 * 将 density 缩放因子应用到 size 配置。
 * @param {Object} sizeConfig - resolveSize 返回的 size 对象
 * @param {Object} densityPreset - density adjustments 对象
 * @returns {Object} 调整后的 size 配置
 */
function applyDensity(sizeConfig, densityPreset) {
  if (!densityPreset) return sizeConfig;

  const fontScale = densityPreset.fontScale || 1.0;
  const paddingScale = densityPreset.paddingScale || 1.0;
  const gapScale = densityPreset.gapScale || 1.0;
  const lineHeightScale = densityPreset.lineHeightScale || 1.0;

  // 对 font 相关字段应用 fontScale
  const FONT_KEYS = ['font', 'titleFont', 'valueFont', 'unitFont', 'captionFont',
    'bodyFont', 'headerFont', 'stageFont', 'headlineFont', 'itemFont', 'metricFont'];

  // 对 padding 相关字段应用 paddingScale
  const PADDING_KEYS = ['paddingX', 'paddingY', 'cellPaddingX', 'cellPaddingY'];

  // 对 gap 相关字段应用 gapScale
  const GAP_KEYS = ['gap', 'itemGap', 'childGap'];

  const result = { ...sizeConfig };

  for (const key of FONT_KEYS) {
    if (result[key] !== undefined && typeof result[key] === 'number') {
      const scaled = result[key] * fontScale;
      result[key] = Math.max(scaled, result[key] * 0.7); // 不低于原值的 70%
    }
  }

  for (const key of PADDING_KEYS) {
    if (result[key] !== undefined && typeof result[key] === 'number') {
      result[key] = result[key] * paddingScale;
    }
  }

  for (const key of GAP_KEYS) {
    if (result[key] !== undefined && typeof result[key] === 'number') {
      result[key] = result[key] * gapScale;
    }
  }

  // lineHeight 字段
  if (result.lineHeight !== undefined && typeof result.lineHeight === 'number') {
    result.lineHeight = result.lineHeight * lineHeightScale;
  }

  return result;
}

/**
 * 获取 density preset 配置。
 * @param {string} densityName - "compact", "regular", "spacious"
 * @param {Object} densityData - kit-loader 返回的 density 对象
 * @returns {Object|null}
 */
function getDensityPreset(densityName, densityData) {
  const adjustments = densityData.densityAdjustments || {};
  return adjustments[densityName] || adjustments.regular || null;
}

module.exports = {
  resolveToken,
  resolveVariant,
  resolveSize,
  applyDensity,
  getDensityPreset
};
