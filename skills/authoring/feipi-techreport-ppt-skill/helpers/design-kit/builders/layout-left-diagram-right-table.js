/**
 * Left-Diagram-Right-Table Builder
 * 使用 design-kit 组件系统渲染左侧架构图 + 右侧表格布局。
 */

'use strict';

const { loadDesignKit } = require('../kit-loader');
const { getRenderer, renderCapabilityGroup, renderNativeTable } = require('../components');
const { getDensityPreset, resolveSize, resolveVariant, applyDensity, resolveToken } = require('../token-resolver');
const { validateSlide, createRenderTracker } = require('../validation');

/**
 * 渲染架构模块（左侧区域）— roundRect + title + subtitle + items。
 */
function renderArchitectureModule(slide, comp, region, ctx) {
  const { size, variant, slots } = comp;
  const { theme, densityPreset } = ctx;

  const compSpec = ctx.kit.components['architecture-module'];
  const baseSize = resolveSize(compSpec, size || 'lg');
  const sized = densityPreset ? applyDensity(baseSize, densityPreset) : baseSize;
  const v = resolveVariant(compSpec, variant || 'neutral', theme);

  const padX = sized.paddingX || 0.18;
  const padY = sized.paddingY || 0.14;

  // 背景
  slide.addShape('roundRect', {
    x: region.x,
    y: region.y,
    w: region.w,
    h: region.h,
    fill: { color: v.fill || '#FFFFFF' },
    line: { color: v.stroke || '#CBD5E1', width: 0.5 },
    rectRadius: Math.min(0.2, (sized.radius || 0.16) * 0.8)
  });

  // 标题
  let curY = region.y + padY;
  const title = slots.title || '';
  if (title) {
    const titleH = sized.titleFont ? sized.titleFont / 72 * 1.6 : 0.35;
    slide.addText(title, {
      x: region.x + padX,
      y: curY,
      w: region.w - padX * 2,
      h: titleH,
      fontSize: sized.titleFont || 14,
      fontFace: ctx.fontFace || 'Kaiti SC',
      color: v.titleColor || '#0F172A',
      bold: true,
      align: 'left',
      valign: 'top',
      wrap: true,
      margin: 0
    });
    curY += titleH;
  }

  // 副标题
  const subtitle = slots.subtitle || '';
  if (subtitle) {
    const subtitleH = sized.bodyFont ? sized.bodyFont / 72 * 1.4 : 0.25;
    slide.addText(subtitle, {
      x: region.x + padX,
      y: curY,
      w: region.w - padX * 2,
      h: subtitleH,
      fontSize: sized.bodyFont || 10,
      fontFace: ctx.fontFace || 'Kaiti SC',
      color: v.bodyColor || '#334155',
      bold: false,
      align: 'left',
      valign: 'top',
      wrap: true,
      margin: 0
    });
    curY += subtitleH + (sized.childGap || 0.08);
  }

  // Items 列表
  const items = slots.items || [];
  if (items.length > 0) {
    const availableH = region.h - (curY - region.y) - padY;

    const itemTexts = items.map((item, i) => ({
      text: (i > 0 ? '\n' : '') + '  •  ' + item,
      options: {
        fontSize: sized.bodyFont || 10,
        fontFace: ctx.fontFace || 'Kaiti SC',
        color: v.bodyColor || '#334155',
        bold: false
      }
    }));

    slide.addText(itemTexts, {
      x: region.x + padX,
      y: curY,
      w: region.w - padX * 2,
      h: availableH,
      align: 'left',
      valign: 'top',
      wrap: true,
      margin: 0
    });
  }
}

/**
 * 渲染 title 区域。
 */
function renderTitleText(slide, text, region, ctx) {
  slide.addText(text, {
    x: region.x,
    y: region.y,
    w: region.w,
    h: region.h,
    fontSize: ctx.typography ? ctx.typography.levels.pageTitle.fontSize : 28,
    fontFace: ctx.fontFace || 'Kaiti SC',
    color: resolveToken('text.primary', ctx.theme) || '#0F172A',
    bold: true,
    align: 'left',
    valign: 'top',
    wrap: true,
    margin: 0
  });
}

function build(pres, slideIR, thm) {
  const kit = loadDesignKit();
  const layout = kit.layouts['left-diagram-right-table'];
  const theme = kit.theme;
  const densityName = slideIR.density || kit.manifest.defaultDensity;
  const densityPreset = getDensityPreset(densityName, kit.density);

  const canvasSize = thm.getCanvasSize(slideIR.canvas);
  const slide = pres.addSlide();
  const components = slideIR.components || [];

  slide.background = { color: resolveToken('surface.page', theme) || '#F8FAFC' };

  // 构建渲染上下文
  const ctx = {
    kit,
    theme,
    densityPreset,
    fontFace: kit.typography.fontFamily || 'Kaiti SC',
    typography: kit.typography,
    tablePresets: kit.tables
  };

  const tracker = createRenderTracker();

  // 渲染 title
  if (slideIR.title) {
    renderTitleText(slide, slideIR.title, layout.regions.title, ctx);
  }

  // 按 region 分组组件
  for (const comp of components) {
    const regionName = comp.region;
    const region = layout.regions[regionName];
    if (!region) {
      continue;
    }

    const rendererName = comp.type;

    if (rendererName === 'architecture-module') {
      renderArchitectureModule(slide, comp, region, ctx);
      tracker.record({
        type: rendererName,
        x: region.x, y: region.y,
        w: region.w, h: region.h,
        fontSizes: [14, 10]
      });
    } else if (rendererName === 'native-table') {
      renderNativeTable(slide, comp, region, ctx);
      tracker.record({
        type: 'native-table',
        x: region.x, y: region.y,
        w: region.w, h: region.h,
        fontSizes: [],
        isNativeTable: true
      });
    } else if (rendererName === 'capability-group') {
      renderCapabilityGroup(slide, comp, region, ctx);
      tracker.record({
        type: 'capability-group',
        x: region.x, y: region.y,
        w: region.w, h: region.h,
        fontSizes: []
      });
    } else {
      // 通用渲染器 fallback
      const renderer = getRenderer(rendererName);
      if (renderer) {
        renderer(slide, comp, region, ctx);
      }
    }
  }

  // 运行验证
  const spec = {
    components,
    _pageWidth: canvasSize.width_in,
    _pageHeight: canvasSize.height_in
  };
  const result = validateSlide(spec, tracker.getAll(), kit);

  return {
    slide_id: slideIR.slide_id || 'design-kit-left-diagram-right-table',
    layout_pattern: 'left-diagram-right-table',
    elements_rendered: components.length,
    canvas: canvasSize,
    validation: result
  };
}

module.exports = { build };
