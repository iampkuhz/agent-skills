/**
 * Design Kit Loader — 读取 manifest.json 及所有 entrypoints。
 */

'use strict';

const path = require('path');
const fs = require('fs');

const DESIGN_KIT_ROOT = '/Users/zhehan/Downloads/feipi-ppt-design-kit/';

let _cachedKit = null;

/**
 * 加载并缓存整个 design kit。
 */
function loadDesignKit() {
  if (_cachedKit) return _cachedKit;

  const manifest = loadJson(path.join(DESIGN_KIT_ROOT, 'manifest.json'));
  const ep = manifest.entrypoints;

  const theme = loadJson(path.join(DESIGN_KIT_ROOT, ep.theme));
  const typography = loadJson(path.join(DESIGN_KIT_ROOT, ep.typography));
  const density = loadJson(path.join(DESIGN_KIT_ROOT, ep.tables));
  const densityTokens = loadJson(path.join(DESIGN_KIT_ROOT, 'tokens/density/default-density.json'));
  const tables = loadJson(path.join(DESIGN_KIT_ROOT, ep.tables));
  const validation = loadJson(path.join(DESIGN_KIT_ROOT, ep.validation));

  // 加载组件注册表 + 各组件 spec
  const compRegistry = loadJson(path.join(DESIGN_KIT_ROOT, ep.components));
  const components = {};
  for (const entry of compRegistry.components) {
    components[entry.name] = loadJson(path.join(DESIGN_KIT_ROOT, entry.path));
  }

  // 加载布局注册表 + 各布局 spec
  const layoutRegistry = loadJson(path.join(DESIGN_KIT_ROOT, ep.layouts));
  const layouts = {};
  for (const entry of layoutRegistry.layouts) {
    layouts[entry.name] = loadJson(path.join(DESIGN_KIT_ROOT, entry.path));
  }

  _cachedKit = {
    manifest,
    theme,
    typography,
    density: densityTokens,
    tables,
    validation,
    components,
    layouts,
    rootDir: DESIGN_KIT_ROOT
  };

  return _cachedKit;
}

function loadJson(filePath) {
  const raw = fs.readFileSync(filePath, 'utf-8');
  return JSON.parse(raw);
}

/**
 * 清除缓存（测试用）。
 */
function clearCache() {
  _cachedKit = null;
}

module.exports = {
  loadDesignKit,
  clearCache,
  DESIGN_KIT_ROOT
};
