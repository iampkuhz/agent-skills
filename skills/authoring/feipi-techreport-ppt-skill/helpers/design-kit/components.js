/**
 * Design Kit 组件渲染器 — badge-and-label, kpi-card, capability-group, native-table。
 * 每个函数接收 design-kit spec 格式的 component + region bounds + token 解析上下文。
 */

'use strict';

const { resolveToken, resolveVariant, resolveSize, applyDensity } = require('./token-resolver');

/**
 * 通用：计算 shape 的 rectRadius（PptxGenJS 使用 0-1 浮点）。
 */
function radiusToPptx(radiusPx) {
  // design kit 的 radius 以 inch 为单位，PptxGenJS rectRadius 也是 0-1 比例
  // 对于 ~0.1 inch 的 radius，映射为 0.08-0.1 的 rectRadius
  return Math.min(0.2, Math.max(0, radiusPx * 0.8));
}

// ===========================================================================
// Badge & Label
// ===========================================================================

function renderBadgeAndLabel(slide, comp, region, ctx) {
  const { size, variant, slots, density } = comp;
  const { theme, densityPreset } = ctx;

  const compSpec = ctx.kit.components['badge-and-label'];
  const baseSize = resolveSize(compSpec, size || 'sm');
  const sized = densityPreset ? applyDensity(baseSize, densityPreset) : baseSize;
  const v = resolveVariant(compSpec, variant || 'neutral', theme);

  const text = slots.text || slots.label || '';

  slide.addShape('roundRect', {
    x: region.x,
    y: region.y,
    w: sized.width || region.w,
    h: sized.height || region.h,
    fill: { color: v.fill || '#F1F5F9' },
    line: { color: v.stroke || '#CBD5E1', width: 0.5 },
    rectRadius: radiusToPptx(sized.radius || 0.08)
  });

  slide.addText(text, {
    x: region.x,
    y: region.y,
    w: sized.width || region.w,
    h: sized.height || region.h,
    fontSize: sized.font || 8,
    fontFace: ctx.fontFace || 'Kaiti SC',
    color: v.titleColor || '#0F172A',
    align: 'center',
    valign: 'middle',
    wrap: true,
    margin: 0
  });
}

// ===========================================================================
// KPI Card
// ===========================================================================

function renderKpiCard(slide, comp, region, ctx) {
  const { size, variant, slots, density } = comp;
  const { theme, densityPreset } = ctx;

  const compSpec = ctx.kit.components['kpi-card'];
  const baseSize = resolveSize(compSpec, size || 'md');
  const sized = densityPreset ? applyDensity(baseSize, densityPreset) : baseSize;
  const v = resolveVariant(compSpec, variant || 'neutral', theme);

  const title = slots.title || '';
  const value = String(slots.value || '');
  const unit = slots.unit || '';
  const caption = slots.caption || '';

  // 构建多段落文本
  const textParts = [];
  if (title) {
    textParts.push({
      text: title + '\n',
      options: {
        fontSize: sized.titleFont || 10,
        fontFace: ctx.fontFace || 'Kaiti SC',
        color: v.titleColor || '#0F172A',
        bold: false
      }
    });
  }

  const valueText = unit ? `${value} ${unit}` : value;
  textParts.push({
    text: valueText + (caption ? '\n' : ''),
    options: {
      fontSize: sized.valueFont || 25,
      fontFace: ctx.fontFace || 'Kaiti SC',
      color: v.bodyColor || '#334155',
      bold: true
    }
  });

  if (caption) {
    textParts.push({
      text: caption,
      options: {
        fontSize: sized.captionFont || 8,
        fontFace: ctx.fontFace || 'Kaiti SC',
        color: '#64748B',
        bold: false
      }
    });
  }

  const w = sized.width || region.w;
  const h = sized.height || region.h;

  slide.addText(textParts, {
    x: region.x,
    y: region.y,
    w,
    h,
    fill: { color: v.fill || '#FFFFFF' },
    line: { color: v.stroke || '#CBD5E1', width: 0.5 },
    rectRadius: radiusToPptx(sized.radius || 0.1),
    align: 'left',
    valign: 'top',
    wrap: true,
    margin: [sized.paddingY || 0.1, sized.paddingX || 0.14, sized.paddingY || 0.1, sized.paddingX || 0.14],
    paraSpaceAfter: 2
  });
}

