# PRD: Agent Session Browser (`session-browser`)

> 面向本地 Claude Code / Codex 的会话索引与上下文流量分析工具

---

## 1. 背景

当前本机已经同时使用 Claude Code 与 Codex 进行日常开发，但会话历史、上下文用量、工具调用情况分散在不同目录和不同格式中：

- Claude Code 主要落在 `~/.claude/history.jsonl`、`~/.claude/projects/**/*.jsonl`
- Codex 主要落在 `~/.codex/history.jsonl`、`~/.codex/session_index.jsonl`、`~/.codex/sessions/**/*.jsonl`、`~/.codex/state_5.sqlite`

现状问题：

1. 无法统一查看某个项目在两个 Agent 中的历史会话
2. 无法快速回溯单次会话的上下文流量、工具调用密度、模型与工作目录
3. 无法从项目维度看“最近谁在用、用了多少、消耗在哪里”
4. 原始文件结构偏底层，人工检索成本高，且存在敏感信息暴露风险

因此需要一个**本地只读、可检索、可分析**的浏览工具。

---

## 2. 产品定位

`session-browser` 定位为仓库内的一个 `Tool`，放在 `tools/session-browser/`。

它不是：

- 不是 `Skill`：目标用户是人，不是对话内的 LLM 调用链
- 不是 MCP 服务：MVP 不要求被模型调用
- 不是通用日志平台：只聚焦本机 Agent 会话与上下文流量分析
- 不是远程共享系统：默认仅本机访问

它是：

- 一个本地原生 Python 工具
- 一个只读索引器 + 本地 Web 浏览界面
- 一个面向回溯、分析、排障的个人工作台

---

## 3. 产品目标

### 3.1 MVP 目标

1. 统一索引 Claude Code 与 Codex 的会话清单
2. 支持按项目、Agent、时间、模型、工具名检索会话
3. 支持项目页查看会话分布、最近活跃、总 token、工具调用次数
4. 支持会话页查看基础元信息、可见对话流、工具调用、上下文流量指标
5. 默认对敏感信息做脱敏和隔离展示

### 3.2 核心分析指标

MVP 关注以下“上下文流量”指标：

- 会话数
- 项目活跃度
- 用户消息数 / 助手消息数
- 工具调用次数
- 输入 tokens / 输出 tokens / 缓存命中 tokens
- 会话持续时间
- 模型分布
- Agent 使用分布（Claude Code / Codex）

### 3.3 非目标

以下能力不进入 MVP：

- 解析 Claude / Codex 的全部内部 debug 日志
- 展示 hidden reasoning 原文
- 多用户共享、登录鉴权、远程访问
- 修改原始 session 文件
- 成本计费精算
- 自动摘要、自动打标签、自动归因

---

## 4. 目标用户与场景

### 4.1 目标用户

- 本仓库维护者
- 经常并行使用多个 Agent 的开发者
- 需要回溯历史上下文与工具使用情况的人

### 4.2 核心使用场景

1. **项目回溯**
   - 我想看某个项目最近 7 天在 Claude Code 和 Codex 中分别做了什么

2. **会话诊断**
   - 我想看某次会话为什么 token 特别高、工具调用特别多

3. **使用分析**
   - 我想知道最近更多是在用 Claude Code 还是 Codex，在哪些项目上用得最多

4. **上下文核查**
   - 我想确认某次会话到底用了什么模型、cwd、branch、工具和上下文量

---

## 5. 成功标准

### 5.1 产品验收指标

1. 本机双 Agent 会话可统一检索
2. 项目页和会话页信息来源明确，可追溯到原始文件
3. 敏感字段默认不明文暴露
4. 首次建索引和增量刷新具备可接受性能

### 5.2 工程验收指标

1. 首次全量索引在常见个人数据规模下可完成
   - 目标：`< 10s`
   - 说明：以个人机器上的数百个会话为基线，不以历史硬编码条数作为验收口径
2. 增量刷新只重扫变更文件
   - 目标：`< 2s`
3. 页面查询延迟可接受
   - 目标：常见列表页 `< 500ms`
4. 工具默认只绑定本机
   - 目标：默认监听 `127.0.0.1`

