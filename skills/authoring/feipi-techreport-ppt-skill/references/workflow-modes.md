# 工作流模式（Workflow Modes）

## 定位

本 skill 提供两套统一维护的 PPT 生成流程，通过 `draft` 和 `production` 两种模式切换。它们共享同一套 design system、Slide IR schema、layout pattern、component registry、QA 分级和 benchmark 体系，只是在确认程度、布局复杂度、QA 严格度、输出声明上不同。

**不要再发明第三套主流程。** 后续如需更细粒度，只能作为 mode option。

## 模式配置

配置真源位于 `config/workflow-modes.json`。两种模式的差异全部通过此配置表达，不散落在多个脚本里。

## 模式对照表

| 维度 | draft（快速样例/草稿模式） | production（生产版本/正式模式） |
|------|---------------------------|-------------------------------|
| 目标 | 快速看方向，讨论内容和版式 | 正式可交付，可编辑可发布 |
| 用户确认 | 简化确认 / 可先出样 | 标准 Page Contract 确认 |
| 版式复杂度 | 低到中 | 中到高 |
| 组件范围 | 简化组件子集 | 完整组件全集 |
| 布局求解 | 简化预算，不强制 capacity check | 完整 layout solver + capacity check |
| QA 门禁 | draft gate：避免明显重叠、越界、空白、无结论；允许部分 warning | production gate：Static QA 无 hard_fail，PPTX postcheck 通过，Render QA 可用时通过 |
| 自动修复 | 最多 1 轮 | 最多 3 轮 |
| 输出标记 | 明确标 "DRAFT" 草稿 | 无标记，正式交付 |
| 来源追溯 | 必须保留，不得跳过 | 必须保留，不得跳过 |
| 事实边界 | 不得编造，不得引入未提供事实 | 不得编造，不得引入未提供事实 |

## Draft 模式

### 定义

`draft` 是快速出图模式，用于快速产出一版可看的样例。不追求复杂堆叠和完整生产质量，重点是让用户快速看到内容方向、页面结构、视觉大概样子。

### 适用场景

- 用户想先看大概效果。
- 内容还没完全定稿。
- 版式还需要讨论。
- 样例文件/风格还在迭代。
- 用户说"先出个样例""先看看效果""快速出图""草稿""不用太精细"。

### 输入要求

- 主题和结论必须提供。
- 原始事实可以不完全稳定，但必须有核心信息。
- 风格 profile 可使用默认值，不需要用户确认。

### 确认策略

- 可以不生成标准 Page Contract，先生成简化版 `Draft Contract`（包含主题、结论、内容范围）。
- 少问确认，直接出一个可讨论的版本。
- 用户确认前，输出必须标记为草稿。

### 允许的布局复杂度

- 布局复杂度上限为 `low_to_medium`。
- 优先使用低复杂度组件：标题、主图轮廓、KPI 卡、短表、说明框、简单流程。
- 不做复杂嵌套、复杂连接线、复杂多层架构。
- 单页元素数量应控制在视觉可读范围内，过载时建议拆页而非硬塞。

### QA 门禁（Draft Gate）

Draft Gate 检查以下必过项：

| # | 检查项 | 说明 |
|---|--------|------|
| 1 | 有标题 | 页面必须有 title 元素 |
| 2 | 有结论 | 必须有 takeaway / 一句话结论 |
| 3 | 无明显越界 | 元素不得大幅超出 canvas safe bounds |
| 4 | 无硬重叠 | 不得有 hard overlap（两个元素大面积互相覆盖） |
| 5 | 无 placeholder | 不得残留 xxxx、lorem 等占位符 |
| 6 | 有来源追溯 | 必须有 source provenance |
| 7 | 内容不过载 | 内容明显过载时输出拆页建议或 production 提示 |

Draft Gate 允许 warning 存在，但不允许 hard_fail。

### 禁止

- 不得加入用户未提供的事实。
- 不得因为是 draft 就跳过来源追溯。
- 不得把 draft 输出描述成最终版。
- 不得把复杂信息硬塞进一页。
- 不得使用 production 级别的复杂组件（如多层架构节点组、复杂决策树）。

## Production 模式

### 定义

`production` 是生产版本模式，用于内容范围、版式、风格确认后的正式生成。必须走完整管线。

### 适用场景

- 用户确认内容范围。
- 版式方向已确定。
- 风格 profile / style lock 已确定。
- 需要正式交付 PPTX。
- 用户说"正式版""生产版""最终交付""可发布""按确认版生成"。

### 输入要求

- 主题、结论、原始事实、关系四类信息必须完整。
- 风格 profile 或 style lock 必须明确。
- 版面蓝图必须确认。

### 确认策略

- 必须生成标准 Page Contract 并等待用户确认。
- 必须生成完整 Slide IR。
- 用户确认前不得进入 PPTX 编译。

### 允许的布局复杂度

