/**
 * PPTX 基础图形原语（Primitives）
 * 封装小而稳定的 PptxGenJS 操作函数。
 * 每个 primitive 只消费 element 的 layout、style、content。
 */

'use strict';

const theme = require('./theme');

// --- PptxGenJS ShapeType 映射 ---
const SHAPE_MAP = {
  rect:          'RECTANGLE',
  rounded_rect:  'ROUNDED_RECTANGLE',
  oval:          'OVAL',
  diamond:       'DIAMOND',
  chevron:       'CHEVRON',
  cloud:         'CLOUD'
};

// --- PptxGenJS ConnectorType 映射 ---
const CONNECTOR_MAP = {
  arrow:       'STRAIGHT_CONNECTOR1',
  elbow:       'ELBOW_CONNECTOR1',
  curve:       'CURVE_CONNECTOR',
  straight:    'STRAIGHT_CONNECTOR1'
};

/**
 * 从 element 提取文本内容。
 */
function extractText(element) {
  if (typeof element.content === 'string') return element.content;
  if (element.content && element.content.label) return element.content.label;
  if (element.content && element.content.text) return element.content.text;
  return '';
}

/**
 * 合并默认样式和用户自定义样式。
 */
function mergeStyle(element, themeDefaults) {
  const s = element.style || {};
  return {
    fontFace: s.font_face || s.fontFace || theme.resolveFontFace('default'),
    fontSize: s.font_size_pt || s.fontSize || themeDefaults.fontSize || theme.FONT_SIZES.body,
    color: s.color || themeDefaults.color || theme.COLORS.navy,
    bold: s.bold !== undefined ? s.bold : themeDefaults.bold || false,
    align: s.align || themeDefaults.align || 'left',
    fillColor: s.background_color || s.fillColor || themeDefaults.fillColor || null,
    border: s.border || themeDefaults.border || null
  };
}

/**
 * 提取 layout 坐标和尺寸。
 */
function extractLayout(element) {
  const l = element.layout || {};
  return {
    x: l.x || 0,
    y: l.y || 0,
    w: l.w || 2,
    h: l.h || 0.5
  };
}

/**
 * 添加文本框。
 */
function addTextBox(slide, element, thm) {
  const layout = extractLayout(element);
  const style = mergeStyle(element, {
    fontSize: element.semantic_role === 'title' ? thm.FONT_SIZES.title :
              element.semantic_role === 'takeaway' ? thm.FONT_SIZES.takeaway :
              element.semantic_role === 'subtitle' ? thm.FONT_SIZES.subtitle :
              thm.FONT_SIZES.body,
    color: thm.textColorForRole(element.semantic_role)
  });

  slide.addText(extractText(element), {
    x: layout.x, y: layout.y, w: layout.w, h: layout.h,
    fontSize: style.fontSize,
    fontFace: style.fontFace,
    color: style.color,
    bold: style.bold,
    align: style.align,
    valign: 'top',
    wrap: true,
    autoFit: true,
    margin: [0.05, 0.1, 0.05, 0.1]
  });
}

/**
 * 添加组件节点（带背景色的圆角矩形 + 文本）。
 */
function addComponentNode(slide, element, thm) {
  const layout = extractLayout(element);
  const style = mergeStyle(element, {
    fontSize: thm.FONT_SIZES.body,
    fillColor: thm.COLORS.paleBlue
  });

  const content = element.content || {};
  const shapeType = SHAPE_MAP[content.shape_type] || 'ROUNDED_RECTANGLE';
  const labelText = content.label || extractText(element);

  slide.addShape(shapeType, {
    x: layout.x, y: layout.y, w: layout.w, h: layout.h,
    fill: { color: style.fillColor || thm.COLORS.paleBlue },
    line: { color: thm.COLORS.border, width: 0.5 },
    rectRadius: 0.1
  });

  if (labelText) {
    slide.addText(labelText, {
      x: layout.x, y: layout.y, w: layout.w, h: layout.h,
      fontSize: style.fontSize,
      fontFace: style.fontFace,
      color: style.color,
      bold: style.bold || false,
      align: 'center',
      valign: 'middle',
      wrap: true,
      autoFit: true,
      margin: [0.05, 0.08, 0.05, 0.08]
    });
  }
}

/**
 * 添加连接线。
 */
function addConnector(slide, element, thm) {
  const layout = extractLayout(element);
  const content = element.content || {};
  const connectorType = CONNECTOR_MAP[content.connector_type] || 'STRAIGHT_CONNECTOR1';

  // PptxGenJS 连接线需要起点和终点坐标
  // 这里使用 layout bounds 作为连接线路径的参考
  const shapeType = connectorType;

  slide.addShape(shapeType, {
    x: layout.x, y: layout.y, w: layout.w, h: layout.h,
    line: {
      color: thm.COLORS.blue,
      width: 1.5,
      endHeadType: content.connector_type === 'arrow' ? 'arrow' : 'none'
    }
  });
}

/**
 * 添加步骤标记。
 */
function addStepMarker(slide, element, thm) {
  const layout = extractLayout(element);
  const content = element.content || {};
  const labelText = content.label || '';

  slide.addText(labelText, {
    x: layout.x, y: layout.y, w: layout.w, h: layout.h,
    fontSize: thm.FONT_SIZES.stepMarker,
    fontFace: thm.resolveFontFace('default'),
    color: thm.COLORS.blue,
    bold: true,
    align: 'center',
    valign: 'middle',
    wrap: true
  });
}

/**
 * 添加 KPI 卡片（带背景色的文本框）。
 */
