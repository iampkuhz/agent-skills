/**
 * Slide IR 保守规范化。
 * 不新增事实内容，仅补默认值、规范 ID、排序、补约束。
 */
'use strict';

const DEFAULT_CANVAS = {
  preset: 'wide_16_9',
  width_in: 13.33,
  height_in: 7.5,
  safe_margin_in: { top: 0.5, right: 0.5, bottom: 0.5, left: 0.5 },
};

const REGION_ROLE_PRIORITY = {
  header: 1,
  primary_visual: 2,
  kpi_row: 2,
  evidence_zone: 3,
  side_panel: 3,
  insight_panel: 3,
  takeaway_bar: 1,
  footer: 4,
};

/**
 * 补默认 canvas。
 */
function defaultCanvas(ir) {
  if (!ir.canvas) return { ...DEFAULT_CANVAS };
  const c = { ...ir.canvas };
  if (!c.preset) c.preset = DEFAULT_CANVAS.preset;
  if (!c.width_in) c.width_in = DEFAULT_CANVAS.width_in;
  if (!c.height_in) c.height_in = DEFAULT_CANVAS.height_in;
  if (!c.safe_margin_in) c.safe_margin_in = DEFAULT_CANVAS.safe_margin_in;
  return c;
}

/**
 * 规范 region id：确保以 region_ 开头。
 */
function normalizeRegionId(region, index) {
  if (region.id && region.id.startsWith('region_')) return region.id;
  return region.id || `region_${region.role || index}`;
}

/**
 * 补默认 priority。
 */
function normalizeRegionPriority(region) {
  if (region.priority) return region.priority;
  return REGION_ROLE_PRIORITY[region.role] || 99;
}

/**
 * 排序 elements：按 region_id 分组，再按 z-order 暗示排序。
 */
function sortElements(elements) {
  const roleOrder = { title: 0, subtitle: 1, takeaway: 2, system_component: 3, process_step: 4, data_flow: 5, evidence: 6, risk: 7, explanation: 8, source_note: 9 };
  return [...elements].sort((a, b) => {
    // First by region_id
    if (a.region_id !== b.region_id) return a.region_id.localeCompare(b.region_id);
    // Then by semantic_role order
    const ra = roleOrder[a.semantic_role] ?? 99;
    const rb = roleOrder[b.semantic_role] ?? 99;
    if (ra !== rb) return ra - rb;
    // Then by id for stability
    return a.id.localeCompare(b.id);
  });
}

/**
 * 补默认 constraints。
 */
function defaultConstraints(el) {
  if (!el.constraints) {
    return { must_stay_within_region: true, priority: 'medium' };
  }
  const c = { ...el.constraints };
  if (c.must_stay_within_region === undefined) c.must_stay_within_region = true;
  if (!c.priority) c.priority = 'medium';
  return c;
}

/**
 * 规范化单个 IR。返回规范化后的副本。
 */
function normalize(ir) {
  const out = { ...ir };

  // Default canvas
  out.canvas = defaultCanvas(ir);

  // Default version
  if (!out.version) out.version = 'v1';
  if (!out.language) out.language = 'zh-CN';
  if (!out.audience) out.audience = 'CTO / technical executive';

  // Normalize regions
  if (out.regions && Array.isArray(out.regions)) {
    out.regions = out.regions.map((r, i) => {
      const nr = { ...r };
      nr.id = normalizeRegionId(r, i);
      nr.priority = normalizeRegionPriority(r);
      if (!nr.capacity) nr.capacity = {};
      return nr;
    });
    // Sort by priority
    out.regions.sort((a, b) => a.priority - b.priority);
  }

  // Normalize elements
  if (out.elements && Array.isArray(out.elements)) {
    out.elements = sortElements(out.elements).map(el => {
      const ne = { ...el };
      ne.constraints = defaultConstraints(el);
      if (!ne.source_refs) ne.source_refs = [];
      return ne;
    });
  }

  // Default constraints
  if (!out.constraints) {
    out.constraints = {
      no_overlap: true,
      min_font_pt: { title: 18, body: 10, footnote: 8.5, table_cell: 8.5 },
    };
  }

  // Default provenance
  if (!out.provenance) out.provenance = [];

  return out;
}

module.exports = { normalize, defaultCanvas };
