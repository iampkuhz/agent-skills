# <图类型> 参考模板

## 适用场景

- 列出该图类型最常见的 2~3 个任务。

## 宽度与布局约束

1. 元素多时必须使用 `top to bottom direction`。
（sequence 图例外：不要使用该语句）
2. 建议设置：
- `skinparam nodesep 6`
- `skinparam ranksep 70`
3. 单行标签过长时优先换行（`\n`），避免横向撑宽。

## 最小可运行样例

```plantuml
@startuml
top to bottom direction
' TODO: 替换为该图类型的最小样例
@enduml
```

## 常见错误

1. 缺少 `@enduml` 导致渲染失败。
2. 连线过多但未改为上下布局，图宽失控。
3. 标签过长不换行，移动端不可读。

## 验证命令

```bash
bash scripts/check_plantuml.sh ./tmp/<diagram-type>.puml
```