---

## 6. 形态与架构决策

### 6.1 为什么是 Tool

| 维度 | Skill | Tool | 结论 |
|------|-------|------|------|
| 主要使用者 | LLM | 人 | Tool |
| 主要交互方式 | 对话调用 | 浏览器/本地页面 | Tool |
| 生命周期 | 单轮任务 | 持久可回看 | Tool |
| 数据来源 | 对话上下文 | 本地历史文件 / SQLite | Tool |

### 6.2 为什么 MVP 不做 FastMCP

MVP 不使用 FastMCP，原因如下：

1. 当前需求是**人看页面**，不是 LLM 发起工具调用
2. 数据源都是本地文件和本地 SQLite，无协议层要求
3. 直接做本地 Web 服务可以减少一层抽象

说明：

- 后续若出现“让 Agent 在对话中查询历史会话”的需求，可在 Phase 4 之后再评估 MCP 化
- 该决定仅针对 MVP，不否定后续追加 MCP 适配层

### 6.3 为什么 MVP 不优先用 Docker / Compose

MVP 优先做**本地原生 Python 服务**，不优先做容器化，原因如下：

1. 数据源位于宿主机 `~/.claude/`、`~/.codex/`，容器方案需要额外挂载与权限处理
2. 该工具本质是个人本机分析工具，不是标准化网络服务
3. 原生运行更适合快速验证数据契约与索引逻辑

结论：

- MVP：原生 Python
- 后续：如果需要统一部署，再评估容器化包装

---

## 7. 数据源与数据契约

本工具必须以“**数据契约先行**”实现，而不是先画页面再反推数据。

### 7.1 统一抽象模型

MVP 统一到以下会话索引模型：

```json
{
  "agent": "claude_code|codex",
  "session_key": "claude_code:<id> | codex:<id>",
  "session_id": "原始会话 ID",
  "title": "首条用户消息或线程标题",
  "project_key": "规范化后的项目路径",
  "project_name": "路径最后一节",
  "cwd": "工作目录绝对路径",
  "started_at": "ISO8601",
  "ended_at": "ISO8601",
  "duration_seconds": 0,
  "model": "模型名",
  "git_branch": "分支名，可为空",
  "source": "cli|vscode|...",
  "user_message_count": 0,
  "assistant_message_count": 0,
  "tool_call_count": 0,
  "input_tokens": 0,
  "output_tokens": 0,
  "cached_input_tokens": 0,
  "has_sensitive_data": true
}
```

关键约束：

1. `session_key` 必须是 `(agent, session_id)` 组合，不能只用 `session_id`
2. `project_key` 必须是完整规范化路径，不能只用目录名
3. 页面路由必须使用稳定 ID 或编码后的路径，不能只用 `projectName`

### 7.2 Claude Code 数据源

| 数据源 | 路径 | 角色 | MVP 是否必需 |
|--------|------|------|--------------|
| 会话索引 | `~/.claude/history.jsonl` | 会话清单入口 | 必需 |
| 会话事件流 | `~/.claude/projects/**/*.jsonl` | 会话详情权威来源 | 必需 |
| 活跃会话元信息 | `~/.claude/sessions/*.json` | 当前活跃态补充 | 可选 |
| 环境快照 | `~/.claude/session-env/<sessionId>/` | 敏感环境信息 | 延后 |

#### Claude Code 解析规则

1. `history.jsonl`
   - 用于快速拿到 `sessionId`、`project`、首条展示文本、时间戳
   - 不作为会话详情权威来源

2. `projects/**/*.jsonl`
   - 作为 Claude 会话详情的权威来源
   - 文件内存在多种事件类型，不可假设“一行就是一条普通消息”
   - 已确认常见类型至少包括：
     - `user`
     - `assistant`
     - `system`
     - `file-history-snapshot`

3. 消息统计口径
   - `user_message_count`：仅统计 `type=user`
   - `assistant_message_count`：仅统计 `type=assistant`
   - 不把 `system`、`file-history-snapshot` 算进消息轮次

