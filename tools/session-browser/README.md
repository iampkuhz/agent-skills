# session-browser

> 面向本地 Claude Code / Codex 的会话索引与上下文流量分析工具

## 快速开始

### 本地运行

```bash
# 安装依赖
pip install jinja2

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
| 总览仪表盘 | `/` | 统计卡片、30 天趋势、项目 Top N、最近会话 |
| 项目列表 | `/projects` | 所有项目聚合统计 |
| 项目详情 | `/projects/{key}` | 会话数、token、工具调用、会话列表 |
| 会话详情 | `/sessions/{agent}/{id}` | 元信息、对话流、工具调用 |
| 搜索 | `/search?q=` | 按标题、项目、模型搜索 |

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
│       │   └── models.py           # 数据模型
│       ├── sources/
│       │   ├── claude.py           # Claude Code 解析器
│       │   └── codex.py            # Codex 解析器
│       ├── index/
│       │   ├── indexer.py          # SQLite 索引
│       │   └── metrics.py          # 聚合统计
│       └── web/
│           ├── routes.py           # HTTP 服务
│           └── templates/          # Jinja2 模板
└── tests/
    └── fixtures/
```

## 隐私

- **只读**：不修改任何原始数据
- **本地**：数据源目录以只读方式挂载
- **脱敏**：敏感字段默认隐藏
