# Rules 目录

> **定位**：AI 行为规则和约束规范
> **状态**：✅ 已创建
> **职责**：定义 AI 在各场景下的行为准则、编码规范、审查标准

---

## 目录结构

```
rules/
├── README.md       # 本文件
├── global/         # 全局规则（始终适用）
├── runtime/        # 运行时规则（服务/工具运行）
├── coding/         # 编码规范
├── diagram/        # 图表绘制规范
├── research/       # 研究/搜索规范
└── review/         # 代码审查规范
```

---

## 为什么需要 Rules 目录？

### Rules 与 Skills 的区别

| 维度 | `rules/` | `skills/` |
|------|----------|-----------|
| **触发方式** | 自动应用 | 显式/隐式触发 |
| **职责** | 约束行为 | 提供能力 |
| **形式** | 规范/准则 | 脚本/工具/模板 |
| **示例** | "中文注释" | "PlantUML 生成" |

**关系说明：**

```
AI 执行任务
    │
    ├── 自动应用 rules/ 中的规范
    │   ├── 使用中文
    │   ├── 遵循编码规范
    │   └── 遵循审查标准
    │
    └── 调用 skills/ 中的能力
        ├── 生成架构图
        ├── 发送通知
        └── 撰写专利
```

### Rules 与 AGENTS.md 的区别

| 维度 | `rules/` | `AGENTS.md` |
|------|----------|-------------|
| **粒度** | 细粒度规则 | 粗粒度指南 |
| **范围** | 特定场景 | 仓库整体 |
| **更新频率** | 较高（随规范演进） | 较低（稳定） |

---

## 各子目录职责

### global/

**全局规则**，在所有场景下自动应用：

- 语言规范（中文优先）
- 通用行为准则
- 安全约束

**示例文件：**
- `global/language.md` - 语言使用规范
- `global/security.md` - 安全约束

### runtime/

**运行时规则**，适用于服务/工具运行场景：

- 服务启动/停止规范
- 环境变量管理
- 容器运行约定

**示例文件：**
- `runtime/service-lifecycle.md` - 服务生命周期
- `runtime/env-management.md` - 环境管理

### coding/

**编码规范**，适用于代码编写场景：

- 代码风格
- 注释规范
- 测试要求
- Git 提交规范

**示例文件：**
- `coding/python.md` - Python 编码规范
- `coding/testing.md` - 测试规范
- `coding/commits.md` - 提交信息规范

### diagram/

**图表绘制规范**，适用于架构图/时序图场景：

- PlantUML 使用规范
- 图表命名约定
- 布局要求
- 审查清单

**示例文件：**
- `diagram/plantuml.md` - PlantUML 规范
- `diagram/naming.md` - 命名约定
- `diagram/review-checklist.md` - 审查清单

### research/

**研究/搜索规范**，适用于信息收集场景：

- 搜索策略
- 信息来源验证
- 引用规范

**示例文件：**
- `research/search-strategy.md` - 搜索策略
- `research/source-verification.md` - 来源验证

### review/

**代码审查规范**，适用于 PR/变更审查场景：

- 审查清单
- 质量门禁
- 安全审查要点

**示例文件：**
- `review/checklist.md` - 审查清单
- `review/security.md` - 安全审查
- `review/performance.md` - 性能审查

---

## 规则文件格式

```markdown
# 规则名称

> **适用场景**：<场景描述>
> **优先级**：<high/medium/low>

## 规则内容

1. 规则 1
2. 规则 2
3. 规则 3

## 示例

### 正确示例

```
<正确代码/行为示例>
```

### 错误示例

```
<错误代码/行为示例>
```

## 参考

- 相关链接
```

---

## 与 Commands、Skills 的协同

```
用户请求："帮我把这个 URL 的内容提取出来"
    │
    ├── rules/research/  → 验证 URL 来源可信
    ├── rules/coding/    → 提取时使用规范的数据结构
    └── tools/crawl4ai-mcp/ → 实际执行抓取
```

---

## 当前 Rules（TODO）

本目录刚创建，以下是计划中的 rules：

| Rule | 位置 | 描述 |
|------|------|------|
| 中文优先 | global/language.md | 所有输出使用中文 |
| PlantUML 规范 | diagram/plantuml.md | PlantUML 图编写规范 |
| Python 编码 | coding/python.md | Python 代码规范 |

---

## 参考

- `AGENTS.md` - 仓库级 agent 指南
- `skills/` - Agent skills
- `commands/` - Slash commands
- `tools/` - External tools
