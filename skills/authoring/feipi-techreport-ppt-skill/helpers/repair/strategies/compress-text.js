/**
 * Compress Text — 压缩过长标签为短文本。
 * 处理 Static QA 的 text_too_small / text_may_overflow。
 * 保留原意，记录 repair_provenance。
 */
'use strict';

const MIN_FONT_PT = 8.5;
const MAX_REDUCTION_RATIO = 0.5; // 最多减少 50% 的内容

/**
 * 保守压缩文本。不改变事实，只精简表达。
 * @param {string} originalText - 原始文本
 * @param {Object} element - 元素
 * @returns {{success: boolean, compressed_text: string|null, provenance: string|null}}
 */
function compressText(originalText, element) {
  if (!originalText || originalText.length < 10) {
    return { success: false, compressed_text: null, provenance: null, message: '文本过短，无法压缩' };
  }

  const originalLen = originalText.length;
  const maxKeep = Math.ceil(originalLen * (1 - MAX_REDUCTION_RATIO));
  let compressed = originalText;

  // Strategy 1: 去除首尾空白和冗余标点
  compressed = compressed.trim().replace(/\s+/g, ' ');

  // Strategy 2: 将长句改为短语——去除连接词、助词
  compressed = compressed
    .replace(/(包括|包含|例如|比如|也就是说|换言之|换句话说|即)/g, '：')
    .replace(/(非常|特别|十分|极其|高度|显著)/g, '')
    .replace(/(的|了|着)/g, '')
    .replace(/\s+/g, ' ');

  // Strategy 3: 如果还是太长，截取到 maxKeep
  if (compressed.length > maxKeep) {
    compressed = compressed.slice(0, maxKeep).replace(/[，。、；,.\s]+$/, '') + '…';
  }

  // 如果压缩后没有实质变化
  if (compressed === originalText.trim()) {
    return { success: false, compressed_text: null, provenance: null, message: '无法进一步压缩' };
  }

  return {
    success: true,
    compressed_text: compressed,
    provenance: `compressed from "${originalText.slice(0, 30)}..."`
  };
}

/**
 * 计算元素的最小可用字号。
 * @param {Object} element
 * @param {number} containerWidth - 容器宽度 (inch)
 * @returns {{estimated_font: number, min_required: number}}
 */
function estimateRequiredFont(element, containerWidth) {
  const content = element.content || {};
  const text = content.label || content.text || '';
  const charCount = text.length;

  // 粗略估计：CJK 字符约 fontSize 宽度，Latin 约 0.55 * fontSize
  const isCJK = /[一-鿿]/.test(text);
  const charWidth = isCJK ? 1 : 0.55;
  const neededWidth = charCount * charWidth;

  // 字号 = containerWidth / chars_per_inch
  const estimatedFont = Math.max(7, Math.floor(containerWidth / (charCount * 0.06)));
  return {
    estimated_font: estimatedFont,
    min_required: Math.ceil(neededWidth / containerWidth * 12)
  };
}

module.exports = { compressText, estimateRequiredFont, MIN_FONT_PT, MAX_REDUCTION_RATIO };
