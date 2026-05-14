---
name: feipi-techreport-ppt-skill
description: 用于将用户提供的中文技术材料重构成 CTO 可读的高密度 PPT 单页；在用户要求创建、优化或结构化技术汇报幻灯片时使用。若用户只需普通 PPT 编辑或模板设计，应使用 pptx skill 而非本 skill。
---

# 技术汇报 PPT 单页撰写 Skill

## Purpose

面向 CTO / 技术负责人的中文技术汇报 PPT 单页撰写 skill。用户提供原始事实与数据，本 skill 负责将其结构化、图解化、PPT 化。

## 与 pptx Skill 的关系

本 skill 是 `pptx` skill 之上的**撰写与排版层**，不是替代品。本 skill 负责内容重构与版面决策；`pptx` skill 负责文件创建、渲染与底层操作。本 skill 同时具备可选的 `pptxgenjs-native` 后端。不复制、不修改、不绕过 `pptx` skill 源文件。

## 默认假设

语言中文为主（英文技术术语保留）；受众 CTO；高密度技术汇报风格；16:9 页面；一页一交互一页一确认；正式、克制、工程化审美。不主动询问用户选择风格或受众。

## 质量目标

一页必须同时满足：先结论后证据（标题 5 秒说清判断）；主视觉优先（明确视觉中心）；信息经过重构（压缩、分组或移出主画面）；工程化审美（网格对齐、留白稳定）；可验证（渲染 QA 发现重叠、截断、溢出时自动修复）。

## 不可协商的规则

1. 默认中文输出。
2. 默认受众 CTO，不询问风格或受众。
3. 不做外部调研。
4. 不编造任何事实、数字、架构或性能数据。
5. 仅使用用户提供的源材料。
6. 信息不足时先要求补充，不生成 Page Contract 或 PPT。
7. 一次只生成一页（除非用户明确要求多页规划）。
8. 生成前必须产出 Page Contract 并等待用户确认。
9. 生成后必须执行视觉 QA 并修复布局问题。
10. 使用 `pptx` skill 处理所有 PPTX 级别操作。
11. 大表仅在数据附录场景允许；超出视觉容量的对比矩阵需转为聚焦对比/热力图/KPI 卡片或建议拆页。
12. 重叠、截断、溢出为 QA 失败，不可接受。
13. Draft 模式不绕过事实边界；Production 模式不绕过确认。

## 主工作流

```
Raw Input → Mode Detection → Input Sufficiency → Page Contract / Draft Contract → User Confirmation → PPTX Generation → Visual QA → Repair → Final
```

各步骤的详细说明均移至按需 references，SKILL.md 仅保留触发条件与路由。

### Step 0: 模式检测

检测用户意图进入 `draft`（快速样例）或 `production`（正式交付）模式。默认 production。不明确时可询问。两种模式均不得绕过事实边界。详见 `references/workflow-modes.md` 与 `config/workflow-modes.json`。

### Step 1-2: 输入与充足性检查

判断是否具备：主题、结论、原始事实、关系。缺少任何一项时，按 `references/input-sufficiency.md` 格式要求用户补充，不生成 Page Contract 或 PPT。

### Step 3: Page Contract / 决策确认卡片

信息足够时生成 Page Contract。**用户可见输出为决策确认卡片**（约 15 行以内），列出真正不确定的 2-3 个决策点及候选选项，标注推荐项。内部仍需完整 Page Contract 规划（目标、信息映射、版面蓝图、容量预算）。无不确定性时输出简短确认语句。详见 `references/page-contract.md`、`references/interaction-protocol.md`。

### Step 4: Composition Blueprint

Page Contract 必须包含简短版面蓝图：主版式、各区域空间比例、信息分级（主画面/脚注/拆页建议）。内容过载时必须在生成前降维。详见 `references/layout-patterns.md`、`references/visual-style.md`。

### Step 5: 用户确认

识别确认语（"确认"、"按这个生成"、"可以"、"继续"等）。用户要求调整时更新 Page Contract，不生成 PPT。

### Step 6: PPTX 生成

基于已有 PPTX/模板/从零创建。必须使用 `pptx` skill。先做内部布局预算确认互不抢占。对比页优先生成聚焦对比而非全量矩阵。表格仅承载关键事实。

### Step 7: Visual QA

生成后执行视觉 QA。通过 pipeline 编排器自动完成 Static QA → Repair Plan → Build → Render QA → Report。检查项：溢出、截断、重叠、表格可读性、主视觉、页面密度、字号、箭头/层级/分组、CTO 30 秒理解主结论。详见 `references/visual-qa.md`、`references/qa-gates.md`。

```bash
node scripts/generate_pptx_pipeline.js <slide-ir.json> <output-dir>
```

### Step 8: Repair

QA 失败时 pipeline 自动生成 repair plan，LLM 据此调整 Slide IR 后重跑。修复轮次上限：draft 1 轮，production 3 轮。修复优先级：压缩文字 → 合并 bullet → 表格改 cards → 减少图中节点 → 调整布局 → 增加留白 → 缩小字号 → 建议拆页（须问用户）。详见 `references/repair-policy.md`、`references/auto-iteration.md`。

## 工程化框架

```
Page Contract → Slide IR → Layout Solver → Backend Compile → Static QA + Render QA → Auto Repair (≤3 轮自动迭代) → Final
```

关键约束：Slide IR 为结构化中间层（`schemas/slide-ir.schema.json`），不得引入未确认事实；LLM 不直接写 PPTX 坐标；QA 分 Static/Render 两层；Backend 可选（pptxgenjs-native/template-placeholder/svg-to-drawingml/html-to-pptx），禁止整页截图式图片交付；一页一确认不变；Slide IR 生成后需经 `scripts/validate_slide_ir.js` 校验。

## 环境与验证

必须确认：底层 `pptx` skill 可访问（非 pptxgenjs-native 场景）；Node 运行时可用；LibreOffice 为 Render QA 可选依赖；能完成 Static QA。未就绪时报告阻塞点，不继续生成低质量 PPT。测试入口 `scripts/test.sh`，Pipeline 编排 `scripts/generate_pptx_pipeline.js`。

## Reference 路由

按工作流阶段按需加载，不要一次性读取所有 references：

| 阶段 | References |
|---|---|
| 模式判断 | `references/workflow-modes.md`、`config/workflow-modes.json` |
| 输入检查 | `references/input-sufficiency.md` |
| Page Contract / 交互 | `references/page-contract.md`、`references/interaction-protocol.md` |
| 版面与视觉 | `references/layout-patterns.md`、`references/visual-style.md`、`references/design-system.md` |
| QA 与修复 | `references/visual-qa.md`、`references/qa-gates.md`、`references/repair-policy.md`、`references/auto-iteration.md` |
| 工程框架 | `references/executable-framework.md`、`references/slide-ir.md`、`references/backend-selection.md`、`references/runtime-environment.md` |
| 示例 | `references/examples.md` |
| P0 模板 | `references/p0-scenario-system.md`、`references/p0-template-taxonomy.md` |

完整索引与按需加载说明见 `references/index.md`。
