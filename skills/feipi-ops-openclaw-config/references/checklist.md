# OpenClaw 配置优化检查清单

## 修改前

1. 确认目标文件路径（通常是 `openclaw.json`）。
2. 明确变更目标键与影响范围（模型、渠道、skills、workspace、gateway）。
3. 明确是否允许自动重启 gateway。

## 修改中

1. 敏感字段统一使用 `${ENV_NAME}`，不得写入明文。
2. 仅修改目标相关键，避免顺手重排无关键。
3. 保留可回滚信息（变更前后值、命令历史或 diff）。

## 修改后

1. 运行配置审计脚本：
```bash
bash scripts/audit_openclaw_config.sh --config <path-to-openclaw.json>
```
2. 运行 JSON 结构检查：
```bash
jq . <path-to-openclaw.json> >/dev/null
```
3. 若本机有 `openclaw`，补充运行：
```bash
openclaw doctor
```

## 输出模板（建议）

1. 改动摘要：`文件 + 键路径 + 新旧值`
2. 验证记录：`命令 + 结果`
3. 风险与回滚：`风险项 + 回滚步骤`
