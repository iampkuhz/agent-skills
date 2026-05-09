# QA 门禁（QA Gates）

## 定位

QA 门禁是 Presentation Compiler 的质量保障层，在渲染前后分别检查页面质量。
所有 QA 结果必须结构化输出，能驱动 Auto Repair。

## QA 层级

### Static QA（渲染前）

在 Slide IR 和布局方案层面检查，无需渲染图片。

**实现位置**：`helpers/static-qa.js`（主引擎）、`helpers/geometry.js`（几何运算）、`helpers/semantic-rules.js`（语义规则）。
**CLI 入口**：`scripts/inspect_slide_ir_layout.js <slide-ir.json> [--json]`

**检查项**：

| # | 检查项 | 规则类型 | 默认严重性 | 说明 |
|---|--------|----------|-----------|------|
| 1 | 元素越界 | `out_of_bounds` / `out_of_region` | hard_fail | 元素超出 canvas safe bounds 或 region bounds |
| 2 | 连接线穿文本 | `connector_cross_text` | hard_fail | connector 与 text/note/footer_note 重叠（端点附近除外） |
| 3 | 连接线端点接近 | `connector_near_endpoint` | acceptable_intentional | connector 在 from/to 节点附近与文本接近 |
| 4 | 标记压节点 | `label_overlap_node` | hard_fail | step_marker 与 component_node 大面积重叠 |
| 5 | 标记接近节点 | `label_near_node` | warning | step_marker 与 component_node 小面积重叠（< 20%） |
| 6 | 脚注碰撞 | `footer_collision` | hard_fail | footer_note 与非 footer 元素碰撞 |
| 7 | 字号过低 | `low_font` | hard_fail | 正文 < 10pt，表格/标签 < 8.5pt |
| 8 | 间距过小 | `too_close` | warning | 非同 region 元素间距 < 0.1 inch |
| 9 | 容器包含 | `container_contains_text` | acceptable_intentional | 组件节点包含其标签文本 |
| 10 | 容器小重叠 | `container_small_overlap` | acceptable_intentional | 重叠面积 < 20% 的边缘装饰性重叠 |
| 11 | 容器意外重叠 | `container_overlap_text` | warning | 容器与非标签文本大面积重叠 |
| 12 | 文本溢出风险 | `text_may_overflow` | warning | 估算文本渲染高度超出区域可用高度 |
| 13 | 内容完整性 | `missing_title` / `missing_takeaway` | hard_fail / warning | 页面缺少必需元素 |

**语义碰撞规则详解**：

Static QA 不是简单的矩形碰撞检测，而是基于元素语义角色区分可接受和不可接受的重叠：

- **连接线穿文本**（`connector_cross_text`）：connector 与任何文本类元素（text、note、footer_note）重叠，默认 `hard_fail`。**修复：端点感知** — 如果重叠区域靠近连接器的 `from` 或 `to` 目标节点（在端点扩展容差范围内），则标记为 `acceptable_intentional`（`connector_near_endpoint`），因为连接器从节点发出时的自然重叠不是 bug。
- **标记压节点**（`label_overlap_node`）：step_marker 与 component_node 大面积重叠，默认 `hard_fail`。**修复：小重叠容忍** — 如果重叠面积 < 20% 的较小元素面积，降级为 `warning`（`label_near_node`），因为轻微的边缘重叠可能是有意的设计。
- **容器包含文本**（`container_contains_text`）：如果组件节点包含其自身的标签文本，标记为 `acceptable_intentional`。**修复：小重叠容忍** — 如果重叠面积 < 20% 的较小元素面积，标记为 `acceptable_intentional`（`container_small_overlap`），处理装饰性元素（如 badge 贴在节点角上）的误报。
- **脚注碰撞**（`footer_collision`）：footer_note 与非 footer 区域元素碰撞，默认 `hard_fail`。脚注必须在页面最底部，不能压住任何主体内容。
- **文本溢出风险**（`text_may_overflow`）：基于内容长度、字号和区域宽度，估算文本需要的渲染高度。如果估算高度 > 可用高度的 1.2 倍，发出 `warning`。这弥补了 Static QA 只能检测几何约束、无法发现文本实际渲染溢出的漏报问题。
- **字号过低**（`low_font`）：根据元素类型检查字号下限。title ≥ 18pt，正文 ≥ 10pt，表格/标签/注释 ≥ 8.5pt。step_marker 也使用 8.5pt 下限。
- **间距过小**（`too_close`）：非同一 region 内的元素间距小于 0.1 inch 时标记为 `warning`。同一 region 内的元素可以较近。connector 不参与间距检查。
- **越界**（`out_of_bounds` / `out_of_region`）：元素超出 canvas safe bounds 或 element 的 `must_stay_within_region=true` 但超出 region bounds。

