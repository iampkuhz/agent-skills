# Design System

本目录是 `feipi-techreport-ppt-skill` 的模块化设计系统真源，用于长期维护 PPT 的颜色、字体、圆角、文本框、原生表格和原生组件图等样式模块。

它和 `templates/style-locks/` 的关系：

- `design-system/`：维护可组合的设计原子、组件和模式，是上游真源。
- `templates/style-locks/`：维护某个场景下的最终风格锁，是下游发布配置。
- `helpers/pptx/`：消费 style lock 或 design system 解析后的 token，生成 PPTX。

## 层级

```text
design-system/
├── tokens/                 # 原子模块：颜色、字体、圆角、间距
├── component-inventory.json # 组件全集和分层清单
├── components/             # 基础组件：文本、容器、数据、图解、媒体
├── patterns/               # 复杂模块：架构图、流程图、对比矩阵等组合规则
├── profiles/               # 场景 profile：把 tokens/components/patterns 组合成可用风格
└── samples/                # 用户提供的参考样例落点，只作提取来源，不作运行时真源
```

## 维护原则

1. 先维护原子 token，再维护组件，再维护复杂图形模式。
2. 不在 builder 中硬编码颜色、字号、圆角和表格样式。
3. 新增组件时必须声明依赖哪些 token。
4. 用户提供样例 PPTX / 图片时，先放入 `samples/`，再提取成 token 和组件配置。
5. `style-locks/` 可以由 design system profile 派生，但不要反向把临时样式散落到 builder。

## 推荐变更流程

1. 把样例文件放到 `design-system/samples/`。
2. 提取颜色、字体、圆角、线条、表格、节点、连接线等设计特征。
3. 更新 `tokens/*.json`。
4. 更新 `components/*.json`。
5. 如有复杂组合规则，更新 `patterns/README.md`。
6. 更新 `profiles/*.json`，明确本 profile 使用哪些模块。
7. 运行：

```bash
node scripts/validate_design_system.js
```

8. 再更新 `templates/style-locks/*.json` 或 builder 消费逻辑。

## 当前模块全集

| 模块 | 文件 | 说明 |
|------|------|------|
| 颜色集合 | `tokens/colors.core.json` | 基础色、语义色、浅色背景、数据色 |
| 字体风格 | `tokens/typography.core.json` | 字体 fallback、字号、字重、行距 |
| 形状圆角 | `tokens/shape.core.json` | 圆角矩形、卡片、节点、胶囊、徽标 |
| 间距网格 | `tokens/spacing.core.json` | 页面边距、区块间距、表格 padding |
| 组件清单 | `component-inventory.json` | PPT 组件全集和分层覆盖关系 |
| 文本层级 | `components/text-hierarchy.json` | 标题、副标题、正文、脚注、来源 |
| 圆角文本框 | `components/rounded-text-box.json` | 标题框、正文框、提示框、风险框 |
| 代码块 | `components/code-block.json` | 配置、伪代码、命令、日志片段 |
| 来源脚注 | `components/source-note.json` | 数据来源、口径说明、页脚 |
| 版面区域 | `components/layout-region.json` | header、main、side、footer 容器 |
| 分隔线 | `components/section-divider.json` | 区块分隔、标题线、脚注线 |
| 标签徽标 | `components/badge-and-label.json` | 状态、阶段、风险、版本标签 |
| 图例 | `components/legend.json` | 颜色、线型、状态解释 |
| KPI 卡片 | `components/kpi-card.json` | 关键指标、目标差距、状态摘要 |
| 原生表格 | `components/native-table.json` | PPTX 原生 table 的 header、body、边框、密度 |
| 热力矩阵 | `components/heatmap-matrix.json` | 风险/能力/方案三档热度 |
| 原生图表 | `components/native-chart.json` | 柱状、折线、环图、sparkline |
| 进度指标 | `components/progress-indicator.json` | 进度条、阶段进度、资源占用 |
| 原生组件图 | `components/native-component-diagram.json` | 架构节点、分组框、连接线、端口、徽标 |
| 流程步骤 | `components/flow-step.json` | 流程节点、步骤编号、连接线 |
| 时间线里程碑 | `components/timeline-milestone.json` | 阶段、版本、交付路线 |
| 决策节点 | `components/decision-node.json` | 判断树、分支条件、推荐路径 |
| 能力分组 | `components/capability-group.json` | 能力域、模块分区、优先级 |
| 媒体框 | `components/media-frame.json` | 截图、图片、logo、引用图 |
| 默认 profile | `profiles/cto-technical-report.design-profile.json` | CTO 技术汇报默认组合 |

更完整的分类说明见 `components/README.md`。

## 与双流程模式的关系

本 skill 提供 `draft`（快速样例）和 `production`（生产版本）两种工作流模式。两种模式**共享同一套设计系统**，不得复制分裂：

- `design-system/tokens/`、`components/`、`patterns/`、`profiles/` 是两种模式的共同真源。
- draft 模式只使用 production 组件的低复杂度变体（如标题、KPI 卡、短表、简单流程），而不是复制一套 draft 专属组件。
- 风格 profile 的差异通过 `config/workflow-modes.json` 中的 `allowed_components` 字段控制，不通过复制组件实现。
- 如果未来用户提供样例，样例只影响 design system/profile/style lock，不直接分裂 workflow。

模式配置详见 `../config/workflow-modes.json`，模式规则详见 `references/workflow-modes.md`。