- 布局复杂度为 `full`，无上限约束。
- 可使用完整组件全集。
- 必须走 layout solver / capacity check。

### QA 门禁（Production Gate）

Production Gate 检查以下必过项：

| # | 检查项 | 说明 |
|---|--------|------|
| 1 | 完整 Page Contract | 必须经过用户确认 |
| 2 | 完整 Slide IR | 必须通过 validate_slide_ir.js |
| 3 | Static QA 无 hard_fail | inspect_slide_ir_layout.js 无 hard_fail |
| 4 | PPTX postcheck 通过 | inspect_pptx_artifact.js 通过 |
| 5 | Render QA 可用时通过 | 渲染引擎可用时必须执行并通过 |
| 6 | style lock / design system 无漂移 | validate_design_system.js 通过 |
| 7 | benchmark / release gate 可验证 | release_gate.sh 通过 |

Production Gate 不允许任何 hard_fail。

### 禁止

- 不得跳过 Page Contract。
- 不得用整页截图作为默认交付。
- 不得在 hard_fail 存在时交付。
- 不得跳过自动修复阶段。

## 两种模式共享资产

以下资产在两种模式间**完全共享**，不得复制分裂：

| 共享模块 | 路径 | 说明 |
|----------|------|------|
| Design System tokens | `design-system/tokens/` | 颜色、字体、圆角、间距 |
| Design System components | `design-system/components/` | 全部组件定义 |
| Design System patterns | `design-system/patterns/` | 复杂组合规则 |
| Design System profiles | `design-system/profiles/` | 场景风格组合 |
| Style locks | `templates/style-locks/` | 下游发布配置 |
| Slide IR schema | `schemas/slide-ir.schema.json` | 结构定义 |
| Layout patterns | `references/layout-patterns.md` | 版式规则 |
| QA gates | `references/qa-gates.md` | QA 分级体系 |
| Benchmark fixtures | `fixtures/benchmarks/` | 质量基准 |
| Helpers | `helpers/` | IR、layout、pptx、static-qa 等 |
| Pipeline scripts | `scripts/` | 管线脚本入口 |

draft 模式只使用 production 组件的低复杂度变体，而不是复制一套 draft 专属组件。

## 模式差异配置

两种模式的差异仅体现在以下维度：

| 差异维度 | draft | production |
|----------|-------|------------|
| `requires_page_contract_confirmation` | false | true |
| `requires_source_provenance` | true | true |
| `max_repair_rounds` | 1 | 3 |
| `qa_gate` | "draft" | "production" |
| `layout_complexity` | "low_to_medium" | "full" |
| `allowed_components` | 子集 | "*"（全集） |
| `output_badge` | "DRAFT" | null |
| `release_gate_strictness` | "relaxed" | "strict" |

## Draft → Production 升级流程

从 draft 升级到 production 必须经过以下步骤：

1. **用户确认内容范围**：draft 阶段讨论的内容范围需要正式确认。
2. **用户确认主版式**：draft 阶段的版式方向需要正式确认。
3. **用户确认风格 profile**：确认是否保留 draft 使用的风格 profile，或更换/锁定 style lock。
4. **内容过载处理**：如果 draft 暴露内容过载，先拆页或降维，确保生产版内容在容量范围内。
5. **生成标准 Page Contract**：从 draft 的简化 contract 升级为完整 Page Contract，等待用户确认。
6. **生成 production Slide IR**：从 draft 的简化 IR 升级为完整 Slide IR，包含完整 provenance、region、constraints。
7. **运行 production pipeline**：执行完整管线（Static QA → PPTX Build → Render QA → Repair → Release Gate）。

**重要：draft 的 PPTX 不能直接当 production 交付。** draft 输出只能作为输入参考，production 必须重新生成完整的 Slide IR 和 PPTX。

### 升级触发条件

当用户在 draft 阶段后表达以下意图时，触发升级流程：

- "这个方向可以，出正式版"
- "按这个生成生产版"
- "确认内容，正式发布"
- "定稿，需要可交付的 PPTX"

## 用户如何触发模式

### 触发 Draft

用户说出以下关键词时进入 draft 模式：

- "先出个样例"
- "先看看效果"
- "快速出图"
- "草稿"
- "不用太精细"
- "随便出一个版本"
- "看看大概样子"

### 触发 Production

用户说出以下关键词时进入 production 模式：

- "正式版"
- "生产版"
- "最终交付"
- "可发布"
- "按确认版生成"
- "定稿"

### 默认行为

- 用户没有明确说 draft 时，保持当前标准 Page Contract 优先流程（等价于 production）。
- 当用户意图不明确时，可询问："需要快速出一个草稿看看效果，还是直接走正式版？"

## 配置真源

模式配置存储在：

```
config/workflow-modes.json
```

脚本可通过读取此文件获取模式参数，确保配置集中管理。

校验脚本：

```bash
node scripts/validate_workflow_modes.js
```