4. 工具调用口径
   - 工具调用来自 `assistant.message.content[]` 中 `type=tool_use` 的条目
   - 不使用“相邻 timestamp 差值”硬估所有工具耗时作为唯一真值

5. token 口径
   - 从 `assistant.message.usage` 提取
   - 若单条只有部分字段，则按字段级聚合

### 7.3 Codex 数据源

| 数据源 | 路径 | 角色 | MVP 是否必需 |
|--------|------|------|--------------|
| 历史输入索引 | `~/.codex/history.jsonl` | 用户原始输入补充 | 可选 |
| 线程索引 | `~/.codex/session_index.jsonl` | 线程标题与更新时间入口 | 必需 |
| 会话事件流 | `~/.codex/sessions/**/*.jsonl` | 会话详情权威来源 | 必需 |
| 线程元数据库 | `~/.codex/state_5.sqlite` | 线程标题、cwd、branch、model、tokens 等补充 | 必需 |
| 调试日志 | `~/.codex/logs_2.sqlite` | 内部日志诊断 | 不进入 MVP |

#### Codex 解析规则

1. `session_index.jsonl`
   - 用于获取线程标题、更新时间
   - 不足以构成会话详情页

2. `sessions/**/*.jsonl`
   - 作为 Codex 会话详情权威来源
   - 已确认常见顶层事件包括：
     - `session_meta`
     - `turn_context`
     - `response_item`
     - `event_msg`

3. 消息统计口径
   - `response_item` 且 `payload.type=message`、`role=user|assistant` 计入消息数
   - `commentary` 与 `final` 都属于助手可见输出，统一归入助手消息

4. 工具调用口径
   - `response_item` 且 `payload.type=function_call` 计为工具调用
   - `function_call_output` 单独记录，不重复计为工具调用次数

5. token 口径
   - 从 `event_msg` 且 `payload.type=token_count` 中读取
   - 会话总量取该会话最后一次或最大一次 `total_token_usage`
   - 不对多次累计快照做简单求和

6. 元信息补充
   - `cwd`、`title`、`git_branch`、`model`、`tokens_used` 优先从 `state_5.sqlite.threads` 补全
   - 若流文件与 SQLite 不一致，以“事件流优先、SQLite 补充”为原则

### 7.4 暂不进入 MVP 的数据

以下数据先不进入 MVP 主路径：

1. `~/.codex/logs_2.sqlite`
   - 仅保留“后续可做高级诊断”的说明
   - 不在 MVP 页面对用户承诺日志解析能力

2. `~/.claude/session-env/<sessionId>/`
   - 含敏感环境变量
   - Phase 4 再做，并且默认脱敏

3. hidden reasoning / encrypted reasoning
   - 不做展示目标

---

## 8. 隐私与安全

这是本工具的强约束章节，不可省略。

### 8.1 基本原则

1. 只读访问，不修改任何原始数据
2. 默认仅本机访问，监听 `127.0.0.1`
3. 默认不展示敏感原文
4. 默认不提供对外分享链接

### 8.2 默认脱敏策略

以下内容默认脱敏或折叠：

- 环境变量值
- Cookie
- API Key / Token / Secret / Password
- 工具调用参数中的鉴权头、密钥、长文本 Prompt
- 可能包含用户隐私的 pasted contents / attachments 原文

### 8.3 敏感展示分层

页面分为三层：

1. **默认层**
   - 会话摘要、基础指标、工具名、模型、项目路径

2. **详情层**
   - 可见对话流、工具参数摘要

3. **敏感层**
   - 环境变量、原始参数、原始事件
   - 默认关闭
   - 必须显式点击“显示敏感信息（仅本机）”后才展示

### 8.4 安全实现要求

1. Web 服务默认绑定 `127.0.0.1`
2. 默认不自动打开外网可访问地址
3. 若未来支持导出，导出内容默认也必须走脱敏逻辑

---

## 9. 页面与信息架构

MVP 不追求复杂炫技页面，优先保证信息正确和可检索。

### 9.1 页面 1：总览页 `/`

展示内容：

- 总会话数
- 近 7 天 / 30 天会话趋势
- 近 7 天 / 30 天 token 趋势
- Agent 使用分布
- 活跃项目 Top N
- 最近会话列表

