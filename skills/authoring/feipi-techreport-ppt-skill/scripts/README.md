# Scripts

本目录包含 Presentation Compiler 的脚本入口。

## 脚本入口

| 脚本 | 语言 | 职责 |
|------|------|------|
| `test.sh` | Bash | 测试入口：结构检查 + 术语校验 + Static QA + Pipeline |
| `validate_slide_ir.js` | Node.js | Slide IR 校验（必填字段、枚举值、region 引用、provenance） |
| `inspect_slide_ir_layout.js` | Node.js | Static QA CLI（语义碰撞检测，`--json` 输出） |
| `build_pptx_from_ir.js` | Node.js | PPTX 编译（Slide IR → PPTX，含 Static QA 门禁） |
| `generate_pptx_pipeline.js` | Node.js | Pipeline 编排入口（Validate → Static QA → Build → Render QA → Report） |
| `render_pptx.sh` | Bash | PPTX → PNG 渲染包装器（LibreOffice/soffice headless） |
| `render_pptx.js` | Node.js | 渲染 manifest 生成 |
| `visual_qa_report.js` | Node.js | 视觉 QA 报告生成 |

## 第二阶段新增入口

| 脚本 | 语言 | 职责 | 状态 |
|------|------|------|------|
| `doctor.js` | Node.js | 运行时环境诊断，输出中文能力矩阵 | ✅ 已实现 |
| `runtime_capabilities.js` | Node.js | JSON 格式运行时能力探测 | ✅ 已实现 |
| `validate_style_lock.js` | Node.js | Style lock 校验（必填 token、颜色格式、字号下限） | ✅ 已实现 |
| `run_benchmarks.js` | Node.js | Benchmark 套件批量运行 | ✅ 已实现 |
| `score_quality_report.js` | Node.js | 质量评分（基于 rubric） | ✅ 已实现 |
| `normalize_slide_ir.js` | Node.js | Slide IR 保守规范化 | ✅ 已实现 |
| `check_provenance.js` | Node.js | Provenance 完整性检查 | ✅ 已实现 |
| `solve_slide_layout.js` | Node.js | Layout solver 入口 | ✅ 已实现 |
| `inspect_pptx_artifact.js` | Node.js | PPTX 产物反检（`--json`、`--expected-slides`、`--release`） | ✅ 已实现 |
| `create_render_montage.js` | Node.js | 渲染结果 HTML 拼图浏览页 | ✅ 已实现 |
| `compare_render_baseline.js` | Node.js | 渲染回归比较 | ✅ 已实现 |
| `apply_repair_plan.js` | Node.js | 保守自动修复引擎 | ✅ 已实现 |
| `clean_pipeline_cache.js` | Node.js | Pipeline 缓存清理 | ✅ 已实现 |
| `release_gate.sh` | Bash | 端到端发布门禁 | ✅ 已实现 |
| `generate_demo_deck.js` | Node.js | Demo deck 生成 | ✅ 已实现 |

## 依赖管理

本 skill 在根目录提供 `package.json` 和 `package-lock.json`，声明了必需的 Node.js 依赖。

```bash
# 安装所有依赖（推荐：skill 目录本地安装，使用 lock 文件确保可重复）
cd skills/authoring/feipi-techreport-ppt-skill && npm ci

# 首次或 package.json 变更后可用 npm install 生成/更新 lock 文件
cd skills/authoring/feipi-techreport-ppt-skill && npm install

# 不推荐全局安装，因为 Node module resolution 不一定能找到全局包
# npm install -g pptxgenjs
```

`node_modules/` 已在仓库根 `.gitignore` 中声明忽略，不会出现在待提交文件中。

## 三档验收

| 档位 | 需要 | 能力 | 命令 |
|------|------|------|------|
| **static-only** | 无 | 验证 IR 结构、静态 QA、provenance、容量 | `bash scripts/test.sh` |
| **pptx-build** | `pptxgenjs` | 编译 IR → PPTX，验证布局和无重叠 | `npm ci && bash scripts/test.sh` |
| **full visual** | `pptxgenjs` + LibreOffice | 渲染 PPTX → PNG，像素级视觉对比 | `npm ci && brew install --cask libreoffice` |

当前环境可通过 `node scripts/doctor.js --json` 查看 `pipeline_level` 字段。

## 使用示例

```bash
# 测试
bash scripts/test.sh

# Slide IR 校验
node scripts/validate_slide_ir.js fixtures/architecture-map.slide-ir.json

# Static QA
node scripts/inspect_slide_ir_layout.js fixtures/architecture-map.slide-ir.json --json

# 编译 PPTX
node scripts/build_pptx_from_ir.js fixtures/architecture-map.slide-ir.json /tmp/output.pptx

# Pipeline（完整运行）
node scripts/generate_pptx_pipeline.js fixtures/architecture-map.slide-ir.json /tmp/output/

# Pipeline（仅 dry-run）
node scripts/generate_pptx_pipeline.js fixtures/architecture-map.slide-ir.json /tmp/output/ --dry-run

# 渲染
bash scripts/render_pptx.sh /tmp/output.pptx /tmp/render/

# Visual QA
node scripts/visual_qa_report.js /tmp/render/render-manifest.json --json
```

## 约束

- 脚本应保持最小外部依赖（Node.js 标准库 + 可选 `pptxgenjs`）。
- `pptxgenjs` 未安装时 gracefully skip，不阻断测试。
- LibreOffice/soffice 未安装时 graceful skip，渲染测试不阻断整体测试。
