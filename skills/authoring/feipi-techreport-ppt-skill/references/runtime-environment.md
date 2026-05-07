# 运行时环境（Runtime Environment）

## 最小运行环境

以下环境足以运行本 skill 的校验、Static QA 和 Pipeline dry-run 模式：

| 依赖 | 最低版本 | 用途 |
|------|----------|------|
| Node.js | 18+ | 脚本运行时 |
| npm | 9+ | 可选，仅用于安装 pptxgenjs |

在最小环境下，以下功能**可用**：
- `scripts/validate_slide_ir.js` — Slide IR 校验
- `scripts/inspect_slide_ir_layout.js` — Static QA 布局检查
- `scripts/generate_pptx_pipeline.js --dry-run` — Pipeline dry-run 模式
- `scripts/doctor.js` — 运行时诊断
- `scripts/runtime_capabilities.js` — JSON 能力探测

在最小环境下，以下功能**会被跳过**：
- PPTX 编译（需要 `pptxgenjs`）
- Render QA（需要 LibreOffice/soffice）
- Pipeline 完整运行（no-render 模式也需要 `pptxgenjs`）

## 完整质量环境

在最小环境基础上增加：

| 依赖 | 用途 |
|------|------|
| pptxgenjs（npm 包） | Slide IR → PPTX 编译、PPTX 生成 |
| LibreOffice / soffice | PPTX → PNG 渲染、Render QA |

在完整环境下，所有 Pipeline 阶段均可运行：Validate → Static QA → Build PPTX → Render QA → Pipeline Report。

## 安装建议

### macOS

```bash
# PPTX 生成
cd skills/authoring/feipi-techreport-ppt-skill && npm ci
# 或首次安装
cd skills/authoring/feipi-techreport-ppt-skill && npm install

# 渲染引擎（可选）
brew install --cask libreoffice
```

### Linux（Debian/Ubuntu）

```bash
# PPTX 生成
cd skills/authoring/feipi-techreport-ppt-skill && npm ci

# 渲染引擎（可选）
apt-get install libreoffice
```

> `node_modules/` 已在仓库根 `.gitignore` 中声明忽略。始终在 skill 目录下运行 `npm ci` 或 `npm install`。

## 可选依赖的影响

- **缺少 pptxgenjs**：所有 PPTX 生成步骤会被跳过，Pipeline 报告中标记为 `build: skipped`。不影响 Static QA 和 IR 校验。
- **缺少 LibreOffice**：Render QA 阶段会被跳过，Pipeline 报告中标记为 `render: skipped`。不影响 PPTX 编译和 Static QA。
- 两个都缺少时，Pipeline 级别为 `static-only`。此时只能验证 Slide IR 的结构和布局语义，无法验证渲染后视觉效果。

## CI 环境

CI 环境中建议：

- 安装 `pptxgenjs` 以验证 PPTX 编译。
- 不强制安装 LibreOffice（CI 中 headless 渲染通常不需要，可用 skip manifest 验证）。
- 运行 `scripts/test.sh` 作为 CI 门禁。
- 在 CI 中可通过 `node scripts/doctor.js --json` 获取环境状态用于日志记录。

## 环境探测

```bash
# 人类可读诊断
node scripts/doctor.js

# JSON 格式（供脚本/CI 消费）
node scripts/doctor.js --json
# 或
node scripts/runtime_capabilities.js
```

`pipeline_level` 枚举值：
- `static-only` — 仅可运行 Static QA 和 IR 校验
- `pptx-build` — 可运行 Static QA + PPTX 编译
- `render-qa` — 可运行 Static QA + PPTX 编译 + 渲染（当前未使用，`full` 的同义词）
- `full` — 完整链路可用
