/**
 * Apply Repair — 保守自动修复引擎。
 * 应用 repair plan 中的确定性修复动作，不改事实，不激进重排。
 */
'use strict';

const moveLabel = require('./strategies/move-label');
const resizeRegion = require('./strategies/resize-region');
const compressText = require('./strategies/compress-text');
const splitNeeded = require('./strategies/split-needed');

/**
 * 深拷贝 Slide IR。
 */
function cloneIR(ir) {
  return JSON.parse(JSON.stringify(ir));
}

/**
 * 应用单个修复动作。
 * @param {Object} slideIR - 当前 Slide IR
 * @param {Object} action - repair action
 * @returns {{success: boolean, changes: Array, needs_user_decision: boolean}}
 */
function applyAction(slideIR, action) {
  const changes = [];
  const elements = slideIR.elements || [];
  let needsUserDecision = false;

  switch (action.type) {
    case 'move_or_resize': {
      // 尝试移动标签避开节点
      const targets = action.target_element_ids || [];
      for (const tid of targets) {
        const labelElem = elements.find(e => e.id === tid);
        if (!labelElem) continue;

        // 找主区域内的 component_node 作为避让目标
        const nodes = elements.filter(e =>
          e.kind === 'component_node' &&
          e.region_id === labelElem.region_id
        );

        const regionBounds = _getRegionBounds(slideIR, labelElem.region_id);
        const result = moveLabel.moveLabel(labelElem, nodes, regionBounds);

        if (result.success && result.new_layout) {
          labelElem.layout = { ...labelElem.layout, ...result.new_layout };
          changes.push({ element_id: tid, action: 'moved', from: labelElem.layout, to: result.new_layout });
        } else if (!result.success) {
          needsUserDecision = true;
          changes.push({ element_id: tid, action: 'move_failed', message: result.message });
        }
      }
      break;
    }

    case 'shorten_text': {
      const targets = action.target_element_ids || [];
      for (const tid of targets) {
        const elem = elements.find(e => e.id === tid);
        if (!elem) continue;

        const text = _extractElementText(elem);
        if (!text) continue;

        const result = compressText.compressText(text, elem);
        if (result.success && result.compressed_text) {
          _setElementText(elem, result.compressed_text);
          elem.repair_provenance = result.provenance;
          changes.push({ element_id: tid, action: 'text_compressed', from: text.slice(0, 30), to: result.compressed_text.slice(0, 30) });
        } else {
          needsUserDecision = true;
          changes.push({ element_id: tid, action: 'compress_failed', message: result.message });
        }
      }
      break;
    }

    case 'adjust_layout': {
      // 将越界元素拉回 region
      const targets = action.target_element_ids || [];
      for (const tid of targets) {
        const elem = elements.find(e => e.id === tid);
        if (!elem) continue;

        const regionBounds = _getRegionBounds(slideIR, elem.region_id);
        const result = resizeRegion.clampToRegion(elem, regionBounds);

        if (result.success && result.new_layout) {
          elem.layout = { ...elem.layout, ...result.new_layout };
          changes.push({ element_id: tid, action: 'clamped', new_layout: result.new_layout });
        } else if (!result.success) {
          needsUserDecision = true;
          changes.push({ element_id: tid, action: 'clamp_failed', message: result.message });
        }
      }
      break;
    }

    case 'adjust_font': {
      // 微调字号（不低于下限）
      const targets = action.target_element_ids || [];
      for (const tid of targets) {
        const elem = elements.find(e => e.id === tid);
        if (!elem) continue;
        const style = elem.style || {};
        const currentFont = style.font_size_pt || 10;
        const newFont = Math.max(compressText.MIN_FONT_PT, currentFont);
        if (newFont !== currentFont) {
          elem.style = { ...style, font_size_pt: newFont };
          changes.push({ element_id: tid, action: 'font_adjusted', from: currentFont, to: newFont });
        }
      }
      break;
    }

    default:
      needsUserDecision = true;
      changes.push({ action: action.type, message: `未知修复动作: ${action.type}` });
  }

  return { success: true, changes, needs_user_decision: needsUserDecision };
}

/**
 * 应用整个 repair plan。
 * @param {Object} slideIR - Slide IR
 * @param {Object} repairPlan - repair plan
 * @returns {Object} repaired IR + diff summary
 */
function applyRepairPlan(slideIR, repairPlan) {
  const ir = cloneIR(slideIR);
  const allChanges = [];
  let needsUserDecision = false;
  let splitRecommendation = null;

  for (const action of repairPlan.actions || []) {
    const result = applyAction(ir, action);
    allChanges.push(...result.changes);
    if (result.needs_user_decision) needsUserDecision = true;
  }

  // 检查是否需要拆分
  if (repairPlan.requires_user_decision || needsUserDecision) {
    const split = splitNeeded.needsSplit(ir, { issues: [] });
    if (split.needs_split) {
      splitRecommendation = split;
    }
  }

  return {
    repaired_ir: ir,
    changes: allChanges,
    needs_user_decision: needsUserDecision,
    split_recommendation: splitRecommendation,
    change_summary: {
      total_changes: allChanges.length,
      moved: allChanges.filter(c => c.action === 'moved').length,
      text_compressed: allChanges.filter(c => c.action === 'text_compressed').length,
      clamped: allChanges.filter(c => c.action === 'clamped').length,
      font_adjusted: allChanges.filter(c => c.action === 'font_adjusted').length,
      failed: allChanges.filter(c => c.action?.endsWith('_failed')).length
    }
  };
}

// --- Internal helpers ---

function _getRegionBounds(slideIR, regionId) {
  if (!regionId) return null;
  const regions = slideIR.regions || [];
  const region = regions.find(r => r.id === regionId || r.region_id === regionId);
  if (region && region.bounds) return region.bounds;
  return null;
}

function _extractElementText(elem) {
  if (typeof elem.content === 'string') return elem.content;
  if (elem.content && elem.content.label) return elem.content.label;
  if (elem.content && elem.content.text) return elem.content.text;
  return '';
}

function _setElementText(elem, text) {
  if (typeof elem.content === 'string') {
    elem.content = text;
  } else if (elem.content && elem.content.label !== undefined) {
    elem.content.label = text;
  } else if (elem.content && elem.content.text !== undefined) {
    elem.content.text = text;
  }
}

module.exports = { applyRepairPlan, applyAction, cloneIR };
