# Diagram Type Profiles

## 概述

每个 typed profile 维护自己的 schema、模板、覆盖规则和布局规则。统一 skill 通过 profile 注册表路由到对应逻辑。

## 已迁移 profile

### architecture（已迁移）

- 来源：`feipi-plantuml-generate-architecture-diagram`
- Brief schema：`assets/validation/types/architecture-brief.schema.json`
- Brief template：`assets/templates/types/architecture-brief.yaml`
- 覆盖校验：检查层名、组件 id、流程编号全部落图；额外组件 alias 被拦截
- 布局校验：纵向布局，`top to bottom direction`，package 数量，legend
- 渲染校验：通用渲染脚本

### sequence（已迁移）

- 来源：`feipi-plantuml-generate-sequence-diagram`
- Brief schema：`assets/validation/types/sequence-brief.schema.json`
- Brief template：`assets/templates/types/sequence-brief.yaml`
- 覆盖校验：检查参与者 id、消息编号全部落图；额外消息被拦截；separator 数量校验
- 布局校验：box/separator 结构，autonumber 顺序，`box` 与 `left to right` 互斥，`separator` 关键字禁用
- 渲染校验：通用渲染脚本

## 待扩展 profile

以下 profile 已预留，待后续通过 `references/expansion-playbook.md` 流程接入：

- `class` - 类图
- `activity` - 活动图
- `state` - 状态图
- `usecase` - 用例图
- `component` - 组件图
- `mindmap` - 思维导图
- `gantt` - 甘特图
- `wireframe` - 线框图

## Profile 接口约定

每个 typed profile 必须实现以下接口（脚本层面）：

1. **brief 校验**：`lib/validate_brief_cli.py <brief.yaml> --schema <schema.json>`（由 `validate_package.sh` 调用）
2. **覆盖校验**：`check_coverage.py --type <type> --brief <brief.yaml> --diagram <diagram.puml>`
3. **布局校验**：`lint_layout.sh --type <type> <diagram.puml>`
4. **渲染校验**：统一使用 `check_render.sh`
