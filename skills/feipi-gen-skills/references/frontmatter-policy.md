# Frontmatter 规范

## 字段要求

- 仅保留 `name` 与 `description` 两个字段。
- `name` 与目录名一致。
- `description` 非空，使用第三人称，<= 1024 字符。
- Frontmatter 不包含 XML 标签。

## 示例

```markdown
---
name: skill-name
description: 用第三人称描述 skill 的核心能力（<=100 字）
---
```

## 常见错误

| 错误 | 修复 |
|------|------|
| 缺少 name 字段 | 添加与目录名一致的 name |
| description 为空 | 补充第三人称描述 |
| description 超过 1024 字符 | 精简到 100 字以内 |
| 包含 XML 标签 | 移除标签 |