function addKpiCard(slide, element, thm) {
  const layout = extractLayout(element);
  const content = element.content || {};
  const label = content.label || '';
  const value = String(content.value !== undefined ? content.value : extractText(element));

  // 背景色
  const bgColor = element.style && element.style.background_color
    ? element.style.background_color
    : thm.COLORS.paleBlue;

  slide.addShape('RECTANGLE', {
    x: layout.x, y: layout.y, w: layout.w, h: layout.h,
    fill: { color: bgColor },
    line: { color: thm.COLORS.border, width: 0.5 },
    rectRadius: 0.08
  });

  // 标签
  slide.addText(label, {
    x: layout.x + 0.08, y: layout.y + 0.05, w: layout.w - 0.16, h: layout.h * 0.4,
    fontSize: thm.FONT_SIZES.kpiLabel,
    fontFace: thm.resolveFontFace('default'),
    color: thm.COLORS.gray,
    bold: false,
    align: 'left',
    valign: 'top',
    wrap: true,
    margin: 0
  });

  // 值
  slide.addText(value, {
    x: layout.x + 0.08, y: layout.y + layout.h * 0.4, w: layout.w - 0.16, h: layout.h * 0.55,
    fontSize: thm.FONT_SIZES.kpiValue,
    fontFace: thm.resolveFontFace('default'),
    color: thm.COLORS.navy,
    bold: true,
    align: 'left',
    valign: 'top',
    wrap: true,
    margin: 0
  });
}

/**
 * 添加矩阵/表格。
 */
function addMatrix(slide, element, thm) {
  const layout = extractLayout(element);
  const content = element.content || {};
  const headers = content.headers || [];
  const rows = content.rows || [];

  // 构建 PptxGenJS 表格数据
  const tableRows = [];
  if (headers.length > 0) {
    tableRows.push(headers.map(h => ({
      text: h,
      options: {
        fontSize: thm.FONT_SIZES.tableHeader,
        fontFace: thm.resolveFontFace('default'),
        color: thm.COLORS.navy,
        bold: true,
        fill: { color: thm.COLORS.pale },
        align: 'center',
        valign: 'middle',
        margin: [0.03, 0.06, 0.03, 0.06]
      }
    })));
  }
  for (const row of rows) {
    tableRows.push(row.map((cell, idx) => ({
      text: typeof cell === 'string' ? cell : String(cell),
      options: {
        fontSize: thm.FONT_SIZES.tableCell,
        fontFace: thm.resolveFontFace('default'),
        color: thm.COLORS.navy,
        bold: idx === 0,
        align: 'center',
        valign: 'middle',
        margin: [0.03, 0.06, 0.03, 0.06]
      }
    })));
  }

  if (tableRows.length === 0) return;

  slide.addTable(tableRows, {
    x: layout.x, y: layout.y, w: layout.w,
    border: { color: thm.COLORS.border, width: 0.5, type: 'solid' },
    colW: headers.length > 0 ? Array(headers.length).fill(layout.w / headers.length) : undefined,
    margin: 0,
    rowH: tableRows.length > 0 ? Math.min(0.4, layout.h / tableRows.length) : undefined
  });
}

/**
 * 添加注释/说明文本。
 */
function addNote(slide, element, thm) {
  const layout = extractLayout(element);
  const style = mergeStyle(element, {
    fontSize: thm.FONT_SIZES.body,
    color: thm.textColorForRole(element.semantic_role),
    fillColor: thm.bgColorForRole(element.semantic_role)
  });

  const text = extractText(element);
  if (!text) return;

  slide.addShape('RECTANGLE', {
    x: layout.x, y: layout.y, w: layout.w, h: layout.h,
    fill: { color: style.fillColor || thm.COLORS.white },
    line: { color: thm.COLORS.border, width: 0.5 },
    rectRadius: 0.05
  });

  slide.addText(text, {
    x: layout.x, y: layout.y, w: layout.w, h: layout.h,
    fontSize: style.fontSize,
    fontFace: style.fontFace,
    color: style.color,
    bold: element.semantic_role === 'risk',
    align: 'left',
    valign: 'top',
    wrap: true,
    autoFit: true,
    margin: [0.08, 0.1, 0.08, 0.1]
  });
}

/**
 * 添加脚注。
 */
function addFooterNote(slide, element, thm) {
  const layout = extractLayout(element);

  slide.addText(extractText(element), {
    x: layout.x, y: layout.y, w: layout.w, h: layout.h,
    fontSize: thm.FONT_SIZES.footer,
    fontFace: thm.resolveFontFace('default'),
    color: thm.COLORS.gray,
    align: 'left',
    valign: 'middle',
    wrap: true,
    margin: 0
  });
}

/**
 * 渲染区域背景框（可选，用于视觉分层）。
 */
function addRegionFrame(slide, region, thm, options) {
  const bounds = region.bounds;
  const opts = options || {};
  const fillColor = opts.fillColor || null;
  const lineColor = opts.lineColor || null;

  if (!fillColor && !lineColor) return;

  slide.addShape('RECTANGLE', {
    x: bounds.x, y: bounds.y, w: bounds.w, h: bounds.h,
    fill: fillColor ? { color: fillColor } : undefined,
    line: lineColor ? { color: lineColor, width: 0.5 } : undefined,
    rectRadius: 0.05
  });
}

module.exports = {
  addTextBox,
  addComponentNode,
  addConnector,
  addStepMarker,
  addKpiCard,
  addMatrix,
  addNote,
  addFooterNote,
  addRegionFrame,
  extractText,
  extractLayout,
  mergeStyle
};
