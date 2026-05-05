# 自动迭代（Auto Iteration）

## 流程

```
Slide IR → Static QA → Repair Plan → Build PPTX → Render QA → Pipeline Report
```

最多 3 轮自动迭代，每轮结构相同。

## 工程化 Pipeline

从 Round 1 开始，自动迭代通过 **pipeline 编排器** 执行：

```bash
node scripts/generate_pptx_pipeline.js <slide-ir.json> <output-dir> [--dry-run] [--no-render] [--json]
```

Pipeline 内部自动执行：

1. **Validate Slide IR**：检查必填字段、枚举值、引用一致性。
2. **Static QA**：`helpers/static-qa.js` 执行语义碰撞检测。
3. **Repair Plan**：如有 hard_fail，`helpers/repair/` 生成修复方案。
4. **Build PPTX**：`helpers/pptx/compiler.js` 编译 PPTX。
5. **Render QA**：如果渲染引擎可用，渲染为 PNG 并检查。
6. **Pipeline Report**：汇总所有结果到 `pipeline-report.json`。

### Pipeline 选项

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `--dry-run` | false | 只做 Validate + Static QA + Repair Plan，不编译 PPTX |
| `--no-render` | false | 跳过 Render QA |
| `--json` | false | 输出 JSON 格式报告 |
| `--max-rounds N` | 3 | 最大迭代轮次 |

### 输出文件

```text
output-dir/
├── pipeline-report.json   # 完整 pipeline 报告
├── qa-static.json         # Static QA 报告
├── repair-plan.json       # 修复 plan（如有 hard_fail）
├── output.pptx            # 编译成功的 PPTX
├── render-manifest.json   # 渲染 manifest（如 render 成功）
└── qa-render.json         # Render QA 报告（如 render 成功）
```

## 轮次定义

### Round 1

```
Static QA 检查 Slide IR
  → 如有 hard_fail：生成 Repair Plan → 报告需要 LLM 根据 plan 重新生成 IR
  → 如无 hard_fail：Build PPTX → Render QA（如引擎可用）→ 交付
```

### Round 2

```
LLM 根据 Round 1 的 Repair Plan 调整 Slide IR
  → Static QA → 如有 hard_fail：生成 Repair Plan
  → Build PPTX → Render QA → 交付
```

### Round 3

```
LLM 根据 Round 2 的 Repair Plan 调整 Slide IR
  → Static QA → 如有 hard_fail：生成 Repair Plan
  → Build PPTX → Render QA
  → 如果仍有 hard_fail：
      - 不强行交付
      - 输出失败原因
      - 输出建议拆页 / 降维方案
      - 等待用户决策
  → 如果无 hard_fail：交付
```

## Pipeline 失败退出策略

| 情况 | 行为 | 退出码 |
|------|------|--------|
| Static QA hard_fail（Round 1-2） | 生成 Repair Plan，不 Build | 1 |
| Static QA hard_fail（Round 3） | `needs_user_decision`，建议拆页 | 100 |
| PPTX 编译失败 | 报告失败原因，终止 | 1 |
| Render QA hard_fail | 生成 Repair Plan，标记失败 | 1 |
| 渲染引擎不可用 | `skip` 状态，不终止 pipeline | 0（pass_with_skip） |
| 所有内容通过 | 交付成功 | 0 |

## 每轮必须产出

每轮迭代必须产出结构化的 QA Report（见 `pipeline-report.json` 中的 rounds 数组）。

## 修复约束

- **禁止通过无限缩小字号解决问题**：字号调整只在修复优先级列表的最后，且不得低于硬规则下限。
- **修复是减法**：优先删除、压缩、合并、重组内容，而不是塞更多内容。
- **每轮修复必须有明确的 Repair Plan**：列出具体修复动作，不是"调整布局"之类的模糊描述。
- **当前阶段不自动改写 Slide IR**：Pipeline 只生成 repair plan，具体改写由 LLM 根据 plan 执行。

## 第 3 轮失败处理

如果第 3 轮仍有 hard_fail，pipeline 输出 `needs_user_decision` 状态：

```json
{
  "status": "needs_user_decision",
  "round": 3,
  "recommendation": "建议拆成两页",
  "reason": "经过 3 轮自动修复仍存在布局溢出、元素重叠，2 项问题未解决。",
  "remaining_issues": [
    { "type": "layout_overflow", "message": "..." },
    { "type": "semantic_overlap", "message": "..." }
  ]
}
```

**不要强行交付有 hard_fail 的页面。**

## 与已有修复策略的关系

- 本文档定义自动迭代的轮次、流程和终止条件。
- 每轮内的具体修复动作遵循 `references/repair-policy.md`。
- Pipeline 编排实现通过 `helpers/pipeline/run-pipeline.js` 和 `scripts/generate_pptx_pipeline.js`。
- 三者互补：本文档管"什么时候修、修几轮"，repair-policy 管"怎么修"，pipeline 管"怎么串起来跑"。
