# 迁移说明

> 从外部目录迁移到 agent-tools 仓库的说明文档

---

## 迁移概览

| 来源 | 目标 | 状态 | 日期 |
|------|------|------|------|
| `/Users/zhehan/Documents/tools/dotfiles/observability/litellm` | `tools/gateway/litellm/` | ✅ 已迁移 | 2026-04-09 |
| `/Users/zhehan/Documents/tools/dotfiles/web-tools/searxng` | `tools/search/searxng/` | ✅ 已迁移 | 2026-04-09 |

---

## LiteLLM 迁移

### 迁移内容

**来源目录结构**：
```
/Users/zhehan/Documents/tools/dotfiles/observability/litellm/
├── config.yaml
├── docker-compose.yml
├── .env.example
├── .claude/settings.local.json
└── README.md
```

**目标目录结构**：
```
tools/gateway/litellm/
├── README.md
├── config/
│   └── config.yaml
├── compose/
│   └── docker-compose.yml
├── env/
│   └── .env.example
└── scripts/
    └── litellm.sh
```

### 改动说明

1. **目录重组**：
   - `config.yaml` → `config/config.yaml`
   - `docker-compose.yml` → `compose/docker-compose.yml`
   - `.env.example` → `env/.env.example`

2. **路径修正**：
   - compose 文件中的挂载路径从 `./config.yaml` 改为 `../config/config.yaml`

3. **新增内容**：
   - `scripts/litellm.sh` - 启动/停止脚本
   - README 中的仓库内路径引用

### 验证步骤

```bash
cd tools/gateway/litellm

# 配置环境变量
cp env/.env.example env/.env
# 编辑 .env

# 启动服务
docker compose -f compose/docker-compose.yml up -d

# 验证
curl http://localhost:4000/health
```

---

## SearXNG 迁移

### 迁移内容

**来源目录结构**：
```
/Users/zhehan/Documents/tools/dotfiles/web-tools/searxng/
├── docker-compose.yml
├── searxng/
│   ├── settings.yml
│   └── limiter.toml
├── .claude/settings.local.json
├── verify.sh
└── README.md
```

**目标目录结构**：
```
tools/search/searxng/
├── README.md
├── settings/
│   ├── settings.yml
│   └── limiter.toml
├── compose/
│   └── docker-compose.yml
├── env/
│   └── .env.example
└── scripts/
    └── searxng.sh
```

### 改动说明

1. **目录重组**：
   - `searxng/` → `settings/`
   - `docker-compose.yml` → `compose/docker-compose.yml`

2. **路径修正**：
   - compose 文件中的挂载路径从 `./searxng` 改为 `../settings`

3. **新增内容**：
   - `env/.env.example` - 环境变量模板
   - `scripts/searxng.sh` - 启动/停止脚本
   - README 中的仓库内路径引用

4. **移除内容**：
   - `verify.sh` - 功能已整合到 scripts/searxng.sh
   - `.claude/settings.local.json` - 配置已迁移到 commands/

### 验证步骤

```bash
cd tools/search/searxng

# 启动服务
docker compose -f compose/docker-compose.yml up -d

# 验证
curl http://localhost:8873/healthz
curl "http://localhost:8873/search?q=test&format=json"
```

---

## 新增内容

### SearXNG MCP 服务

**位置**：`tools/search/searxng-mcp/`

**说明**：基于 FastMCP 的 MCP 服务，供 Claude Code 使用

**目录结构**：
```
tools/search/searxng-mcp/
├── README.md
├── pyproject.toml
├── src/
│   ├── __init__.py
│   ├── server.py
│   ├── client.py
│   ├── schema.py
│   └── config.py
├── tests/
│   └── test_server.py
├── compose/
│   └── docker-compose.yml
├── scripts/
│   └── run.sh
└── env/
    └── .env.example
```

### FastMCP Runtime

**位置**：`runtimes/fastmcp/`

**说明**：FastMCP 运行时框架，提供模板和共享库

**目录结构**：
```
runtimes/fastmcp/
├── README.md
├── templates/
│   └── python/
│       ├── README.md
│       ├── pyproject.toml
│       └── src/
└── shared/
    ├── common.py
    └── config.py
```

---

## 回滚指南

如果需要回滚到外部目录配置：

### LiteLLM 回滚

```bash
# 备份仓库内配置
cp -r tools/gateway/litellm/ /tmp/litellm-backup

# 恢复外部目录配置（如果有备份）
# ...
```

### SearXNG 回滚

```bash
# 备份仓库内配置
cp -r tools/search/searxng/ /tmp/searxng-backup

# 恢复外部目录配置（如果有备份）
# ...
```

---

## 参考

- [README.md](../README.md) - 仓库总览
- [docs/architecture/overview.md](architecture/overview.md) - 架构说明
- [docs/verification/README.md](verification/README.md) - 验证指南
