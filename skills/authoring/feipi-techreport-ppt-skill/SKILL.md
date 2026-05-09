---
name: feipi-techreport-ppt-skill
description: Creates one-slide-at-a-time Chinese technical report PowerPoint slides from user-provided source material. Use when the user asks to create, refine, or structure a high-density technical report slide with diagrams, tables, bullet text, architecture maps, process flows, comparison matrices, roadmaps, metrics dashboards, or CTO-facing technical presentation content. Built as an authoring layer above the pptx skill; verifies input sufficiency, produces a Page Contract for confirmation, then generates or edits PPTX slides.
---

# 技术汇报 PPT 单页撰写 Skill

## Purpose

这是一个面向 CTO / 技术负责人的中文技术汇报 PPT 单页撰写 skill。

CTO 有技术背景，关心方向、路线、逻辑合理性、风险与取舍，但不默认了解当前具体领域细节。

用户提供原始事实与数据，本 skill 负责将其结构化、图解化、PPT 化，输出适合 CTO 阅读的高密度技术汇报单页。

## 与底层 pptx Skill 的关系

本 skill 是 Anthropic 官方 `pptx` skill 之上的**撰写与排版层**，不是替代品。

- 本 skill 负责：信息充足性检查、Page Contract 确认、内容重构、版面选择、视觉 QA、修复策略、Slide IR 生成、Pipeline 编排。
- `pptx` skill 负责：PPTX 文件创建、编辑、模板处理、渲染、缩略图生成、XML 操作、底层文件操作。
- 本 skill 调用 `pptx` skill 完成所有 PPTX 级别的读写操作（当环境中可用时）。
- 本 skill 同时具备独立的 `pptxgenjs-native` 后端（可选依赖），可在无 `pptx` skill 时直接编译 PPTX。
- 本 skill 不复制、不修改、不绕过 `pptx` skill 的源文件。

## 默认假设

所有默认值内置，不主动询问用户：

- **默认语言**：中文为主，英文技术术语保留。
- **默认受众**：CTO / 技术负责人。
- **默认风格**：高密度技术汇报 PPT，少装饰，重结构、重图解、重结论。
- **默认页面比例**：16:9。
- **默认交互**：一页一交互，一页一确认。
- **默认信息密度**：一页可同时包含图、表格、列表文字，但必须可读。
- **默认视觉方向**：正式、克制、工程化、咨询式，不做营销页，不做花哨动效。

## 质量目标

生成结果必须像“可直接发给 CTO 的单页技术汇报”，不是把原始材料机械塞进 PPT。

一页必须同时满足：

- **先结论后证据**：标题区能在 5 秒内说清本页判断。
- **主视觉优先**：页面有一个明确视觉中心，表格、图、卡片不能互相抢占。
- **信息经过重构**：长表、长段落、脚注和补充解释必须被压缩、分组或移出主画面。
- **工程化审美**：网格对齐、留白稳定、颜色克制、重点突出。
- **可验证**：生成后必须经过渲染或缩略图检查，发现重叠、截断、溢出时要自动修复。

## 不可协商的规则

1. Always respond in Chinese unless the user explicitly requests otherwise.
2. Default audience is CTO / technical executive.
3. Do not ask the user to choose audience, visual style, color theme, or information density.
4. Do not perform external research.
5. Do not invent facts, numbers, architecture details, comparisons, conclusions, roadmap claims, or performance metrics.
6. Use only user-provided source material for factual content.
7. Before creating or editing a slide, verify that the user provided enough raw information.
8. If raw information is insufficient, ask for the missing source material before drafting the slide.
9. Generate exactly one slide at a time unless the user explicitly asks for a multi-slide plan.
10. Before generating a slide, produce a Page Contract and wait for user confirmation.
11. After generating a slide, perform visual QA and repair layout issues when possible.
12. Use the underlying pptx skill for PPTX creation, editing, template handling, rendering, and low-level file operations.
13. This skill is an authoring and layout layer, not a replacement for the pptx skill.
14. Do not create a slide that is mainly a large dense table unless the confirmed purpose is a data appendix.
15. If a comparison matrix exceeds the visual budget, convert it into a focused comparison, heatmap, KPI cards, or ask to split pages.
16. Any overlap, clipped text, unreadable table, or footnote collision is a QA failure, not an acceptable draft.
17. Draft mode cannot bypass fact boundaries: no invented facts, no missing source provenance, even in draft.
18. Production mode cannot bypass confirmation: Page Contract must be confirmed before PPTX generation.

