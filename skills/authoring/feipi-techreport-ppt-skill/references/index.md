# References 索引

本目录为 `feipi-techreport-ppt-skill` 的按需参考资料。不要一次性读取所有文件；根据当前工作流阶段加载对应 references。

## 按阶段路由

### 阶段 1：模式判断

确定当前使用 draft 还是 production 模式。

| 文件 | 行数 | 何时读取 |
|---|---|---|
| `workflow-modes.md` | ~242 | 判断模式、理解差异、模式升级流程 |
| `config/workflow-modes.json` | - | 读取模式配置真源 |

### 阶段 2：输入充足性检查

判断用户提供的原始信息是否足够支撑生成 PPT 单页。

| 文件 | 行数 | 何时读取 |
|---|---|---|
| `input-sufficiency.md` | ~118 | 需要判断信息是否足够、或输出补充请求时 |

### 阶段 3：Page Contract 与交互

生成 Page Contract、决策确认卡片、与用户交互确认。

| 文件 | 行数 | 何时读取 |
|---|---|---|
| `page-contract.md` | ~170 | 生成或理解 Page Contract 内部格式、容量预算 |
| `interaction-protocol.md` | ~123 | 需要判断交互流程、确认机制、是否追问 |

### 阶段 4：版面与视觉

选择版式、确定视觉规范、生成 Layout Blueprint。

| 文件 | 行数 | 何时读取 |
|---|---|---|
| `layout-patterns.md` | ~172 | 选择页面结构、图表组合、单页版式 |
| `visual-style.md` | ~170 | 确定默认视觉规范、字号、颜色、密度、间距 |
| `design-system.md` | ~84 | 引用 design system token 与组件定义 |

### 阶段 5：QA 与修复

执行生成后质量检查和自动修复。

| 文件 | 行数 | 何时读取 |
|---|---|---|
| `visual-qa.md` | ~192 | PPTX 生成后检查视觉问题 |
| `qa-gates.md` | ~284 | 执行 QA 门禁、判定问题分级 |
| `repair-policy.md` | ~128 | 修复过密、重叠、溢出问题 |
| `auto-iteration.md` | ~127 | 执行自动迭代修复流程 |

### 阶段 6：工程框架

理解整体工程架构、Slide IR、后端选择。

| 文件 | 行数 | 何时读取 |
|---|---|---|
| `executable-framework.md` | ~143 | 理解分层架构、各层职责、与底层 PPTX 工具的关系 |
| `slide-ir.md` | ~241 | 构建或理解 Slide IR 中间表示 |
| `backend-selection.md` | ~110 | 选择 PPTX 写入后端 |
| `runtime-environment.md` | ~92 | 确认运行时依赖与环境配置 |
| `primitive-contracts.md` | ~109 | 理解组件级合约与 Slide IR 的关系 |

### 阶段 7：示例与参考

| 文件 | 行数 | 何时读取 |
|---|---|---|
| `examples.md` | ~343 | 参考架构页、对比矩阵页、路线图页等输入输出示例 |

### 阶段 8：P0 模板

高频场景的快速模板。

| 文件 | 行数 | 何时读取 |
|---|---|---|
| `p0-scenario-system.md` | ~112 | 高频 P0 场景识别与路由 |
| `p0-template-taxonomy.md` | ~36 | P0 模板分类速查 |

### 其他

| 文件 | 行数 | 何时读取 |
|---|---|---|
| `release-gate.md` | ~63 | 发布前检查清单 |

## 加载建议

- **首次触发**（用户给出材料要求生成 PPT）：阶段 1 → 阶段 2 → 阶段 3
- **确认后生成**：阶段 4 → 阶段 6（Slide IR）→ PPTX 生成
- **生成后**：阶段 5
- **遇到疑难**：按需读取对应 references + `examples.md`
- **高频场景**：阶段 8 模板可直接跳过阶段 3-4 的部分细节

## 总量

- SKILL.md：111 行
- references/：20 文件，约 3059 行
- 首次加载（仅 SKILL.md）：111 行，减少约 65% 的首次加载成本（对比原版 318 行）
