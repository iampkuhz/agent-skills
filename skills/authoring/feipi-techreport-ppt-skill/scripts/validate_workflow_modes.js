#!/usr/bin/env node
/**
 * Validate workflow-modes configuration.
 *
 * Checks:
 * - JSON is parseable.
 * - Both "draft" and "production" modes exist.
 * - Each mode declares required fields.
 * - production.requires_page_contract_confirmation must be true.
 * - draft.requires_source_provenance must be true.
 * - draft.max_repair_rounds <= production.max_repair_rounds.
 * - If allowed_components is an array, each component must exist in design-system/components/.
 */
'use strict';

const fs = require('fs');
const path = require('path');

const SKILL_DIR = path.resolve(__dirname, '..');
const CONFIG_PATH = path.join(SKILL_DIR, 'config', 'workflow-modes.json');
const COMPONENTS_DIR = path.join(SKILL_DIR, 'design-system', 'components');

const REQUIRED_MODE_FIELDS = [
  'requires_source_provenance',
  'max_repair_rounds',
  'qa_gate',
  'layout_complexity',
  'allowed_components',
];

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf-8'));
  } catch (e) {
    return { __error: `JSON 解析失败: ${e.message}` };
  }
}

function main() {
  const issues = [];

  // 1. Config file exists and is valid JSON
  if (!fs.existsSync(CONFIG_PATH)) {
    issues.push(`配置文件不存在: ${CONFIG_PATH}`);
    const summary = { config_path: CONFIG_PATH, status: 'fail', issues };
    printResult(summary);
    process.exit(1);
  }

  const config = readJson(CONFIG_PATH);
  if (config.__error) {
    issues.push(config.__error);
    const summary = { config_path: CONFIG_PATH, status: 'fail', issues };
    printResult(summary);
    process.exit(1);
  }

  // 2. Both modes exist
  if (!config.modes) {
    issues.push('缺少 modes 字段');
    const summary = { config_path: CONFIG_PATH, status: 'fail', issues };
    printResult(summary);
    process.exit(1);
  }

  if (!config.modes.draft) {
    issues.push('缺少 draft 模式配置');
  }
  if (!config.modes.production) {
    issues.push('缺少 production 模式配置');
  }
  if (issues.length > 0) {
    const summary = { config_path: CONFIG_PATH, status: 'fail', issues };
    printResult(summary);
    process.exit(1);
  }

  // 3. Each mode has required fields
  for (const modeName of ['draft', 'production']) {
    const mode = config.modes[modeName];
    for (const field of REQUIRED_MODE_FIELDS) {
      if (!(field in mode)) {
        issues.push(`${modeName}: 缺少必填字段 "${field}"`);
      }
    }
  }

  // 4. production.requires_page_contract_confirmation must be true
  if (config.modes.production.requires_page_contract_confirmation !== true) {
    issues.push('production.requires_page_contract_confirmation 必须为 true');
  }

  // 5. draft.requires_source_provenance must be true
  if (config.modes.draft.requires_source_provenance !== true) {
    issues.push('draft.requires_source_provenance 必须为 true');
  }

  // 6. draft.max_repair_rounds <= production.max_repair_rounds
  if (
    typeof config.modes.draft.max_repair_rounds === 'number' &&
    typeof config.modes.production.max_repair_rounds === 'number' &&
    config.modes.draft.max_repair_rounds > config.modes.production.max_repair_rounds
  ) {
    issues.push(
      `draft.max_repair_rounds (${config.modes.draft.max_repair_rounds}) 不得大于 production.max_repair_rounds (${config.modes.production.max_repair_rounds})`,
    );
  }

  // 7. Validate allowed_components references
  const draftComponents = config.modes.draft.allowed_components;
  if (Array.isArray(draftComponents)) {
    // Build set of existing component ids from design-system/components/*.json
    const existingComponentIds = new Set();
    if (fs.existsSync(COMPONENTS_DIR)) {
      const files = fs.readdirSync(COMPONENTS_DIR).filter(f => f.endsWith('.json'));
      for (const file of files) {
        try {
          const doc = JSON.parse(fs.readFileSync(path.join(COMPONENTS_DIR, file), 'utf-8'));
          if (doc.id && typeof doc.id === 'string') {
            existingComponentIds.add(doc.id);
          }
          // Also accept file stem (e.g., "text-hierarchy" from "text-hierarchy.json")
          existingComponentIds.add(file.replace('.json', ''));
        } catch (e) {
          // skip unreadable files
        }
      }
    }
    for (const compId of draftComponents) {
      if (!existingComponentIds.has(compId)) {
        issues.push(
          `draft.allowed_components: 组件 "${compId}" 在 design-system/components/ 中不存在`,
        );
      }
    }
  }

  // Summary
  const summary = {
    config_path: CONFIG_PATH,
    modes: Object.keys(config.modes),
    draft: {
      label: config.modes.draft.label,
      qa_gate: config.modes.draft.qa_gate,
      max_repair_rounds: config.modes.draft.max_repair_rounds,
      layout_complexity: config.modes.draft.layout_complexity,
    },
    production: {
      label: config.modes.production.label,
      qa_gate: config.modes.production.qa_gate,
      max_repair_rounds: config.modes.production.max_repair_rounds,
      layout_complexity: config.modes.production.layout_complexity,
    },
    issues,
    status: issues.length === 0 ? 'pass' : 'fail',
  };

  printResult(summary);
  if (issues.length > 0) process.exit(1);
}

function printResult(summary) {
  if (process.argv.includes('--json')) {
    process.stdout.write(JSON.stringify(summary, null, 2) + '\n');
  } else {
    console.log('Workflow Modes Validation');
    console.log(`  config: ${summary.config_path}`);
    console.log(`  modes: ${summary.modes.join(', ')}`);
    console.log(`  draft: ${summary.draft.label} (qa_gate=${summary.draft.qa_gate}, repair=${summary.draft.max_repair_rounds}, complexity=${summary.draft.layout_complexity})`);
    console.log(`  production: ${summary.production.label} (qa_gate=${summary.production.qa_gate}, repair=${summary.production.max_repair_rounds}, complexity=${summary.production.layout_complexity})`);
    if (summary.issues.length > 0) {
      console.log('  issues:');
      for (const issue of summary.issues) console.log(`    - ${issue}`);
    }
    console.log(`  status: ${summary.status}`);
  }
}

main();