### Render QA（渲染后）

在渲染为 PNG 后检查视觉级别的问题。

**实现位置**：`scripts/visual_qa_report.js`（报告生成）、`helpers/render/manifest.js`（PNG 解析）
**渲染入口**：`scripts/render_pptx.sh`（shell 渲染包装器）、`scripts/render_pptx.js`（manifest 生成）

**输入**：渲染后的 PNG 缩略图 + render manifest JSON（由 `render_pptx.sh` 产出）
**输出**：结构化 QA report（JSON 或可读文本）
**失败策略**：
- 渲染引擎不可用 → 输出 `status: "skip"` 报告，标注"无法进行完整视觉 QA"，提供人工检查清单。
  - **production 模式**：最终状态为 `incomplete`，不可视为通过。
  - **draft 模式**：最终状态为 `pass_with_skip`，但必须在报告中明确标注为不完整/草稿。
- 渲染产出异常（0 byte PNG、宽高比严重偏离） → `hard_fail`。
- 静态检查全部通过但仍有问题 → 交由人工 checklist 确认。

**自动检查项**：

| # | 检查项 | 严重性 | 说明 |
|---|--------|--------|------|
| 1 | 图片文件存在性 | hard_fail | slide 对应的 PNG 文件不存在 |
| 2 | 图片文件非空 | hard_fail | PNG 文件大小为 0 byte |
| 3 | 图片文件大小 | warning | PNG 文件 < 1KB，可能渲染不完整 |
| 4 | 宽高比例 | warning | 宽高比偏离 16:9 超过 10% |
| 5 | PNG 文件头有效性 | warning | 无法解析 PNG header，可能不是有效图片 |

**需人工/模型确认项**（manual checklist）：

| # | 检查项 | 说明 |
|---|--------|------|
| 1 | 裁剪检测 | 是否有元素被页面边缘裁剪 |
| 2 | 遮挡检测 | 是否有元素被其他元素遮挡 |
| 3 | 文字密度 | bullet / 表格文字是否过密 |
| 4 | 视觉中心 | 主视觉是否清晰可辨，是否被分散注意力 |
| 5 | 文本截断 | 是否有文字显示不全 |
| 6 | 颜色对比 | 文字和背景对比度是否足够 |
| 7 | 表格可读性 | 表格是否可读，行列是否清晰 |
| 8 | 脚注位置 | 脚注是否压住主体内容 |

> **注意**：Static QA 是 Render QA 的前置门禁，但不能替代渲染检查。Static QA 只能检测几何层面的问题，Render QA 能发现字体渲染差异、图片裁剪、实际渲染效果等 Static QA 无法覆盖的问题。
>
> **Render QA 是强制门禁**：只要环境中有渲染引擎就必须执行。如果无法渲染，必须报告"无法进行完整视觉 QA"，不允许只凭生成脚本成功就交付。详见 `references/visual-qa.md`。

### Content QA（贯穿全程）

检查内容层面的正确性。

**检查项**：

| # | 检查项 | 说明 |
|---|--------|------|
| 1 | Placeholder 残留 | 是否存在 xxxx、lorem、占位符文本 |
| 2 | 未提供的事实 | 是否包含用户未提供的信息 |
| 3 | 结论存在性 | 页面 takeaway 是否存在且与 Page Contract 一致 |
| 4 | Provenance 完整性 | 每个内容元素是否可追溯到用户原始输入 |

## 问题分级

| 级别 | 含义 | 处理 |
|------|------|------|
| `hard_fail` | 页面存在严重问题，不可交付 | 必须修复后才能交付 |
| `warning` | 页面存在问题但不阻塞交付 | 建议在 Repair 阶段修复 |
| `acceptable_intentional` | 已知问题但有意为之（如设计选择） | 可在 QA report 中标注后跳过 |

## Pipeline 最终状态

