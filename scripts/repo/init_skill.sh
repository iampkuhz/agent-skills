#!/usr/bin/env bash
set -euo pipefail

# 使用仓库模板初始化一个新 skill。
# 脚本会执行命名规则校验，并创建：
# - SKILL.md
# - agents/openai.yaml
# - 可选资源目录（scripts/references/assets）

usage() {
  cat <<'USAGE'
用法:
  scripts/repo/init_skill.sh <skill-name> [--resources scripts,references,assets]

示例:
  scripts/repo/init_skill.sh feipi-coding-react
  scripts/repo/init_skill.sh gen-api-tests --resources scripts,references
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_ROOT="$REPO_ROOT/skills"
TEMPLATES_ROOT="$REPO_ROOT/templates"

SKILL_NAME="$1"
shift

RESOURCES=""
# `feipi-<action>-<target...>` 命名里的 action 白名单。
ALLOWED_ACTIONS="coding gen read write analyze review test debug refactor docs data git web ops build deploy migrate automate monitor summarize translate design planning"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resources)
      RESOURCES="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! "$SKILL_NAME" =~ ^[a-z0-9-]{1,64}$ ]]; then
  echo "Skill 名称必须匹配 ^[a-z0-9-]{1,64}$" >&2
  exit 1
fi

if [[ "$SKILL_NAME" != feipi-* ]]; then
  # 自动补全前缀，兼容 `make new SKILL=gen-api-tests` 这种输入。
  SKILL_NAME="feipi-$SKILL_NAME"
fi

if [[ ${#SKILL_NAME} -gt 64 ]]; then
  echo "补全前缀后名称超过 64 字符: $SKILL_NAME" >&2
  exit 1
fi

if [[ "$SKILL_NAME" =~ (anthropic|claude) ]]; then
  echo "Skill 名称不能包含保留词 anthropic 或 claude" >&2
  exit 1
fi

IFS='-' read -r -a TOKENS <<< "$SKILL_NAME"
if [[ ${#TOKENS[@]} -lt 3 ]]; then
  echo "Skill 名称必须符合 feipi-<action>-<target...>，例如 feipi-coding-react" >&2
  exit 1
fi

# 第二段是 action，必须在白名单里。
ACTION="${TOKENS[1]}"
if ! printf "%s\n" "$ALLOWED_ACTIONS" | tr ' ' '\n' | rg -qx "$ACTION"; then
  echo "不支持的 action: $ACTION" >&2
  echo "允许的 action: $ALLOWED_ACTIONS" >&2
  exit 1
fi

ROOT_DIR="$SKILLS_ROOT/$SKILL_NAME"
if [[ -e "$ROOT_DIR" ]]; then
  echo "目标目录已存在: $ROOT_DIR" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/agents"

TITLE="$(echo "$SKILL_NAME" | tr '-' ' ' | awk '{for (i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}; print}')"
DESCRIPTION="处理相关任务并输出可验证结果。在用户提出对应场景需求时使用。"

sed \
  -e "s/{{SKILL_NAME}}/$SKILL_NAME/g" \
  -e "s/{{SKILL_DESCRIPTION}}/$DESCRIPTION/g" \
  -e "s/{{TITLE}}/$TITLE/g" \
  "$TEMPLATES_ROOT/SKILL.template.md" > "$ROOT_DIR/SKILL.md"

DISPLAY_NAME="$TITLE"
SHORT_DESCRIPTION="使用中文完成任务，并提供可验证交付证据。"
DEFAULT_PROMPT="请按 $SKILL_NAME 的四阶段流程执行：先探索与规划，再实现与验证；输出需包含验证步骤与结果。"

sed \
  -e "s/{{DISPLAY_NAME}}/$DISPLAY_NAME/g" \
  -e "s/{{SHORT_DESCRIPTION}}/$SHORT_DESCRIPTION/g" \
  -e "s/{{DEFAULT_PROMPT}}/$DEFAULT_PROMPT/g" \
  "$TEMPLATES_ROOT/openai.template.yaml" > "$ROOT_DIR/agents/openai.yaml"

if [[ -n "$RESOURCES" ]]; then
  # 根据参数创建可选资源目录。
  IFS=',' read -r -a ARR <<< "$RESOURCES"
  for r in "${ARR[@]}"; do
    case "$r" in
      scripts|references|assets)
        mkdir -p "$ROOT_DIR/$r"
        ;;
      *)
        echo "未知资源类型: $r (仅支持 scripts,references,assets)" >&2
        exit 1
        ;;
    esac
  done
fi

echo "已初始化: skills/$SKILL_NAME"
