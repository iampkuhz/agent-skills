# 治理产物落位与字段说明

## 落位规则

- Step 1 基线审计、Step 1.5 rename review、rename plan、Step 2 checklist、governance report、anti-pattern 草稿都属于临时治理产物。
- 这些文件只能写到仓库根 `tmp/` 或系统临时目录，例如：
  - `tmp/feipi-video-read-url-step1-audit.md`
  - `tmp/feipi-video-read-url-rename-plan.md`
  - `tmp/feipi-video-read-url-governance-report.md`
- 禁止把这些临时文档提交到任意 skill 的 `assets/`、`references/`、`templates/` 或其他内部目录。

## 通用字段

以下字段应在相关临时文档中按需出现，并保持同名：

- `current_name`
- `target_name`
- `target_layer`
- `target_domain`
- `target_action`
- `target_object`
- `rename_reason`
- `rule_violation`
- `migration_risk`
- `script_localization_status`
- `validation_status`

## 使用原则

- 临时文档只提供治理过程记录，不替代真实分析与验证。
- 若本次不涉及命名迁移，可跳过 Step 1.5，但仍需在 report 中说明原因。
- 旧 rename 结论若不符合 v2，必须通过 Step 1.5 重审，不能直接复用历史结论。