| 状态 | 含义 | 退出码 |
|------|------|--------|
| `pass` | Static QA、Layout Solver、Build、Render QA 均按目标模式完成并通过 | 0 |
| `fail` | 存在 hard_fail，无法交付 | 1 |
| `incomplete` | 产物生成成功，但质量门禁未完成（solver 未执行、Render QA skip 等），不可视为完整交付 | 2 |
| `needs_user_decision` | 需要人工决策（如拆页建议、内容过载） | 100 |

> **注意**：`pass_with_skip` 仅用于 draft 模式的 round 状态，不作为 production 最终状态。
> production 模式下 Render QA skip 应转为 `incomplete`。

### Hard Fail 判定标准

出现以下任一情况判定为 `hard_fail`：

- 任意文本、图形、表格、卡片发生非预期重叠。
- 表格、卡片或脚注超出页面边界。
- 文本被截断、行高不足、字符挤压或内容被遮挡。
- 脚注压在主体内容上。
- 字号低于硬规则下限（正文 < 10pt / 表格 < 8.5pt）。
- 页面上有两个以上同等视觉中心。
- 页面上半部分拥挤、下半部分大面积空白。
- 存在 placeholder 残留。
- 包含用户未提供的编造事实。
- **PPTX XML 结构错误**：同一 slide 内重复 `cNvPr id`（触发 PowerPoint repair）。
- **PPTX fallback 坐标聚集**：多个元素同时落在默认 `(0,0,2,0.5)` 坐标（缺失 layout 的文本堆叠在左上角）。

### Warning 判定标准

- 元素间距偏小但仍有可读性。
- 颜色对比度偏低但不影响辨识。
- 表格行数接近上限但未超过。
- **表格 geometry 风险**：table frame 高度小于行高总和（可能触发 PowerPoint repair，但尚未确认）。

### Acceptable Intentional 判定标准

- 组件节点包含其自身的标签文本（容器包含）。
- 约束中显式声明 `allow_intentional_containment=true`。
- 用户明确要求的设计选择（如特殊配色）。
- 需要在 QA report 中显式说明原因。

## 误报处理原则

Static QA 基于几何规则，以下误报场景已通过规则优化处理：

### 已修复

1. **连接器端点假阳性**（`connector_cross_text`）：通过 `from`/`to` 端点感知，连接器在目标节点附近的重叠标记为 `connector_near_endpoint`（acceptable_intentional）。容差为 0.15 inch。
2. **装饰性小重叠**（`container_overlap_text` / `label_overlap_node`）：重叠面积 < 20% 的较小元素面积时，标记为 `container_small_overlap` 或 `label_near_node`（acceptable_intentional / warning），不再误报 badge 贴角等装饰性重叠。
3. **文本溢出漏报**（新增 `text_may_overflow`）：基于内容长度、字号和区域宽度估算渲染高度，超出可用高度 1.2 倍时发出 warning。

### 仍需 Render QA 发现

4. **多行文本的实际渲染高度**：`text_may_overflow` 是启发式估算，可能因换行策略、字体渲染差异等产生误差。最终仍需 Render QA 确认。
5. **连接线的精确路径**：connector 的 layout bounds 是外包矩形，即使端点感知过滤后，中间段仍可能因外包矩形产生假阳性。如需更精确检测，需要引入路径级别的几何计算。

## QA 报告格式

```json
{
  "status": "pass",
  "summary": {
    "hard_fail": 0,
    "warning": 2,
    "acceptable_intentional": 4
  },
  "issues": [
    {
      "severity": "hard_fail",
      "type": "connector_cross_text",
      "element_ids": ["elem_conn_1", "elem_label"],
      "message": "连接线 \"elem_conn_1\" 与文本 \"elem_label\" 发生重叠",
      "metrics": { "overlap_area": 0.15, "bounds_a": {...}, "bounds_b": {...} },
      "suggestion": "调整连接线路径，使其不穿过文本区域"
    }
  ]
}
```

## 与已有 QA 文件的关系

- 本文档定义 QA 门禁的结构化框架和分级体系。
- `references/visual-qa.md` 保留详细的视觉检查清单和失败样例，作为 Render QA 的细化参考。
- 两者互补，不冲突。

## 第二阶段 Release Gate

QA 门禁是 Release Gate 的核心组成部分。完整 Release Gate 包括：

