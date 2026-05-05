# Schemas

本目录存放 Presentation Compiler 的结构化 Schema 定义。

## 当前状态

- `slide-ir.schema.json` — Slide IR 的 JSON Schema 定义（Draft 2020-12），包含 12+ 顶层字段：version、slide_id、language、audience、canvas、layout_pattern、source_summary、takeaway、regions、elements、constraints、provenance。
- 校验脚本：`scripts/validate_slide_ir.js`（轻量校验，不依赖外部 npm 包）。

## 后续任务

- 定义 QA Report 和 Repair Plan 的 JSON Schema，使检测结果可被下游工具消费。
- 添加 schema 验证脚本的完整 JSON Schema 校验（当前为轻量校验）。
