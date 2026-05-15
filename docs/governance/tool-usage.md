# 工具使用规范

> **目标**：降低 agent 工具输出 token 成本 40-60%
> **原则**：先窄后宽、局部优先、按需读取、输出截断

本规范适用于仓库内所有 Claude Code agent 在分析和编辑任务中的工具调用行为。

## 输出限制汇总

| 操作 | 默认上限 | 说明 |
|---|---|---|
| `sed -n` 行范围 | 100 行 | 明确需要更多上下文时可扩展 |
| `rg` 搜索结果 | 100 行 | 超限时用 `-l` 先缩范围再展开 |
| `tail -n` 日志 | 100 行 | 错误搜索可用 `-C` |
| Read 工具 | 100 行 | 用 `limit`/`offset` 参数 |
| `jq` JSON 提取 | 50 行 | 用更精确路径选择 |
| `git diff` | 先 `--stat` | 单文件不超过 200 行 |
| 测试输出 | 100 行 | 失败详情不超过 20 条 |
| 目录遍历 | 50 条 | `find -maxdepth` 不超过 3 |
| Session 抽样 | top 5 文件 | 每个最多 10 条 message |

## 场景速查

### 文件清单

- 推荐：`rg --files <path>`、`ls -la <path>`
- 禁止：`cat -R`、`find -exec cat`、Read 逐个读目录

### 文本搜索

- 推荐：`rg -n <pattern> <path>`、`rg -C 2`、`rg -l`
- 禁止：`grep -rn` 全仓库后 cat、大文件 cat 后管道 grep

### 局部读取

- 推荐：`sed -n '10,30p'`、`head -n 20`、`tail -n 20`
- 禁止：对 >200 行文件 Read 全文、连续多次 Read 同一文件不同部分

### JSON/YAML

- 推荐：`jq '.key'`、`jq 'keys'`
- 禁止：cat 大型 JSON（如 5MB+ session 快照）

### 日志

- 推荐：`tail -n 50`、`rg -C 5 'ERROR'`
- 禁止：cat 整个日志文件

### Git Diff

- 推荐：`git diff --stat`、`git diff -- <file>`、`git log --oneline -n 10`
- 禁止：无限制 `git diff`、无限制 `git log`

### 目录遍历

- 推荐：`find <path> -maxdepth 2 -type f | head -n 50`
- 禁止：`find . -type f`、`tree .` 不带限制

### Session 抽样

- 推荐：`find -exec stat` 统计大小、`jq` 元数据提取、`rg -l` 定位
- 禁止：cat 或 Read 整个 5MB+ session 文件