1. Runtime 能力诊断（doctor.js）。
2. 基础测试通过（test.sh）。
3. Benchmark dry-run 无 hard_fail。
4. PPTX build 成功（如果 pptxgenjs 可用）。
5. Render QA 通过（如果渲染引擎可用）。
6. 质量评分 >= 85（QUALITY_RUBRIC.md）。
7. PPTX post-check 通过。
8. 无 placeholder/lorem/xxxx 残留。
9. 无绝对路径泄漏。

详见 `scripts/release_gate.sh` 和 `references/release-gate.md`。

## 双模式门禁（Draft Gate / Production Gate）

本 skill 提供两种工作流模式，各自对应不同的 QA 门禁严格度。完整模式定义见 `references/workflow-modes.md`。

### Draft Gate

适用于快速样例/草稿模式。目标是在保证基本质量的前提下快速出图。

**必过检查项**：

| # | 检查项 | 严重性 | 说明 |
|---|--------|--------|------|
| 1 | 有标题 | hard_fail | 页面必须有 title 元素 |
| 2 | 有结论/takeaway | hard_fail | 必须有 takeaway 或一句话结论 |
| 3 | 无明显越界 | hard_fail | 元素不得大幅超出 canvas safe bounds |
| 4 | 无硬重叠 | hard_fail | 不得有 hard overlap（两个元素大面积互相覆盖） |
| 5 | 无 placeholder | hard_fail | 不得残留 xxxx、lorem 等占位符 |
| 6 | 有来源追溯 | hard_fail | 必须有 source provenance，每个内容元素可追溯到原始输入 |
| 7 | 内容不过载 | warning | 内容明显过载时输出拆页建议或 production 提示 |

**允许**：

- Draft Gate 允许 warning 存在（如间距偏小、颜色对比度偏低）。
- 不强制要求 layout solver / capacity check 通过。
- Render QA 可 skip，但最终报告必须标注为草稿或不完整。
- 不强制 PPTX postcheck 全部通过（仅检查 placeholder 和路径泄漏）。

**禁止**：

- 即使是 draft，也不允许事实编造、来源缺失、明显重叠、无结论。
- draft 的 PPTX 不得直接当 production 交付。

### Production Gate

适用于正式交付模式。必须走完完整管线。

**必过检查项**：

| # | 检查项 | 严重性 | 说明 |
|---|--------|--------|------|
| 1 | 完整 Page Contract | hard_fail | 必须经过用户确认 |
| 2 | 完整 Slide IR | hard_fail | 必须通过 validate_slide_ir.js |
| 3 | Static QA 无 hard_fail | hard_fail | inspect_slide_ir_layout.js 无 hard_fail |
| 3.5 | Layout Solver 执行 | hard_fail | production 模式必须在 Build 前尝试执行布局求解 |
| 4 | PPTX postcheck 通过 | hard_fail | inspect_pptx_artifact.js 通过 |
| 5 | Render QA 可用时通过 | hard_fail | 渲染引擎可用时必须执行并通过；不可用时最终状态为 `incomplete` |
| 6 | Design system 无漂移 | hard_fail | validate_design_system.js 通过 |
| 7 | Release gate 可验证 | hard_fail | release_gate.sh 通过 |

**不允许**：

- 任何 hard_fail 存在时不得交付。
- 不得跳过 Page Contract。
- 不得跳过 Layout Solver（production 模式）。
- 不得跳过自动修复阶段（最多 3 轮）。
- Render QA 不可用时，不得报告 `pass`，应报告 `incomplete`。
- 不得用整页截图作为默认交付。

### 两种门禁的差异

| 维度 | Draft Gate | Production Gate |
|------|-----------|----------------|
| 页面合同 | 简化 Draft Contract | 完整 Page Contract 确认 |
| Static QA | 仅检查 7 项必过项 | 全部 Static QA 检查项 |
| Layout Solver | 简化预算 | 完整求解 + 容量检查 |
| 自动修复 | 最多 1 轮 | 最多 3 轮 |
| Render QA | 可 skip（最终状态 `pass_with_skip`） | 必须执行（不可用时状态 `incomplete`） |
| PPTX postcheck | 仅核心项 | 全部检查 |
| 输出标记 | "DRAFT" 标记 | 无标记 |
| 交付状态 | 不可交付，仅讨论 | 可交付、可发布 |

