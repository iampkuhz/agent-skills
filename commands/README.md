# Commands 目录

> **定位**：统一的 Slash Commands 管理中心
> **状态**：✅ 已创建
> **职责**：管理 Claude Code、Codex 等客户端的 slash commands

---

## 目录结构

```
commands/
├── README.md       # 本文件
├── shared/         # 共享 commands（客户端无关）
├── claude/         # Claude Code 专属 commands
└── codex/          # Codex 专属 commands
```

---

## 为什么 Commands 需要独立目录？

### 问题：分散管理的痛点

在 commands/ 目录创建之前，slash commands 分散在：
- `.claude/commands/`
- `.codex/commands/`

这种分散管理带来以下问题：

1. **重复维护**：相同功能的 command 需要在多处复制
2. **版本不同步**：修改一个 command 容易遗漏其他副本
3. **边界模糊**：难以区分通用 commands 和客户端专属 commands
4. **发现困难**：新用户不知道仓库提供了哪些 commands

### 解决方案：统一 commands/ 目录

```
commands/
├── shared/         # 所有客户端共享的 commands
│   ├── help.md
│   └── project-info.md
├── claude/         # Claude Code 专属
│   ├── debug.md
│   └── test.md
└── codex/          # Codex 专属
    └── legacy.md
```

---

## 与 Skills、Rules、Tools 的边界

| 目录 | 职责 | 触发方式 | 示例 |
|------|------|----------|------|
| `commands/` | **Slash Commands** - 显式触发 | `/command` | `/help`, `/test` |
| `skills/` | **Agent Skills** - 隐式能力 | 自动触发 | PlantUML 生成、专利撰写 |
| `rules/` | **行为规则** - 约束 AI 行为 | 自动应用 | 编码规范、 diagram 约定 |
| `tools/` | **外部服务** - API 封装 | MCP 调用 | SearXNG 搜索、Crawl4AI 抓取 |

**关系说明：**

```
用户输入 "/test"
    │
    ▼
commands/claude/test.md  ← 显式 slash command
    │
    └── 可能触发
        │
        ├── skills/ 中的测试技能
        ├── rules/ 中的测试规范
        └── tools/ 中的测试服务
```

---

## 目录职责

### shared/

存放**客户端无关**的通用 commands：

- 项目信息
- 帮助文档
- 通用工作流

**特点：**
- 可在多个客户端中复用
- 不依赖特定客户端的功能
- 通常是信息性或文档性内容

### claude/

存放 **Claude Code 专属**的 commands：

- 利用 Claude Code 特有功能
- 依赖 Claude Code 的工具链
- 针对本仓库的定制化 commands

### codex/

存放 **Codex 专属**的 commands：

- 历史遗留 commands（如有）
- Codex 特定功能

---

## 使用方式

### 方式一：软链接到客户端目录

```bash
# 在仓库根目录执行
make install-links AGENT=claudecode

# 这会将 commands/ 中的内容链接到 ~/.claude/commands/
```

### 方式二：直接在配置中引用

在 `.claude/settings.local.json` 中配置：

```json
{
  "commands": {
    "include": [
      "../commands/shared",
      "../commands/claude"
    ]
  }
}
```

---

## 创建新 Command

### 步骤 1：确定类型

- **通用 command** → `commands/shared/<name>.md`
- **Claude Code 专属** → `commands/claude/<name>.md`
- **Codex 专属** → `commands/codex/<name>.md`

### 步骤 2：创建文件

```markdown
# /<command-name>

<command 描述>

## 用法

```
/<command-name> [参数]
```

## 示例

```
/<command-name> 示例参数
```

## 实现细节

（可选）
```

### 步骤 3：验证

```bash
# 在 Claude Code 中测试
/<command-name> 测试
```

---

## 当前 Commands（TODO）

本目录刚创建，以下是计划中的 commands：

| Command | 位置 | 描述 |
|---------|------|------|
| `/help` | shared/ | 仓库级帮助 |
| `/status` | shared/ | 项目状态 |
| `/deploy` | claude/ | 部署相关 |

---

## 参考

- `.claude/commands/` - Claude Code commands（保留，用于快速链接）
- `.codex/commands/` - Codex commands（保留）
- `skills/` - Agent skills
- `rules/` - 行为规则