支持筛选：

- 时间范围
- Agent
- 项目
- 模型

### 9.2 页面 2：项目页 `/projects/{project_key}`

展示内容：

- 项目路径
- Claude Code / Codex 会话数
- 最近活跃时间
- 总 token
- 总工具调用次数
- 会话列表

会话列表字段：

- 标题
- Agent
- 时间
- 模型
- token 总量
- 工具调用次数

### 9.3 页面 3：会话页 `/sessions/{agent}/{session_id}`

展示内容：

- 基础元信息
  - Agent
  - session id
  - cwd
  - project
  - started / ended / duration
  - model
  - git branch
- 指标卡片
  - user / assistant / tool calls
  - input / output / cached tokens
- 对话流
  - 默认仅展示用户消息、助手可见输出、工具调用摘要
- 工具调用列表
  - 工具名
  - 参数摘要
  - 调用顺序
- 原始事件视图
  - 调试用途
  - 默认折叠

### 9.4 搜索

顶部统一搜索，支持：

- 标题 / 首条用户消息
- session id
- 项目路径
- 模型
- 工具名

---

## 10. 功能需求

### FR-1 索引与刷新

1. 支持首次全量扫描
2. 支持按文件变更时间做增量刷新
3. 支持手动点击“刷新索引”
4. Web 请求本身不应强制触发全量重扫

### FR-2 统一检索

1. 支持跨 Agent 统一列表
2. 支持按项目、时间、模型、Agent、工具名过滤
3. 支持按最近活跃、token 总量、工具调用次数排序

### FR-3 会话详情

1. 能查看基础元信息
2. 能查看可见对话流
3. 能查看工具调用摘要
4. 能查看上下文流量统计

### FR-4 项目分析

1. 能按项目聚合会话
2. 能对比 Claude Code 与 Codex 在同一项目中的使用情况
3. 能展示最近活跃和总量指标

### FR-5 敏感信息控制

1. 默认脱敏
2. 默认隐藏敏感层
3. 提供显式切换入口

---

## 11. 非功能需求

| 类别 | 要求 |
|------|------|
| 只读 | 不写入 `~/.claude/`、`~/.codex/` 原始数据 |
| 本地 | 不调用任何远程 API |
| 安全 | 默认仅监听 `127.0.0.1` |
| 性能 | 支持增量索引，不在每次请求做全量扫描 |
| 可追溯 | 页面字段必须能映射回原始数据源 |
| 兼容 | Python 3.10+，macOS 优先 |

---

## 12. 工程方案

### 12.1 技术选型

| 层级 | 选型 | 说明 |
|------|------|------|
| 语言 | Python 3.10+ | 与仓库环境一致 |
| 源数据访问 | `json`, `sqlite3`, `pathlib` | 标准库足够 |
| 索引存储 | `sqlite3` | 便于增量刷新与聚合查询 |
| 模板 | `jinja2` | 轻量模板渲染 |
| 前端 | 原生 HTML/CSS/JS | 避免引入前端构建链 |
| 图表 | 本地 SVG / 轻量原生绘制 | 不依赖 CDN |
| 服务 | 标准库 HTTP 或轻量 WSGI | 本地服务即可 |

约束：

- MVP 不依赖外部 CDN
- MVP 不要求 Docker

### 12.2 运行模式

提供两种模式：

1. **索引模式**
   - 生成或刷新本地索引库

2. **服务模式**
   - 启动本地 Web 服务，读取索引库展示页面

说明：

- 索引和服务解耦，避免“每次打开页面都重扫全盘”

### 12.3 索引库位置

默认将运行时索引放在用户本地缓存目录，例如：

```text
~/.cache/agent-session-browser/index.sqlite
```

原则：

1. 运行时数据默认不写回仓库，避免污染 git 工作区
2. 若后续需要导出报告，再单独输出到显式指定目录

---

## 13. 分阶段实施

### Phase 1：数据契约与解析器

目标：

- 固化 Claude / Codex 的解析口径
- 产出统一的会话索引模型

交付物：

- `sources/claude.py`
- `sources/codex.py`
- `domain/models.py`
- `tests/fixtures/`
- 解析器测试

