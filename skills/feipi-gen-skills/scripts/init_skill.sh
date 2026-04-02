#!/usr/bin/env bash
set -euo pipefail

# Skill 初始化脚本
# 用法：bash scripts/init_skill.sh <name> [resources]

SKILL_NAME="${1:-}"
RESOURCES="${2:-scripts,references}"
TARGET_DIR="${3:-.}"

if [[ -z "$SKILL_NAME" ]]; then
  echo "用法：bash scripts/init_skill.sh <skill-name> [resources] [target-dir]" >&2
  echo "  resources: 逗号分隔，可选 scripts,references,assets" >&2
  echo "  target-dir: 目标目录，默认当前目录" >&2
  exit 1
fi

SKILL_PATH="$TARGET_DIR/$SKILL_NAME"

echo "=== 初始化 skill: $SKILL_NAME ==="
echo "目标目录：$SKILL_PATH"
echo "资源：$RESOURCES"

# 创建基础结构
mkdir -p "$SKILL_PATH/agents"

if [[ "$RESOURCES" == *"scripts"* ]]; then
  mkdir -p "$SKILL_PATH/scripts"
  echo "[创建] scripts/"
fi

if [[ "$RESOURCES" == *"references"* ]]; then
  mkdir -p "$SKILL_PATH/references"
  echo "[创建] references/"
fi

if [[ "$RESOURCES" == *"assets"* ]]; then
  mkdir -p "$SKILL_PATH/assets"
  echo "[创建] assets/"
fi

# 创建 agents/openai.yaml 模板
cat > "$SKILL_PATH/agents/openai.yaml" << 'EOF'
version: 1
interface:
  display_name: "Skill 名称"
  short_description: "简短描述（<=50 字）"
  default_prompt: "默认提示词，描述 skill 的核心工作流程。"
EOF
echo "[创建] agents/openai.yaml"

# 创建 SKILL.md 模板
cat > "$SKILL_PATH/SKILL.md" << 'EOF'
---
name: <skill-name>
description: 填写 skill 描述（第三人称，<=100 字）
---

# Skill 名称（中文）

## 核心目标
- 一句话描述 skill 要解决的核心问题

## 适用场景
- 场景 1
- 场景 2

## 非适用场景
- 不适用场景 1
- 不适用场景 2

## 输入与输出
1. 输入：用户需要提供什么
2. 输出：skill 交付什么结果

## 执行流程
1. Explore：明确目标与边界
2. Plan：列出改动与验证方式
3. Implement：实现变更
4. Verify：运行验证并记录结果

## 常用命令
```bash
bash scripts/validate.sh <skill-dir>
bash scripts/test.sh <skill-name>
```
EOF
echo "[创建] SKILL.md"

echo "=== 初始化完成 ==="
echo "下一步：编辑 SKILL.md 和 agents/openai.yaml，然后运行 bash scripts/validate.sh $SKILL_PATH"