// ===========================================================================
// Capability Group
// ===========================================================================

function renderCapabilityGroup(slide, comp, region, ctx) {
  const { size, variant, slots, density } = comp;
  const { theme, densityPreset } = ctx;

  const compSpec = ctx.kit.components['capability-group'];
  const baseSize = resolveSize(compSpec, size || 'md');
  const sized = densityPreset ? applyDensity(baseSize, densityPreset) : baseSize;
  const v = resolveVariant(compSpec, variant || 'neutral', theme);

  const title = slots.title || '';
  const items = slots.items || [];
  const footer = slots.footer || '';

  // 背景圆角矩形
  const w = sized.width || region.w;
  const h = sized.height || region.h;

  slide.addShape('roundRect', {
    x: region.x,
    y: region.y,
    w,
    h,
    fill: { color: v.fill || '#FFFFFF' },
    line: { color: v.stroke || '#CBD5E1', width: 0.5 },
    rectRadius: radiusToPptx(sized.radius || 0.11)
  });

  // 标题
  const padX = sized.paddingX || 0.14;
  const padY = sized.paddingY || 0.1;

  if (title) {
    slide.addText(title, {
      x: region.x + padX,
      y: region.y + padY,
      w: w - padX * 2,
      h: sized.titleFont ? sized.titleFont / 72 * 1.5 : 0.25,
      fontSize: sized.titleFont || 11,
      fontFace: ctx.fontFace || 'Kaiti SC',
      color: v.titleColor || '#0F172A',
      bold: true,
      align: 'left',
      valign: 'top',
      wrap: true,
      margin: 0
    });
  }

  // Items 列表（带 bullet）
  if (items.length > 0) {
    const titleH = title ? (sized.titleFont ? sized.titleFont / 72 * 1.8 : 0.3) : 0;
    const footerH = footer ? 0.2 : 0;
    const listY = region.y + padY + titleH;
    const listH = h - padY * 2 - titleH - footerH;
    const itemGap = sized.itemGap || 0.05;

    const itemTexts = items.map((item, i) => ({
      text: (i > 0 ? '\n' : '') + '  •  ' + item,
      options: {
        fontSize: sized.itemFont || 8.5,
        fontFace: ctx.fontFace || 'Kaiti SC',
        color: v.bodyColor || '#334155',
        bold: false
      }
    }));

    slide.addText(itemTexts, {
      x: region.x + padX,
      y: listY,
      w: w - padX * 2,
      h: listH,
      align: 'left',
      valign: 'top',
      wrap: true,
      margin: 0
    });
  }

  // Footer
  if (footer) {
    slide.addText(footer, {
      x: region.x + padX,
      y: region.y + h - padY - 0.2,
      w: w - padX * 2,
      h: 0.2,
      fontSize: (sized.itemFont || 8.5) - 1,
      fontFace: ctx.fontFace || 'Kaiti SC',
      color: '#64748B',
      align: 'left',
      valign: 'bottom',
      wrap: true,
      margin: 0
    });
  }
}

// ===========================================================================
// Native Table
// ===========================================================================