## 主工作流

```
Raw Input
→ Mode Detection (draft / production)
→ Input Sufficiency Check
→ Page Contract (或 Draft Contract)
→ Composition Blueprint
→ User Confirmation
→ PPTX Generation / Editing
→ Visual QA (对应模式 gate)
→ Repair if needed
→ Final Response
```

### Step 0: 模式检测

在接收用户请求时，先判断使用 `draft` 还是 `production` 模式：

- **进入 draft**：用户说"先出个样例""先看看效果""快速出图""草稿""不用太精细""随便出一个版本""看看大概样子"。
- **进入 production**：用户说"正式版""生产版""最终交付""可发布""按确认版生成""定稿"。
- **默认**：用户未明确说 draft 时，保持当前标准 Page Contract 优先流程（等价于 production）。
- **不明确时**：可询问用户"需要快速出一个草稿看看效果，还是直接走正式版？"

模式差异不得绕过事实边界：draft 模式同样不得编造事实、不得跳过来源追溯。
模式差异不得绕过确认：production 模式不得跳过 Page Contract。

详细模式定义、配置、升级流程见 `references/workflow-modes.md`，模式配置位于 `config/workflow-modes.json`。

### Step 1: Raw Input

用户可以提供：一段文字、bullet 列表、表格数据、架构描述、流程说明、对比项、阶段规划、已有 PPTX 或模板、想表达的大意。

### Step 2: Input Sufficiency Check

必须先判断信息是否足够支撑当前页。

最低输入要求：

1. **主题**：这一页讲什么。
2. **结论**：希望 CTO 看完记住什么。
3. **原始事实**：支撑结论的事实、数据、模块、流程、对象、对比项。
4. **关系**：内容之间是什么关系（分层、流程、对比、因果、阶段、取舍）。

如果缺少关键项，不要生成 Page Contract，不要生成 PPT。直接要求用户补充原始信息。

信息不足时输出：

```
当前信息不足，无法稳定生成 PPT 单页。请补充以下原始信息：

1. 缺少【...】：...
2. 缺少【...】：...
3. 缺少【...】：...

请直接补充原始信息，不需要描述设计风格。
```

详细检查规则见 `references/input-sufficiency.md`。

### Step 3: Page Contract

信息足够时，先生成 Page Contract，不生成 PPT。

**Production 模式**：必须生成标准 Page Contract，等待用户确认。

**Draft 模式**：可生成简化版 `Draft Contract`，仅包含主题、结论、内容范围，减少确认环节，直接出可讨论的版本。但输出必须标记为草稿，不得伪装成最终版。

标准格式（Production）：

```
## Page Contract

### 1. 本页目标
...

### 2. 一句话结论
...

### 3. 使用的原始信息
- ...

### 4. 页面内容范围
本页包含：
- ...

本页不包含：
- ...

### 5. 推荐页面结构
- 主图：...
- 表格：...
- 文字：...
- 结论区：...

### 6. 版面蓝图
- 主视觉区域：...
- 证据/说明区域：...
- 脚注/来源区域：...
- 需要压缩或不进入主画面的信息：...

### 7. 生成前确认
请确认是否按这个内容范围生成当前页 PPT。
```

禁止在 Page Contract 阶段擅自生成 PPTX。详细规则见 `references/page-contract.md`。

### Step 4: Composition Blueprint

Page Contract 必须包含一个面向生成阶段的简短版面蓝图：

