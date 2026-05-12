# 类型识别与路由规则

## Router 职责

Router 只负责判断用户意图属于哪种 PlantUML 图，不做复杂校验。

## 识别规则

### 显式类型（优先级最高）

用户在自然语言中明确提到图类型关键词：

| 关键词示例 | 路由到 profile |
|-----------|---------------|
| 架构图、系统架构、模块分层、组件关系图 | `architecture` |
| 时序图、交互图、调用链路、消息流转 | `sequence` |
| 类图、class diagram | `class` |
| 活动图、流程图、activity diagram | `activity` |
| 状态图、状态机、state diagram | `state` |
| 用例图、use case | `usecase` |
| 组件图、component diagram | `component` |

### 可推断类型

用户未明确说图类型，但描述中包含可推断关键词：

- "参与者"、"调用"、"返回"、"时序"、"消息" → 推断 `sequence`
- "层"、"组件"、"依赖"、"架构"、"分层" → 推断 `architecture`

### 不确定类型

关键词不明确或完全不匹配任何 profile → 进入 `fallback`。

## 路由优先级

1. brief YAML 中 `diagram_type` 字段 > 显式关键词 > 可推断关键词 > fallback
2. Router 不应拒绝用户，识别不了也要进入 fallback 生成图。

## Fallback 触发条件

- 用户请求中无图类型关键词
- 描述同时匹配多个类型且无法消歧
- brief 未提供 `diagram_type` 或值不合法
