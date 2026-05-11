/**
 * Compiler Adapter — 将 design-kit slide spec 格式规范化为 Slide IR 格式，
 * 使 pipeline 能正确处理两种格式。
 */

'use strict';

const { loadDesignKit } = require('../kit-loader');

/**
 * 检测是否为 design-kit slide spec 格式。
 */
function isDesignKitSpec(obj) {
  return obj.slideType && Array.isArray(obj.components) && !obj.layout_pattern;
}

/**
 * 将 design-kit slide spec 规范化为最小 Slide IR 格式。
 * @param {Object} spec - design-kit spec
 * @returns {Object} Slide IR 对象
 */
function normalizeToSlideIR(spec) {
  const kit = loadDesignKit();
  const layout = kit.layouts[spec.slideType];
  const pageWidth = layout ? layout.page.width : 13.333;
  const pageHeight = layout ? layout.page.height : 7.5;
  const safeMargin = kit.manifest.page.safeMarginIn || 0.28;

  // 将 components 转换为 elements（带 region_id 和 layout）
  const elements = [];
  const regions = [];

  // 构建 region 列表（来自 layout spec）
  if (layout) {
    for (const [id, region] of Object.entries(layout.regions)) {
      regions.push({
        id,
        ...region
      });
    }
  }

  // 将每个 component 转换为 element
  for (const comp of spec.components) {
    const regionName = comp.region;
    const region = layout ? layout.regions[regionName] : null;

    elements.push({
      id: comp.type + '_' + comp.region,
      kind: comp.type,
      region_id: regionName,
      semantic_role: region ? region.role : 'body',
      layout: region ? {
        x: region.x,
        y: region.y,
        w: region.w,
        h: region.h
      } : {},
      content: comp.slots || {},
      _designKitComponent: comp // 保留原始 component 供 builder 使用
    });
  }

  // 添加 title element
  if (spec.title && layout && layout.regions.title) {
    const titleRegion = layout.regions.title;
    // 确保 title y >= safe_margin_in 以避免 out_of_bounds
    const adjustedY = Math.max(titleRegion.y, safeMargin);
    elements.push({
      id: 'title',
      kind: 'text',
      region_id: 'title',
      semantic_role: 'title',
      layout: {
        x: titleRegion.x,
        y: adjustedY,
        w: titleRegion.w,
        h: titleRegion.h
      },
      content: spec.title
    });
  }

  return {
    slide_id: spec.slide_id || `design-kit-${spec.slideType}`,
    layout_pattern: spec.slideType,
    canvas: {
      width_in: pageWidth,
      height_in: pageHeight,
      safe_margin_in: safeMargin,
      preset: 'wide_16_9'
    },
    regions,
    elements,
    // 传递 design-kit 特有字段
    _designKitSpec: spec,
    components: spec.components,
    density: spec.density,
    theme: spec.theme
  };
}

module.exports = {
  isDesignKitSpec,
  normalizeToSlideIR
};