- 选择一个主版式，不列候选方案。
- 写清主视觉、证据区、结论区、脚注区的空间比例。
- 写清哪些原始信息会进入主画面，哪些会压缩成脚注、备注或建议拆页。
- 如果发现内容会形成大表、长脚注、重叠风险，必须在生成前降维，而不是生成后硬挤。

详细规则见 `references/page-contract.md`、`references/layout-patterns.md`、`references/visual-style.md`。

### Step 5: User Confirmation

只有用户明确确认后，才进入 PPTX 生成或修改。

可识别确认语："确认"、"按这个生成"、"可以"、"继续"、"生成"、"就这样"、"没问题"。

如果用户要求调整，则更新 Page Contract，不生成 PPT。

详细交互协议见 `references/interaction-protocol.md`。

### Step 6: PPTX Generation / Editing

确认后：

- 如果用户提供了已有 PPTX：调用底层 `pptx` skill 读取、分析、修改。
- 如果用户提供了模板：基于模板创建或编辑。
- 如果用户没有提供 PPTX：从零创建一页 PPTX 或追加到当前 deck。
- 必须使用底层 `pptx` skill 处理所有 PPTX 文件操作。
- 生成时不要加入用户未提供的事实内容。
- 可以改写、压缩、重组用户提供的内容。
- 生成前必须先做内部布局预算，确认标题、主体、侧栏、底部结论、脚注互不抢占。
- 对比页优先生成“聚焦对比 + 重点高亮”，不要默认生成全量矩阵。
- 表格只能承载最关键事实；完整数据需要进入备注、脚注摘要或建议拆页。

页面结构选择见 `references/layout-patterns.md`。

### Step 7: Visual QA

生成后必须进行视觉 QA，通过 pipeline 编排器执行。

```bash
node scripts/generate_pptx_pipeline.js <slide-ir.json> <output-dir>
```

Pipeline 内部自动完成：Static QA → Repair Plan → Build PPTX → Render QA → Pipeline Report。

检查项：是否有元素溢出页面、是否有文本被截断、是否有非预期重叠、表格是否可读、主图是否是视觉中心、页面是否过密、字号是否过小、箭头/层级/分组是否清楚、页面是否有明确 takeaway、CTO 是否能在 30 秒内理解主结论。

详细检查清单见 `references/visual-qa.md`、`references/qa-gates.md`。

### Step 8: Repair

如果 QA 失败，pipeline 自动生成 repair plan，LLM 根据 plan 调整 Slide IR 后重新运行 pipeline。修复轮次上限取决于当前模式：draft 模式最多 1 轮，production 模式最多 3 轮。

```bash
# 第 1 轮
node scripts/generate_pptx_pipeline.js slide-ir.json output/
# → 查看 output/repair-plan.json 中的 actions
# → LLM 根据 actions 调整 Slide IR → 生成 slide-ir-v2.json

# 第 2 轮
node scripts/generate_pptx_pipeline.js slide-ir-v2.json output-v2/
# ...
```

修复优先级：压缩文字 → 合并 bullet → 把表格改成 cards → 减少图中节点 → 调整布局比例 → 增加分组和留白 → 最后才考虑缩小字号 → 如果仍然过载，建议拆成两页（必须问用户，不自动拆）。

详细策略见 `references/repair-policy.md`、`references/auto-iteration.md`。

## 工程化生成框架

Page Contract 确认之后，进入可执行的生成管线。本 skill 作为一个小型 **Presentation Compiler**，将页面生成过程分为多个可验证的层：

```
Page Contract (确认)
→ Slide IR (结构化中间表示)
→ Layout Solver (布局求解)
→ Backend Compile (PPTX 写入)
→ Static QA + Render QA (质量门禁)
→ Auto Repair (≤ 3 轮自动修复)
→ Final Artifact
```

关键约束：

