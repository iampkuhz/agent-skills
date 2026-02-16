# 图类型参考索引

## 目标

按“每种图类型一个独立 reference 文件”维护样例与约束，避免不同图混在同一文档中。

## 当前 reference 清单

1. `references/component.md`：组件图样例与布局规则（已提供完整样例）。
2. `references/sequence.md`：时序图参考位（待补充业务样例）。
3. `references/class.md`：类图参考位（待补充业务样例）。
4. `references/diagram-reference-template.md`：新增图类型时的统一模板。

## 新增图类型流程

1. 新建 `references/<diagram-type>.md`。
2. 在该文件中放：触发场景、宽度控制、最小可运行样例、常见错误。
3. 在本索引登记该文件。
4. 在 `SKILL.md` 的“渐进式披露导航”补充该入口。

## 命名建议

- 文件名使用小写英文图类型：`component.md`、`sequence.md`、`class.md`。
- 避免混合命名：不要把多个图类型堆在一个“all.md”中。
