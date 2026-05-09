# 模块化设计系统

## 定位

`design-system/` 是本 skill 的模块化设计真源，用于维护可复用、可替换、可验证的 PPT 视觉模块。它解决的问题是：不要让颜色、字体、圆角、表格样式、组件图样式散落在 builder、theme 和 style lock 中。

## 分层

| 层级 | 目录 | 说明 |
|------|------|------|
| 原子层 | `design-system/tokens/` | 颜色、字体、圆角、线宽、间距 |
| 基础组件层 | `design-system/components/` | 文本、容器、数据、图解、媒体等组件 |
| 复杂模块层 | `design-system/patterns/` | 架构图、流程图、矩阵、路线图等组合规则 |
| 场景层 | `design-system/profiles/` | 某类 PPT 的完整风格组合 |
| 发布层 | `templates/style-locks/` | 供生成管线消费的最终 style lock |

## 与 style lock 的边界

- design system 管“模块怎么定义、怎么组合”。
- style lock 管“某个场景最终用哪组 token 和约束”。
- builder 不应直接发明颜色、字号、圆角、表格样式。
- 如果样例文件改变视觉风格，应先更新 design system，再同步 style lock。

## 组件全集

当前组件按六类覆盖 PPT 技术汇报的主要构成：

| 类别 | 组件 |
|------|------|
| 文本与说明 | 文本层级、圆角文本框、代码块、来源脚注 |
| 版面与容器 | 版面区域、分隔线、标签徽标、图例 |
| 数据表达 | KPI 卡片、原生表格、热力矩阵、原生图表、进度指标 |
| 图解与架构 | 原生组件图、流程步骤、时间线里程碑、决策节点、能力分组 |
| 媒体与引用 | 媒体框 |
| 复杂页面 | 架构图、分层图、流程图、对比矩阵、路线图、指标看板、决策树、能力地图 |

完整清单见 `design-system/component-inventory.json` 和 `design-system/components/README.md`。

## 模块维护顺序

1. 先更新 token：颜色、字体、圆角、间距。
2. 再更新基础组件：文本框、表格、组件图节点、连接线。
3. 再更新数据组件和图解组件：KPI、热力矩阵、图表、流程、时间线、决策节点。
4. 再更新复杂 pattern：架构图、流程图、矩阵等组合方式。
5. 最后更新 profile 和 style lock。
6. 增加或调整 benchmark，验证风格是否符合高频场景。

## 样例替换流程

用户后续提供样例文件时，按以下步骤处理：

1. 放入 `design-system/samples/` 或仓库根 `tmp/`。
2. 识别样例中的设计特征：
   - 主色、辅助色、语义色、浅色背景。
   - 标题、正文、表格、脚注字号。
   - 圆角、线宽、边框、内边距。
   - 表格 header、隔行色、重点列样式。
   - KPI 卡片、热力矩阵、图表、进度条样式。
   - 架构节点、分组框、连接线、端口、徽标样式。
   - 时间线、流程步骤、决策节点、能力分组样式。
3. 写入对应 token 和 component JSON。
4. 更新 profile。
5. 必要时更新 style lock。
6. 运行 `scripts/validate_design_system.js` 和 release gate。

## 防漂移要求

- 新增 token 必须被至少一个 component 或 profile 引用。
- 新增 component 必须声明 `depends_on`。
- 新增 profile 必须列出使用的 tokens 和 components。
- 修改基础 token 后，应检查所有 style lock 是否需要同步。
- 修改组件结构后，应检查对应 builder 是否仍能消费。
- 不提交 `design-system/samples/` 中的大体积临时样例，除非明确作为 fixture。

## 与双流程模式的关系

本 skill 的 `draft` 和 `production` 两种工作流模式共享同一套设计系统：

- 两种模式消费相同的 `tokens/`、`components/`、`patterns/`、`profiles/`。
- draft 模式的 `allowed_components` 是 production 组件全集的一个子集，通过 `config/workflow-modes.json` 配置控制。
- 不允许复制一套 "draft 组件" 或 "production 组件"。如果某个组件在 draft 下显得过于复杂，应选择更简单的组件类型（如用 `kpi-card` 代替复杂 pattern），而不是创建变体。
- 用户提供样例 PPTX / 图片时，提取的设计特征进入 design system 上游，不直接分裂 workflow 模式。

详见 `references/workflow-modes.md` 和 `../config/workflow-modes.json`。
