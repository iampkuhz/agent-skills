# Slide IR（中间表示）

## 概念设计

Slide IR（Slide Intermediate Representation）是页面布局的**稳定中间表示层**。
它位于 Page Contract 之后、Layout Solver 之前，是页面内容的结构化、可验证、可推导的表示形式。

### 为什么需要 Slide IR

- Page Contract 是面向用户的确认协议，不是机器可执行的结构。
- 直接让 LLM 写 PPTX 坐标会导致不可控的重叠、溢出、不一致。
- Slide IR 保留语义角色和约束，使 Layout Solver 可以独立求解坐标。
- IR 是 QA 和 Repair 的统一输入源，支持多轮迭代而不丢失原始意图。

### 与 Page Contract 的映射

Page Contract 确认后，以下字段自动映射到 Slide IR：

| Page Contract 字段 | Slide IR 字段 | 说明 |
|-------------------|---------------|------|
| 本页目标 | `canvas` + `layout_pattern` | 目标决定版式选择 |
| 一句话结论 | `takeaway` | 直接映射 |
| 使用的原始信息 | `source_summary` + `provenance` | 每条原始信息生成 source_item 和 provenance 条目 |
| 页面内容范围 | `elements` + `regions` | "包含" → 生成元素，"不包含" → 不生成 |
| 推荐页面结构 | `layout_pattern` + `regions` | 版式决定区域划分 |
| 版面蓝图 | `regions[].bounds` + `elements[].layout` | 蓝图中的空间比例转为区域坐标 |

**核心约束**：Slide IR 不得引入 Page Contract 未确认的事实。所有 `elements` 的 `source_refs` 必须能追溯到 `source_summary` 中的原始信息。

## 核心设计原则

### 1. Schema 结构

Slide IR 的完整 JSON Schema 定义在 `schemas/slide-ir.schema.json` 中。以下是顶层字段摘要：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `version` | string | 是 | Schema 版本，当前为 `"v1"` |
| `slide_id` | string | 是 | 页面唯一标识符 |
| `language` | string | 是 | 页面语言，默认 `"zh-CN"` |
| `audience` | string | 是 | 目标受众 |
| `canvas` | object | 是 | 画布尺寸和边距 |
| `layout_pattern` | enum | 是 | 8 类版式之一 |
| `source_summary` | array | 是 | 原始材料摘要 |
| `takeaway` | string | 是 | 一句话结论 |
| `regions` | array | 是 | 页面区域划分 |
| `elements` | array | 是 | 页面元素列表 |
| `constraints` | object | 是 | 全局约束 |
| `provenance` | array | 是 | 来源追溯 |
| `backend_hints` | object | 否 | 后端编译提示 |

### 2. 语义角色

每个页面元素必须有明确的语义角色，而不是"一个文本框在某个位置"。

**元素类型（kind）**：

| 类型 | 说明 |
|------|------|
| `text` | 普通文本 |
| `component_node` | 架构图中的组件节点 |
| `connector` | 连接线、箭头 |
| `step_marker` | 步骤标记、序号 |
| `table` | 表格 |
| `matrix` | 矩阵/对比表 |
| `kpi_card` | 关键指标卡 |
| `note` | 注释/说明 |
| `legend` | 图例 |
| `footer_note` | 脚注 |

**语义角色（semantic_role）**：

| 角色 | 说明 |
|------|------|
| `title` | 页面标题 |
| `subtitle` | 副标题 |
| `takeaway` | 一行结论 |
| `system_component` | 系统组件 |
| `process_step` | 流程步骤 |
| `data_flow` | 数据流/连接关系 |
| `explanation` | 说明文字 |
| `risk` | 风险提示 |
| `evidence` | 证据/数据 |
| `source_note` | 来源说明 |

**区域角色（region role）**：

| 角色 | 说明 |
|------|------|
| `header` | 标题区 |
| `primary_visual` | 主视觉区 |
| `side_panel` | 侧栏说明 |
| `evidence_zone` | 证据区 |
| `takeaway_bar` | 结论栏 |
| `footer` | 脚注区 |
| `kpi_row` | KPI 卡片行 |
| `insight_panel` | 洞察面板 |

### 3. Layout Constraints

页面级别约束：

```json
{
  "constraints": {
    "min_font_pt": { "title": 18, "body": 10, "footnote": 8.5, "table_cell": 8.5 },
    "no_overlap": true,
    "max_table_rows": 5,
    "max_table_cols": 4
  }
}
```

元素级别约束（在 `element.constraints` 中）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `min_font_pt` | number | 该元素最小字号 |
| `max_lines` | integer | 最大行数 |
| `no_overlap_with` | string[] | 不可重叠的元素 ID |
| `must_stay_within_region` | boolean | 是否必须停留在所属区域 |
| `allow_intentional_containment` | boolean | 是否允许有意包含 |
| `priority` | enum | 约束优先级：critical / high / medium / low |

### 4. Provenance（来源追溯）

每个元素必须记录来自哪些用户原始信息，防止编造事实：

```json
{
  "provenance": [
    {
      "source_id": "src_1",
      "source_type": "user_input",
      "quote_or_summary": "共识层采用 PBFT 变种，128 节点...",
      "used_by_elements": ["elem_node_propose", "elem_node_prevote", "elem_node_commit"]
    }
  ]
}
```

Provenance 类型（source_type）：
- `user_input`：直接来自用户提供的文本。
- `derived`：从用户输入推导（如压缩、合并），需保留原始引用。
- `layout_only`：纯布局元素（分隔线、背景框），无事实内容。

**校验规则**：每个 element 的 `source_refs` 中的 ID 必须在 `source_summary` 和 `provenance` 中存在。

## 与后续层的关系

```
Page Contract (确认)
    ↓
Slide IR (结构化中间表示)
    ↓
Layout Solver (求解坐标)
    ↓
Backend (写入 PPTX)
    ↓
QA (验证 IR 约束是否满足)
    ↓
Repair (修改 IR → 重新求解)
```

- QA 层验证 Slide IR 的约束是否在最终 PPTX 中得到满足。
- Repair 层修改 Slide IR 而非直接修改 PPTX，保证每次迭代都有一致的输入源。

## 校验与示例

- Schema 定义：`schemas/slide-ir.schema.json`
- 校验脚本：`scripts/validate_slide_ir.js`
- 示例 fixture：
  - `fixtures/architecture-map.slide-ir.json` — 架构图示例
  - `fixtures/comparison-matrix.slide-ir.json` — 对比矩阵示例
  - `fixtures/flow-diagram.slide-ir.json` — 流程图示例

## 当前状态

Slide IR schema 已形式化为 JSON Schema（Draft 2020-12）。
校验脚本 `validate_slide_ir.js` 提供轻量校验（不依赖外部 npm 包）。
后续可增强为完整的 JSON Schema 校验器。