验收标准：

- 能解析 Claude 会话索引与详情流
- 能解析 Codex 线程索引、详情流与 `threads` 表
- 能输出统一 `SessionSummary`
- 有样例 fixture 覆盖主要事件类型

### Phase 2：本地索引器

目标：

- 把原始文件增量归并到本地索引 SQLite

交付物：

- `indexer.py`
- `metrics.py`
- `python -m session_browser scan`

验收标准：

- 支持首次全量索引
- 支持增量刷新
- 索引结果可按项目、Agent、时间、模型查询

### Phase 3：本地 Web UI

目标：

- 提供总览页、项目页、会话页

交付物：

- `web/routes.py`
- `web/templates/`
- `web/static/`
- `python -m session_browser serve --host 127.0.0.1 --port 8899`

验收标准：

- 首页可查看趋势和最近会话
- 项目页可按项目聚合
- 会话页可查看元信息、对话流、工具调用和 token 指标
- 搜索与筛选可用

### Phase 4：高级诊断与敏感层控制

目标：

- 补充原始事件视图和更严格的脱敏控制
- 评估是否需要引入 `logs_2.sqlite` 的诊断能力

交付物：

- 原始事件页 / 折叠视图
- 敏感字段白名单 / 黑名单配置
- `logs_2.sqlite` 可行性说明

验收标准：

- 默认脱敏不破坏主要分析链路
- 高级诊断能力与 MVP 主流程边界清晰

### Phase 5：仓库集成

目标：

- 接入仓库命令与文档

交付物：

- `Makefile` 目标
- `tools/session-browser/README.md`
- 根目录 `README.md` 或工具索引更新
- 若引入环境变量，同步更新仓库根 `.env.example`

验收标准：

- 可通过统一命令启动
- 文档包含使用方式、数据源说明、隐私说明

---

## 14. 目录结构（建议终态）

```text
tools/session-browser/
├── README.md
├── scripts/
│   └── session-browser.sh
├── src/
│   └── session_browser/
│       ├── __init__.py
│       ├── cli.py
│       ├── config.py
│       ├── domain/
│       │   └── models.py
│       ├── sources/
│       │   ├── claude.py
│       │   └── codex.py
│       ├── index/
│       │   ├── indexer.py
│       │   └── metrics.py
│       └── web/
│           ├── routes.py
│           ├── templates/
│           └── static/
└── tests/
    ├── fixtures/
    ├── test_claude_source.py
    ├── test_codex_source.py
    └── test_indexer.py
```

说明：

1. 不在工具目录下新增分散式 `env/.env.example`
2. 若确实需要环境变量，统一回收至仓库根 `.env.example`
3. 运行时索引库默认不进仓库目录

---

## 15. 命令建议

```bash
# 全量或增量刷新索引
python -m session_browser scan

# 启动本地服务
python -m session_browser serve --host 127.0.0.1 --port 8899

# 运行测试
pytest tools/session-browser/tests
```

仓库级包装命令可在集成阶段补充，例如：

```bash
make session-browser-run
make session-browser-scan
make session-browser-test
```

---

## 16. 风险与待决策项

### 16.1 已知风险

1. Claude / Codex 的内部事件格式未来可能演进，解析器必须容错
2. 敏感信息脱敏若做得不完整，风险高于普通工具
3. token 统计来自不同 Agent 的不同事件模型，需要清晰标注“口径”

### 16.2 待决策项

1. 是否在 Phase 4 引入 `logs_2.sqlite` 诊断页
2. 是否支持导出脱敏后的静态报告
3. 是否在后续追加 MCP 查询接口

---

## 17. DoD

交付完成必须满足：

1. **可追溯**
   - 页面字段与数据源映射清晰

2. **可验证**
   - 解析器、索引器、页面主流程均有测试或手工验证路径

3. **规范一致**
   - 遵循仓库 `AGENTS.md` 与 `rules/`

4. **安全可控**
   - 默认只读、本地、脱敏

5. **范围收敛**
   - MVP 先解决会话索引与上下文流量分析，不把高级日志平台一并做掉
