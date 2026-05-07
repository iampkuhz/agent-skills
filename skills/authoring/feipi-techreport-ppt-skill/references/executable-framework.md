# 可执行框架（Executable Framework）

## 定位

本 skill 是 **Presentation Compiler 的 authoring + orchestration + QA 层**，不是直接操作 PPTX 文件格式的 backend。
具体 PPTX 写入、shape 创建、模板处理由 backend 工具实现（当前默认底层 `pptx` skill）。

## 分层架构

```
Raw Input
→ [1] Input Sufficiency Check
→ [2] Page Contract
→ [3] Slide IR
→ [4] Layout Solver / Builder
→ [5] Backend Compile
→ [6] Static QA
→ [7] Render QA
→ [8] Auto Repair (≤ 3 rounds)
→ Final Artifact
```

## 各层职责

### Layer 1: Input Sufficiency Check

- **输入**：用户提供的原始材料（文本、数据、描述、已有 PPTX）。
- **输出**：信息充足 / 信息不足 + 缺失项列表。
- **失败处理**：信息不足时拒绝进入后续层，要求用户补充。
- **规则文件**：`references/input-sufficiency.md`

### Layer 2: Page Contract

- **输入**：充足的用户原始信息。
- **输出**：Page Contract（目标、结论、使用信息、内容范围、推荐结构、版面蓝图）。
- **失败处理**：内容过载时建议拆页或降维，不擅自压缩。
- **规则文件**：`references/page-contract.md`

### Layer 3: Slide IR（中间表示）

- **输入**：确认后的 Page Contract。
- **输出**：结构化的 Slide IR JSON，包含语义角色、layout constraints、provenance。
- **失败处理**：无法构建合法 IR 时回退到 Page Contract 调整。
- **规则文件**：`references/slide-ir.md`

> **关键约束**：Slide IR 是页面布局的稳定中间层。LLM 不得直接无约束写 PPTX 坐标；所有坐标和布局决策必须从 Slide IR 推导。

### Layer 4: Layout Solver / Builder

- **输入**：Slide IR。
- **输出**：带有具体坐标、尺寸、字号的布局方案。
- **职责**：
  - 根据版面模式（architecture-map、comparison-matrix 等）计算区域分配。
  - 应用最小字号、页面边距、不可重叠等约束。
  - 输出带坐标的布局方案，供 backend 使用。
- **失败处理**：约束无法同时满足时标记为 static_qa hard_fail，进入 repair。
- **规则文件**：`references/layout-patterns.md`

### Layer 5: Backend Compile

- **输入**：带坐标的布局方案。
- **输出**：`.pptx` 文件。
- **职责**：将布局方案翻译为具体 PPTX 操作（shape、text、table、chart）。
- **后端选择**：根据场景选择 `pptxgenjs-native`、`template-placeholder`、`svg-to-drawingml`、`html-to-pptx`。
- **失败处理**：backend 不可用时报告阻塞点，不降级为低质量输出。
- **规则文件**：`references/backend-selection.md`

### Layer 6: Static QA

- **输入**：Slide IR + 布局方案（渲染前）。
- **输出**：结构化 QA report（通过项、hard_fail、warning）。
- **职责**：
  - 检查元素边界、重叠、间距、字号、语义碰撞。
  - 在渲染前发现可静态推断的问题。
- **规则文件**：`references/qa-gates.md`

### Layer 7: Render QA

- **输入**：渲染后的 PNG 缩略图或截图（由 PPTX 渲染引擎产出）。
- **输出**：结构化 QA report（JSON）+ 人工检查清单。
- **职责**：
  - 通过 LibreOffice/soffice headless 将 PPTX 渲染为 PNG。
  - 解析 PNG 文件头获取实际宽高。
  - 生成 render manifest（记录每张 slide 的 PNG 路径、尺寸、文件大小）。
  - 执行自动检查：图片存在性、非空、宽高比例、文件大小异常。
  - 生成人工/模型检查 checklist（裁剪、遮挡、密度、视觉中心等）。
  - 如果渲染引擎不可用，报告"无法进行完整视觉 QA"，提供人工检查清单。
- **失败处理**：
  - 渲染引擎缺失 → exit 100（跳过状态，非失败），输出 skip manifest。
  - 渲染产出异常 → hard_fail 标记。
- **规则文件**：`references/qa-gates.md`、`references/visual-qa.md`
- **工程入口**：
  - `scripts/render_pptx.sh` — 渲染包装器
  - `scripts/render_pptx.js` — manifest 生成
  - `scripts/visual_qa_report.js` — QA 报告生成
  - `helpers/render/manifest.js` — PNG 解析 + manifest 工具

### Layer 8: Auto Repair

- **输入**：QA report（static + render）。
- **输出**：修复后的 Slide IR → 重新编译 → 重新 QA，最多 3 轮。
- **职责**：
  - 按修复优先级尝试：信息压缩 → 布局重排 → 最后才调整字号。
  - 第 3 轮仍失败时输出失败原因和建议拆页方案。
- **规则文件**：`references/auto-iteration.md`、`references/repair-policy.md`

## 与底层 PPTX 工具的关系

| 层 | 本 skill 职责 | 底层工具职责 |
|----|-------------|-------------|
| Authoring（1-3） | 信息检查、Page Contract、Slide IR | 不参与 |
| Layout（4） | 约束求解、区域分配 | 不参与 |
| Compile（5） | 生成布局方案 | PPTX 写入、shape/text/table 创建 |
| QA（6-7） | 静态 + 渲染检查 | 提供渲染/缩略图/文本提取能力 |
| Repair（8） | 修复策略、迭代控制 | 执行修复后的 PPTX 重写 |

## 运行时环境

本 skill 的运行时分为两级，详见 `references/runtime-environment.md`：

- **最小环境**：仅需 Node.js，可运行 IR 校验、Static QA 和 Pipeline dry-run。
- **完整环境**：额外需要 `pptxgenjs` 和 LibreOffice，可运行全部 Pipeline 阶段。

环境探测入口：
```bash
node scripts/doctor.js          # 人类可读诊断
node scripts/doctor.js --json   # JSON 格式（CI 消费）
node scripts/runtime_capabilities.js  # 纯 JSON 能力探测
```

## 安全约束

1. **禁止 LLM 直接写 PPTX 坐标**：必须先经过 Page Contract → Slide IR → Layout Solver。
2. **禁止无约束的事实编造**：Slide IR 的每个元素必须有 provenance 追溯。
3. **禁止跳过 QA 直接交付**：即使渲染不可用，也必须完成 static QA。
4. **一页一确认**：用户确认 Page Contract 后才能进入生成流程。

## 后续增强方向

- Slide IR schema 形式化（JSON Schema / Pydantic）。
- Layout Solver 从 LLM 推理迁移为约束求解器。
- Render QA 引入自动化视觉检测模型。
- Auto Repair 支持差异化的修复动作集。