function renderNativeTable(slide, comp, region, ctx) {
  const { variant, slots, size, density } = comp;
  const { theme, densityPreset, tablePresets } = ctx;

  const compSpec = ctx.kit.components['native-table'];
  const baseSize = resolveSize(compSpec, size || 'md');
  const sized = densityPreset ? applyDensity(baseSize, densityPreset) : baseSize;
  const v = resolveVariant(compSpec, variant || 'tech', theme);

  const headers = slots.headers || [];
  const rows = slots.rows || [];
  const presetName = slots.preset || null;

  // 获取 table preset（列宽比例等）
  let tablePreset = null;
  if (presetName && tablePresets && tablePresets.presets && tablePresets.presets[presetName]) {
    tablePreset = tablePresets.presets[presetName];
  }

  const colCount = headers.length || (rows[0] ? rows[0].length : 0);
  const tableW = region.w;
  const totalRows = (headers.length > 0 ? 1 : 0) + rows.length;

  // 列宽
  let colWidths;
  if (tablePreset && tablePreset.columnWidthsRatio) {
    colWidths = tablePreset.columnWidthsRatio.map(ratio => ratio * tableW);
  } else {
    colWidths = Array(colCount).fill(tableW / colCount);
  }

  // 行高
  const headerHeight = sized.headerHeight || 0.36;
  const rowHeight = sized.rowHeight || 0.31;

  // 计算表格总高度
  let tableH = 0;
  if (headers.length > 0) {
    tableH += headerHeight;
  }
  tableH += rows.length * rowHeight;

  // 如果 region 高度更大，使用 region 高度
  tableH = Math.max(tableH, region.h);

  // 构建表格行数据
  const tableRows = [];

  // Header 行
  if (headers.length > 0) {
    const headerFontSize = sized.headerFont || 9.5;
    const headerFill = v.headerFill || v.fill || '#EEF6FF';
    const headerText = v.headerText || v.titleColor || '#0F172A';

    tableRows.push(headers.map(h => ({
      text: h,
      options: {
        fontSize: headerFontSize,
        fontFace: ctx.fontFace || 'Kaiti SC',
        color: headerText,
        bold: true,
        fill: { color: headerFill },
        align: 'center',
        valign: 'middle',
        margin: [sized.cellPaddingY || 0.035, sized.cellPaddingX || 0.05, sized.cellPaddingY || 0.035, sized.cellPaddingX || 0.05]
      }
    })));
  }

  // Body 行
  const bodyFontSize = sized.bodyFont || 8.2;
  const bodyFill = v.bodyFill || v.fill || '#FFFFFF';
  const bodyText = v.bodyText || v.bodyColor || '#334155';

  for (const row of rows) {
    tableRows.push(row.map((cell, idx) => ({
      text: typeof cell === 'string' ? cell : String(cell || ''),
      options: {
        fontSize: bodyFontSize,
        fontFace: ctx.fontFace || 'Kaiti SC',
        color: bodyText,
        bold: idx === 0,
        fill: { color: bodyFill },
        align: idx === 0 ? 'left' : 'center',
        valign: 'middle',
        margin: [sized.cellPaddingY || 0.035, sized.cellPaddingX || 0.05, sized.cellPaddingY || 0.035, sized.cellPaddingX || 0.05]
      }
    })));
  }

  // 计算实际行高数组
  const rowHeights = [];
  if (headers.length > 0) {
    rowHeights.push(headerHeight);
  }
  for (let i = 0; i < rows.length; i++) {
    rowHeights.push(rowHeight);
  }

  // 如果表格总高度 < region.h，均分剩余空间
  const computedH = rowHeights.reduce((a, b) => a + b, 0);
  if (computedH < tableH && rowHeights.length > 0) {
    const extra = (tableH - computedH) / rowHeights.length;
    for (let i = 0; i < rowHeights.length; i++) {
      rowHeights[i] += extra;
    }
  }

  const borderWidth = sized.borderWidth || 0.5;

  slide.addTable(tableRows, {
    x: region.x,
    y: region.y,
    w: tableW,
    h: tableH,
    colW: colWidths,
    rowH: rowHeights,
    border: { color: v.border || v.stroke || '#CBD5E1', width: borderWidth, type: 'solid' },
    margin: 0
  });
}

// ===========================================================================
// Timeline Card (用于 roadmap-5-stage builder，内联渲染)
// ===========================================================================

