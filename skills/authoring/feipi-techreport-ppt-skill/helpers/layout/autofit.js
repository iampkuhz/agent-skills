/**
 * 保守 Autofit：尝试调整文本元素使其适配容器。
 * 不无限缩小字号，不低于下限。
 */
'use strict';

const { estimateTextFit } = require('./text-measure');

/**
 * 尝试自动缩小字号使文本适配容器。
 * 返回调整后的 fontSize 和 fitStatus。
 */
function tryAutofit(element, minFontPT = 7.5) {
  const layout = element.layout || {};
  if (!layout.w) return { fontSize: element.style?.font_size_pt || 10, fitStatus: 'unknown' };

  const text = typeof element.content === 'string'
    ? element.content
    : (element.content?.label || element.content?.text || '');

  if (!text) return { fontSize: element.style?.font_size_pt || 10, fitStatus: 'fit' };

  // Binary search for fitting font size
  let lo = minFontPT;
  let hi = element.style?.font_size_pt || 14;
  let best = hi;

  for (let i = 0; i < 10; i++) {
    const mid = (lo + hi) / 2;
    const fit = estimateTextFit(text, mid, layout.w, 1.2);
    if (fit.fitStatus === 'fit' && !fit.overflows_height) {
      best = mid;
      hi = mid;
    } else {
      lo = mid;
    }
  }

  if (best < element.style?.font_size_pt) {
    return {
      fontSize: Math.round(best * 10) / 10,
      fitStatus: 'shrink_needed',
      originalFontSize: element.style?.font_size_pt,
      suggestion: `字号从 ${element.style?.font_size_pt}pt 降至 ${Math.round(best * 10) / 10}pt`,
    };
  }

  return { fontSize: element.style?.font_size_pt || 10, fitStatus: 'fit' };
}

/**
 * 对单页 IR 中所有文本元素应用 autofit。
 * 返回调整列表和建议。
 */
function autofitPage(ir, minFontPT = 7.5) {
  const adjustments = [];
  const warnings = [];

  for (const el of ir.elements || []) {
    const hasText = typeof el.content === 'string' ||
      (el.content && (el.content.label || el.content.text));

    if (!hasText) continue;
    if (!el.layout || !el.layout.w) continue;

    const result = tryAutofit(el, minFontPT);
    if (result.fitStatus === 'shrink_needed') {
      adjustments.push({
        element_id: el.id,
        action: 'shrink_font',
        from: result.originalFontSize,
        to: result.fontSize,
      });
    }
    if (result.fitStatus === 'unknown' && !el.layout.h) {
      warnings.push({
        element_id: el.id,
        message: '元素缺少高度信息，无法进行 autofit',
      });
    }
  }

  return { adjustments, warnings, total_elements: ir.elements?.length || 0, adjusted: adjustments.length };
}

module.exports = { tryAutofit, autofitPage };