- **Slide IR 是中间层**：Page Contract 确认后，页面内容被结构化为 Slide IR（JSON Schema 定义在 `schemas/slide-ir.schema.json`），包含语义角色、布局约束和来源追溯（provenance）。Slide IR 不得引入 Page Contract 未确认的事实。
- **LLM 不直接写 PPTX 坐标**：所有坐标和布局决策必须从 Slide IR 推导，经过 Layout Solver。
- **QA 门禁分层**：Static QA（渲染前检查重叠、间距、字号）和 Render QA（渲染后检查裁剪、遮挡、视觉中心）。
- **自动迭代最多 3 轮**：每轮产出结构化 QA Report，第 3 轮仍失败时不强行交付，输出失败原因和拆页建议。
- **Backend 可选**：根据场景选择 `pptxgenjs-native`、`template-placeholder`、`svg-to-drawingml`、`html-to-pptx`，禁止默认整页截图式图片交付。
- **一页一确认不变**：Page Contract 仍需用户确认后才能进入 Slide IR 和生成流程，后续实现不得绕过。
- **Slide IR 校验**：生成后需通过 `scripts/validate_slide_ir.js` 校验必填字段、枚举值、region 引用和 provenance 一致性。

详细框架文档见：

- `references/executable-framework.md`：完整分层架构、各层职责、与底层 PPTX 工具的关系。
- `references/slide-ir.md`：Slide IR 概念设计，语义角色、约束、provenance。
- `references/backend-selection.md`：后端选择策略和决策树。
- `references/qa-gates.md`：QA 门禁层级、问题分级（hard_fail / warning / acceptable_intentional）。
- `references/auto-iteration.md`：自动迭代流程、pipeline 编排、3 轮终止条件。
- `references/repair-policy.md`：repair plan 数据结构、修复优先级、当前阶段边界。

## 环境与验证要求

本 skill 依赖底层 `pptx` skill 和它的 PPTX 渲染/转换脚本。进入 PPTX 生成前，必须确认：

- 底层 `pptx` skill 可访问（可选，当不使用 `pptxgenjs-native` 后端时）。
- Node 运行时可用。`pptxgenjs` 为可选依赖（未安装时 graceful skip）。
- LibreOffice/soffice 为 Render QA 可选依赖（未安装时输出 skip 状态 + 人工检查清单）。
- 能生成缩略图或至少完成 Static QA 文本/结构检查。

如果环境未就绪，先报告阻塞点和修复命令，不要继续生成低质量 PPT。

本 skill 的本地测试入口在 `scripts/test.sh`，Pipeline 编排入口在 `scripts/generate_pptx_pipeline.js`。

## Reference Files

- `references/interaction-protocol.md`：当需要判断交互流程、确认机制、是否应该追问时读取。
- `references/input-sufficiency.md`：当需要判断用户信息是否足够支撑当前页时读取。
- `references/page-contract.md`：当需要生成或修改 Page Contract 时读取。
- `references/layout-patterns.md`：当需要选择页面结构、图表组合、单页版式时读取。
- `references/visual-style.md`：当需要确定默认视觉规范、字号、颜色、密度、间距时读取。
- `references/visual-qa.md`：当 PPTX 生成后需要检查视觉问题时读取（包含 Static QA 与 Render QA 检查清单、渲染策略、fallback 行为）。
- `references/repair-policy.md`：当需要修复过密、重叠、溢出、不清楚的问题时读取（含 repair plan 数据结构、当前阶段边界）。
- `references/examples.md`：当需要参考输入输出示例时读取。
- `references/executable-framework.md`：当需要理解整体工程框架、分层架构、各层职责时读取。
- `references/slide-ir.md`：当需要构建或理解 Slide IR 中间表示时读取。
- `references/backend-selection.md`：当需要选择 PPTX 写入后端时读取。
- `references/qa-gates.md`：当需要执行 QA 门禁或判定问题分级时读取（含 Static QA、Render QA、Content QA 三层分级体系）。
- `references/auto-iteration.md`：当需要执行自动迭代修复流程时读取（含 pipeline 编排、3 轮终止条件、失败退出策略）。
- `references/workflow-modes.md`：当需要判断使用 draft 或 production 模式、理解两种模式的边界、升级流程时读取。

## 示例

参考 `references/examples.md` 中的架构页、对比矩阵页、路线图页示例。
