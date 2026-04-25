# Agent Run Profiler

> 面向本地 Claude Code / Codex 的会话索引与 Token 分析工具

## 快速开始

### 本地运行

```bash
# 安装依赖
pip install jinja2 markdown-it

# 扫描并索引（首次约 8 秒）
./scripts/session-browser.sh scan

# 启动 Web 服务，浏览器打开 http://127.0.0.1:8899
./scripts/session-browser.sh serve
```

### Docker 容器

```bash
# 构建
docker compose -f compose/docker-compose.yml build

# 首次扫描索引
docker compose -f compose/docker-compose.yml run --rm session-browser ./scripts/session-browser.sh scan

# 启动服务
docker compose -f compose/docker-compose.yml up -d
# 浏览器打开 http://localhost:8899
```

容器将 `~/.claude` 和 `~/.codex` 以只读方式挂载，index 持久化在 `./data/index/`。

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `CLAUDE_DATA_DIR` | `~/.claude` | Claude Code 数据目录 |
| `CODEX_DATA_DIR` | `~/.codex` | Codex 数据目录 |
| `INDEX_DIR` | `~/.cache/agent-session-browser` | 索引存储目录 |
| `SERVER_HOST` | `0.0.0.0` | 服务绑定地址 |
| `SERVER_PORT` | `8899` | 服务端口 |

## 页面

| 页面 | 路径 | 内容 |
|------|------|------|
| Dashboard | `/dashboard` | 紧凑指标卡片、趋势图、项目/会话列表 |
| Projects | `/projects` | 所有项目聚合，含 Cache Read/Write 列 |
| Project | `/projects/{key}` | 项目级统计 + 会话列表 |
| Sessions | `/sessions` | 全局会话列表，支持 Agent/Model/Project 过滤 |
| Session | `/sessions/{agent}/{id}` | 折叠对话轮次、Token 柱状图、Token Profile、Tool 树 |
| Agents | `/agents` | Agent 级统计 |
| Token Glossary | `/glossary` | Token 指标定义与 Provider 映射 |
| Search | `/search?q=` | 按标题、项目、模型搜索 |

## 快捷键

| 键 | 操作 |
|----|------|
| `/` | 聚焦搜索框 |
| `t` | 切换到 Token Profile 标签 |
| `m` | 切换到 Messages 标签 |
| `r` | 切换到 Raw 标签 |
| `Esc` | 折叠所有展开的对话轮次 |

## Token 指标

| 指标 | 说明 |
|------|------|
| **Input Fresh** | 实际新发送的输入 Token（未命中缓存） |
| **Cache Read** | 缓存命中的输入 Token（输入侧读） |
| **Cache Write** | 写入缓存的输入 Token（输入侧写） |
| **Output** | 可见输出 Token |

注意：Cache Read ≠ 输出缓存。`cache_read_input_tokens` 和 `cache_creation_input_tokens` 都是输入侧字段。

## 目录结构

```
tools/session-browser/
├── Dockerfile                      # 容器镜像
├── .dockerignore
├── .gitignore
├── compose/
│   └── docker-compose.yml          # 容器编排
├── env/
│   └── .env.example                # 环境变量模板
├── scripts/
│   └── session-browser.sh          # 启动脚本
├── src/
│   └── session_browser/
│       ├── config.py               # 配置中心（环境变量）
│       ├── cli.py                  # CLI 入口
│       ├── domain/
│       │   ├── models.py           # 数据模型
│       │   └── token_normalizer.py # Token 标准化器
│       ├── sources/
│       │   ├── claude.py           # Claude Code 解析器
│       │   └── codex.py            # Codex 解析器
│       ├── index/
│       │   ├── indexer.py          # SQLite 索引
│       │   └── metrics.py          # 聚合统计
│       └── web/
│           ├── routes.py           # HTTP 服务
│           └── templates/          # Jinja2 模板
├── tests/
│   ├── fixtures/                   # 测试数据
│   ├── test_token_normalizer.py    # Token 标准化测试
│   └── test_title_extraction.py    # 标题提取测试
```

## 隐私

- **只读**：不修改任何原始数据
- **本地**：数据源目录以只读方式挂载
- **脱敏**：敏感字段默认隐藏
