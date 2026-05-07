/**
 * PPTX Post-check
 * 生成 PPTX 后的产物验证：文件存在性、结构完整性、placeholder 残留、路径泄漏、母版残留。
 * 使用 JSZip 解析 PPTX（ZIP 格式），精确统计 slide 数量和提取可见文本。
 */
'use strict';

const fs = require('fs');
const path = require('path');
const JSZip = require('jszip');

// Placeholder 关键词
const PLACEHOLDER_PATTERNS = [
  /\bxxxx\b/i,
  /\blorem\b/i,
  /\bipsum\b/i,
  /\bplaceholder\b/i,
  /\bTBD\b/,
  /\bTODO\b/i,
  /\[insert\s/i,
  /\[待定\]/,
  /\[待补充\]/,
];

// 绝对路径泄漏模式
const PATH_LEAK_PATTERNS = [
  /\/Users\/\w+\/[^\s]{5,}/,
  /\/home\/\w+\/[^\s]{5,}/,
  /C:\\Users\\[^\s]{5,}/i,
];

// 默认母版/模板残留模式
const MASTER_RESIDUAL_PATTERNS = [
  'Click to edit Master text styles',
  'Second level',
  'Third level',
  'Fourth level',
  'Fifth level',
  '‹#›',
  '7/23/19',
];

/**
 * 检查文件存在性和基本属性。
 */
function checkFileExists(outputPath) {
  const issues = [];
  if (!fs.existsSync(outputPath)) {
    issues.push({ severity: 'hard_fail', type: 'file_missing', message: `PPTX 文件不存在: ${outputPath}` });
    return { success: false, issues, stats: null };
  }
  const stat = fs.statSync(outputPath);
  if (stat.size === 0) {
    issues.push({ severity: 'hard_fail', type: 'file_empty', message: 'PPTX 文件大小为 0 byte' });
    return { success: false, issues, stats: null };
  }
  return { success: true, issues, stats: { size_bytes: stat.size } };
}

/**
 * 扫描文本中是否残留 placeholder。
 */
function scanPlaceholder(texts) {
  const issues = [];
  for (const t of texts) {
    for (const pat of PLACEHOLDER_PATTERNS) {
      if (pat.test(t)) {
        issues.push({ severity: 'hard_fail', type: 'placeholder_residual', message: `检测到 placeholder 残留: "${t.slice(0, 60)}"` });
        break;
      }
    }
  }
  return issues;
}

/**
 * 扫描文本中是否包含绝对路径泄漏。
 */
function scanPathLeaks(texts) {
  const issues = [];
  for (const t of texts) {
    for (const pat of PATH_LEAK_PATTERNS) {
      const m = t.match(pat);
      if (m) {
        issues.push({ severity: 'hard_fail', type: 'path_leak', message: `检测到绝对路径泄漏: "${m[0].slice(0, 60)}"` });
        break;
      }
    }
  }
  return issues;
}

/**
 * 扫描默认母版/模板残留文本。
 * @param {string[]} texts - 提取的文本数组
 * @param {boolean} releaseMode - release 模式下视为 hard_fail，否则 warning
 * @returns {Array} issues
 */
function scanMasterResidual(texts, releaseMode) {
  const issues = [];
  const severity = releaseMode ? 'hard_fail' : 'warning';
  const seen = new Set();

  for (const t of texts) {
    for (const pattern of MASTER_RESIDUAL_PATTERNS) {
      if (t.includes(pattern) && !seen.has(pattern)) {
        seen.add(pattern);
        issues.push({
          severity,
          type: 'template_master_residual',
          message: `检测到默认母版残留: "${pattern}"`
        });
      }
    }
  }
  return issues;
}

/**
 * 验证 slide 数量与预期一致。
 */
function checkSlideCount(actualSlides, expectedSlides) {
  if (expectedSlides && actualSlides !== expectedSlides) {
    return [{ severity: 'warning', type: 'slide_count_mismatch', message: `预期 ${expectedSlides} 张幻灯片，实际 ${actualSlides} 张` }];
  }
  return [];
}

/**
 * 使用 JSZip 精确解析 PPTX 结构。
 * 统计 ppt/slides/slide*.xml 文件数量，从 slide XML 中提取可见文本。
 * 同时提取 slideMaster XML 中的文本用于母版残留检测。
 * @param {string} filePath - PPTX 文件路径
 * @returns {Promise<{slideCount: number, texts: string[], masterTexts: string[]}>}
 */
async function inspectPptxStructure(filePath) {
  const buffer = fs.readFileSync(filePath);

  // Validate ZIP header (PK)
  if (buffer[0] !== 0x50 || buffer[1] !== 0x4b) {
    throw new Error('Not a valid PPTX/ZIP file');
  }

  const zip = await JSZip.loadAsync(buffer);

  // Count slides: entries matching ppt/slides/slide<N>.xml
  const slideFiles = Object.keys(zip.files).filter(name =>
    /^ppt\/slides\/slide\d+\.xml$/i.test(name)
  ).sort((a, b) => {
    const numA = parseInt(a.match(/slide(\d+)/i)[1], 10);
    const numB = parseInt(b.match(/slide(\d+)/i)[1], 10);
    return numA - numB;
  });

  const slideCount = slideFiles.length;

  // Extract text from slide XMLs only (not from master/theme)
  const texts = [];
  for (const slideFile of slideFiles) {
    const content = await zip.files[slideFile].async('string');
    // <a:t>...</a:t> contains visible text in DrawingML
    const textRegex = /<a:t[^>]*>([^<]*)<\/a:t>/g;
    let match;
    while ((match = textRegex.exec(content)) !== null) {
      const text = match[1].trim();
      if (text) {
        texts.push(text);
      }
    }
  }

  // Also extract text from slideMaster XMLs for master residual detection
  const masterTexts = [];
  const masterFiles = Object.keys(zip.files).filter(name =>
    /^ppt\/slideMasters\/slideMaster\d+\.xml$/i.test(name)
  );
  for (const masterFile of masterFiles) {
    const content = await zip.files[masterFile].async('string');
    const textRegex = /<a:t[^>]*>([^<]*)<\/a:t>/g;
    let match;
    while ((match = textRegex.exec(content)) !== null) {
      const text = match[1].trim();
      if (text) {
        masterTexts.push(text);
      }
    }
  }

  // Also check slideLayout XMLs (placeholders may define default text here)
  const layoutFiles = Object.keys(zip.files).filter(name =>
    /^ppt\/slideLayouts\/slideLayout\d+\.xml$/i.test(name)
  );
  for (const layoutFile of layoutFiles) {
    const content = await zip.files[layoutFile].async('string');
    const textRegex = /<a:t[^>]*>([^<]*)<\/a:t>/g;
    let match;
    while ((match = textRegex.exec(content)) !== null) {
      const text = match[1].trim();
      if (text) {
        masterTexts.push(text);
      }
    }
  }

  return { slideCount, texts, masterTexts };
}

/**
 * 执行 post-check (async).
 * @param {string} outputPath - PPTX 文件路径
 * @param {Object} options - 可选参数
 * @param {number} options.expectedSlides - 预期幻灯片数量
 * @param {string[]} options.expectedTexts - 预期应包含的文本列表
 * @param {boolean} options.releaseMode - release 模式（母版残留视为 hard_fail）
 * @returns {Promise<{success: boolean, issues: Array, stats: Object|null}>}
 */
async function postcheck(outputPath, options = {}) {
  const { expectedSlides, expectedTexts, releaseMode = false } = options;
  const allIssues = [];

  // 1. File existence
  const fileResult = checkFileExists(outputPath);
  if (!fileResult.success) {
    return fileResult;
  }
  allIssues.push(...fileResult.issues);
  const stats = { ...fileResult.stats };

  // 2. PPTX structure inspection via JSZip
  let slideCount = 0;
  let extractedTexts = [];
  let masterTexts = [];
  try {
    const pptxStructure = await inspectPptxStructure(outputPath);
    slideCount = pptxStructure.slideCount;
    extractedTexts = pptxStructure.texts;
    masterTexts = pptxStructure.masterTexts || [];
    stats.slide_count = slideCount;
    stats.text_element_count = extractedTexts.length;
    stats.master_text_count = masterTexts.length;
  } catch (e) {
    allIssues.push({ severity: 'warning', type: 'structure_inspect_failed', message: `PPTX 结构解析失败: ${e.message}` });
    stats.structure_inspectable = false;
  }

  // 3. Slide count check
  allIssues.push(...checkSlideCount(slideCount, expectedSlides));

  // 4. Placeholder scan (slide text only)
  if (extractedTexts.length > 0) {
    allIssues.push(...scanPlaceholder(extractedTexts));
    allIssues.push(...scanPathLeaks(extractedTexts));
  }

  // 5. Master residual scan (both slide text and master text)
  // Master residual patterns in slide text = warning (or hard_fail in release mode)
  // Master residual patterns in master XML = always warning (these are template defaults)
  const slideMasterIssues = scanMasterResidual(extractedTexts, releaseMode);
  allIssues.push(...slideMasterIssues);

  // Also check master XML itself for default template patterns
  if (masterTexts.length > 0) {
    const masterResiduals = scanMasterResidual(masterTexts, releaseMode);
    // If master XML has default template text, that means new slides may inherit it
    if (masterResiduals.length > 0) {
      // In release mode this is a hard_fail, otherwise warning
      const masterSeverity = releaseMode ? 'hard_fail' : 'warning';
      allIssues.push({
        severity: masterSeverity,
        type: 'template_master_residual',
        message: `PPTX 使用默认母版模板，包含 ${masterResiduals.length} 处母版占位残留（详见 master XML）`
      });
    }
  }

  // 6. Expected text check
  if (expectedTexts) {
    for (const expected of expectedTexts) {
      const found = extractedTexts.some(t => t.includes(expected));
      if (!found) {
        allIssues.push({ severity: 'warning', type: 'expected_text_missing', message: `预期文本未找到: "${expected.slice(0, 40)}..."` });
      }
    }
  }

  const hasHardFail = allIssues.some(i => i.severity === 'hard_fail');
  return { success: !hasHardFail, issues: allIssues, stats };
}

module.exports = {
  postcheck,
  checkFileExists,
  scanPlaceholder,
  scanPathLeaks,
  scanMasterResidual,
  checkSlideCount,
  inspectPptxStructure,
  MASTER_RESIDUAL_PATTERNS,
  PLACEHOLDER_PATTERNS,
  PATH_LEAK_PATTERNS,
};