function renderTimelineCard(slide, comp, region, ctx) {
  const { size, variant, slots, density } = comp;
  const { theme, densityPreset } = ctx;

  const compSpec = ctx.kit.components['timeline-card'];
  const baseSize = resolveSize(compSpec, size || 'md');
  const sized = densityPreset ? applyDensity(baseSize, densityPreset) : baseSize;
  const v = resolveVariant(compSpec, variant || 'neutral', theme);

  const stage = slots.stage || '';
  const time = slots.time || '';
  const headline = slots.headline || '';
  const metric = slots.metric || '';
  const items = slots.items || [];

  const padX = sized.paddingX || 0.13;
  const padY = sized.paddingY || 0.1;

  // 背景圆角矩形
  slide.addShape('roundRect', {
    x: region.x,
    y: region.y,
    w: region.w,
    h: region.h,
    fill: { color: v.fill || '#FFFFFF' },
    line: { color: v.stroke || '#CBD5E1', width: 0.5 },
    rectRadius: radiusToPptx(sized.radius || 0.12)
  });

  // 阶段标签 + 时间（顶部一行）
  const headerText = [stage, time].filter(Boolean).join('  ');
  if (headerText) {
    slide.addText(headerText, {
      x: region.x + padX,
      y: region.y + padY,
      w: region.w - padX * 2,
      h: 0.22,
      fontSize: sized.stageFont || 10,
      fontFace: ctx.fontFace || 'Kaiti SC',
      color: v.titleColor || '#1E3A8A',
      bold: true,
      align: 'center',
      valign: 'top',
      wrap: true,
      margin: 0
    });
  }

  // Headline
  if (headline) {
    const headlineY = region.y + padY + 0.25;
    slide.addText(headline, {
      x: region.x + padX,
      y: headlineY,
      w: region.w - padX * 2,
      h: 0.3,
      fontSize: sized.headlineFont || 12,
      fontFace: ctx.fontFace || 'Kaiti SC',
      color: v.titleColor || '#0F172A',
      bold: true,
      align: 'center',
      valign: 'middle',
      wrap: true,
      margin: 0
    });
  }

  // Metric
  if (metric) {
    const metricY = region.y + padY + 0.55;
    slide.addText(metric, {
      x: region.x + padX,
      y: metricY,
      w: region.w - padX * 2,
      h: 0.3,
      fontSize: sized.metricFont || 16,
      fontFace: ctx.fontFace || 'Kaiti SC',
      color: v.bodyColor || '#2563EB',
      bold: true,
      align: 'center',
      valign: 'middle',
      wrap: true,
      margin: 0
    });
  }

  // Items 列表
  if (items.length > 0) {
    const itemsStartY = metric
      ? region.y + padY + 0.9
      : headline
        ? region.y + padY + 0.6
        : region.y + padY + 0.35;
    const itemsH = region.h - (itemsStartY - region.y) - padY;

    const itemTexts = items.map((item, i) => ({
      text: (i > 0 ? '\n' : '') + '  •  ' + item,
      options: {
        fontSize: sized.itemFont || 8.2,
        fontFace: ctx.fontFace || 'Kaiti SC',
        color: v.bodyColor || '#334155',
        bold: false
      }
    }));

    slide.addText(itemTexts, {
      x: region.x + padX,
      y: itemsStartY,
      w: region.w - padX * 2,
      h: itemsH,
      align: 'left',
      valign: 'top',
      wrap: true,
      margin: 0
    });
  }
}

// ===========================================================================
// 组件类型 → 渲染函数映射
// ===========================================================================

const COMPONENT_RENDERERS = {
  'badge-and-label': renderBadgeAndLabel,
  'kpi-card': renderKpiCard,
  'capability-group': renderCapabilityGroup,
  'native-table': renderNativeTable,
  'timeline-card': renderTimelineCard
};

function getRenderer(type) {
  return COMPONENT_RENDERERS[type] || null;
}

module.exports = {
  renderBadgeAndLabel,
  renderKpiCard,
  renderCapabilityGroup,
  renderNativeTable,
  renderTimelineCard,
  getRenderer,
  COMPONENT_RENDERERS
};
