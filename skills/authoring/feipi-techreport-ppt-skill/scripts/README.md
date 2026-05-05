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
