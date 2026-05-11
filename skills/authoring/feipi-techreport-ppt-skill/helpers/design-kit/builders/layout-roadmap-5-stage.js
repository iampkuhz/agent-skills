/**
 * Roadmap 5-Stage Builder
 * 使用 design-kit 组件系统渲染五阶段路线图。
 */

'use strict';

const { loadDesignKit } = require('../kit-loader');
const { renderNativeTable, renderTimelineCard } = require('../components');
const { getDensityPreset, resolveToken, resolveVariant, resolveSize, applyDensity } = require('../token-resolver');
const { validateSlide, createRenderTracker } = require('../validation');

/**
 * 渲染 title 文本。
 */
function renderTitle(slide, text, region, ctx) {
  const fontSize = ctx.typography ? ctx.typography.levels.pageTitle.fontSize : 28;
  slide.addText(text, {
    x: region.x,
    y: region.y,
    w: region.w,
    h: region.h,
    fontSize,
    fontFace: ctx.fontFace || 'Kaiti SC',
    color: resolveToken('text.primary', ctx.theme) || '#0F172A',
    bold: true,
    align: 'left',
    valign: 'top',
    wrap: true,
    margin: 0
  });
}

/**
 * 渲染 summary band（KPI + badge 区域）。
 */
function renderSummaryBand(slide, comp, region, ctx) {
  // 如果 summary 区域有组件，渲染它
  const renderer = comp.type === 'kpi-card' ? require('../design-kit/components').renderKpiCard :
                   comp.type === 'badge-and-label' ? require('../design-kit/components').renderBadgeAndLabel :
                   null;
  if (renderer) {
    renderer(slide, comp, region, ctx);
  }
}

/**
 * 在两个阶段卡片之间画箭头。
 */
function drawArrowBetweenStages(slide, fromRegion, toRegion, thm) {
  const arrowY = fromRegion.y + fromRegion.h / 2;
  const startX = fromRegion.x + fromRegion.w;
  const endX = toRegion.x;

  if (endX <= startX) return;

  try {
    slide.addShape('line', {
      x: startX,
      y: arrowY,
      w: endX - startX,
      h: 0,
      line: {
        color: resolveToken('border.subtle', ctx.theme) || '#CBD5E1',
        width: 1.5,
        endHeadType: 'arrow'
      }
    });
  } catch {
    // Graceful fallback
  }
}

/**
 * 渲染 footnote。
 */
function renderFootnote(slide, text, region, ctx) {
  slide.addText(text, {
    x: region.x,
    y: region.y,
    w: region.w,
    h: region.h,
    fontSize: ctx.typography ? ctx.typography.levels.footnote.fontSize : 8,
    fontFace: ctx.fontFace || 'Kaiti SC',
    color: resolveToken('text.muted', ctx.theme) || '#64748B',
    align: 'left',
    valign: 'top',
    wrap: true,
    margin: 0
  });
}

// 需要访问 ctx，在 drawArrowBetweenStages 中
let ctx = null;

function drawArrowBetweenStagesFixed(slide, fromRegion, toRegion, theme) {
  const arrowY = fromRegion.y + fromRegion.h / 2;
  const startX = fromRegion.x + fromRegion.w;
  const endX = toRegion.x;

  if (endX <= startX) return;

  try {
    slide.addShape('line', {
      x: startX,
      y: arrowY,
      w: endX - startX,
      h: 0,
      line: {
        color: resolveToken('border.subtle', theme) || '#CBD5E1',
        width: 1.5,
        endHeadType: 'arrow'
      }
    });
  } catch {
    // Graceful fallback
  }
}

function build(pres, slideIR, thm) {
  const kit = loadDesignKit();
  const layout = kit.layouts['roadmap-5-stage'];
  const theme = kit.theme;
  const densityName = slideIR.density || kit.manifest.defaultDensity;
  const densityPreset = getDensityPreset(densityName, kit.density);

  const canvasSize = thm.getCanvasSize(slideIR.canvas);
  const slide = pres.addSlide();
  const components = slideIR.components || [];

  slide.background = { color: resolveToken('surface.page', theme) || '#F8FAFC' };

  // 构建渲染上下文
  const renderCtx = {
    kit,
    theme,
    densityPreset,
    fontFace: kit.typography.fontFamily || 'Kaiti SC',
    typography: kit.typography,
    tablePresets: kit.tables
  };
  ctx = renderCtx;

  const tracker = createRenderTracker();

  // 1. 渲染 title
  if (slideIR.title) {
    renderTitle(slide, slideIR.title, layout.regions.title, renderCtx);
  }

  // 2. 渲染 summary band（如果有对应组件）
  const summaryComponents = components.filter(c => c.region === 'summary');
  for (const comp of summaryComponents) {
    const region = layout.regions.summary;
    renderSummaryBand(slide, comp, region, renderCtx);
  }

  // 3. 渲染 5 个 stage 卡片
  const stageRegions = [];
  for (let i = 1; i <= 5; i++) {
    const regionName = `stage.${i}`;
    const region = layout.regions[regionName];
    if (!region) continue;

    stageRegions.push(region);

    const stageComp = components.find(c => c.region === regionName);
    if (stageComp) {
      renderTimelineCard(slide, stageComp, region, renderCtx);
      tracker.record({
        type: 'timeline-card',
        x: region.x, y: region.y,
        w: region.w, h: region.h,
        fontSizes: []
      });
    }
  }

  // 4. 在 stage 卡片之间画箭头
  for (let i = 0; i < stageRegions.length - 1; i++) {
    drawArrowBetweenStagesFixed(slide, stageRegions[i], stageRegions[i + 1], theme);
  }

  // 5. 渲染 matrix（native table）
  const matrixComp = components.find(c => c.region === 'matrix');
  if (matrixComp) {
    const region = layout.regions.matrix;
    renderNativeTable(slide, matrixComp, region, renderCtx);
    tracker.record({
      type: 'native-table',
      x: region.x, y: region.y,
      w: region.w, h: region.h,
      fontSizes: [],
      isNativeTable: true
    });
  }

  // 6. 渲染 footnote（可选）
  const footnoteComp = components.find(c => c.region === 'footnote');
  if (footnoteComp) {
    const region = layout.regions.footnote;
    const text = footnoteComp.slots.text || '';
    renderFootnote(slide, text, region, renderCtx);
  }

  // 运行验证
  const spec = {
    components,
    _pageWidth: canvasSize.width_in,
    _pageHeight: canvasSize.height_in
  };
  const result = validateSlide(spec, tracker.getAll(), kit);

  return {
    slide_id: slideIR.slide_id || 'design-kit-roadmap-5-stage',
    layout_pattern: 'roadmap-5-stage',
    elements_rendered: components.length,
    canvas: canvasSize,
    validation: result
  };
}

module.exports = { build };
