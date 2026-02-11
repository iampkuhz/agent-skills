#!/usr/bin/env bash
set -euo pipefail

# 按仓库规则校验单个 skill 目录：
# - 命名规范（feipi-<action>-<target...>）
# - frontmatter 约束
# - 中文内容约束
# - 基础结构与元数据完整性

usage() {
  cat <<'USAGE'
用法:
  scripts/quick_validate.sh <path-to-skill-folder>

示例:
  scripts/quick_validate.sh skills/feipi-coding-react
USAGE
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

DIR="$1"

if [[ ! -d "$DIR" ]]; then
  echo "不是目录: $DIR" >&2
  exit 1
fi

BASE="$(basename "$DIR")"
if [[ ! "$BASE" =~ ^[a-z0-9-]{1,64}$ ]]; then
  echo "无效目录名: $BASE (需匹配 ^[a-z0-9-]{1,64}$)" >&2
  exit 1
fi

if [[ "$BASE" != feipi-* ]]; then
  echo "目录名必须以 feipi- 开头: $BASE" >&2
  exit 1
fi

IFS='-' read -r -a NAME_TOKENS <<< "$BASE"
if [[ ${#NAME_TOKENS[@]} -lt 3 ]]; then
  echo "目录名必须符合 feipi-<action>-<target...>: $BASE" >&2
  exit 1
fi

ALLOWED_ACTIONS="coding gen read write analyze review test debug refactor docs data git web ops build deploy migrate automate monitor summarize translate design planning"
ACTION="${NAME_TOKENS[1]}"
if ! printf "%s\n" "$ALLOWED_ACTIONS" | tr ' ' '\n' | rg -qx "$ACTION"; then
  echo "action 不在标准列表中: $ACTION" >&2
  echo "允许的 action: $ALLOWED_ACTIONS" >&2
  exit 1
fi

SKILL_FILE="$DIR/SKILL.md"
if [[ ! -f "$SKILL_FILE" ]]; then
  echo "缺少文件: $SKILL_FILE" >&2
  exit 1
fi

FRONTMATTER="$(awk '
  NR==1 && $0=="---" { in_yaml=1; start=1; next }
  in_yaml && $0=="---" { end=1; in_yaml=0; exit }
  in_yaml { print }
  END {
    if (start!=1 || end!=1) exit 2
  }
' "$SKILL_FILE")" || {
  echo "Frontmatter 必须以 --- 开始并以 --- 结束" >&2
  exit 1
}

NAME_VALUE="$(printf "%s\n" "$FRONTMATTER" | sed -nE 's/^name:[[:space:]]*(.+)[[:space:]]*$/\1/p' | head -n1)"
DESC_VALUE="$(printf "%s\n" "$FRONTMATTER" | sed -nE 's/^description:[[:space:]]*(.+)[[:space:]]*$/\1/p' | head -n1)"

if [[ -z "$NAME_VALUE" || -z "$DESC_VALUE" ]]; then
  echo "Frontmatter 必须包含非空的 name 与 description" >&2
  exit 1
fi

EXTRA_KEYS="$(printf "%s\n" "$FRONTMATTER" | sed -nE 's/^([a-zA-Z0-9_-]+):.*$/\1/p' | rg -v '^(name|description)$' || true)"
if [[ -n "$EXTRA_KEYS" ]]; then
  echo "Frontmatter 仅允许 name 与 description，发现额外字段: $(echo "$EXTRA_KEYS" | tr '\n' ' ')" >&2
  exit 1
fi

if [[ "$NAME_VALUE" != "$BASE" ]]; then
  echo "name 字段必须与目录名一致: name=$NAME_VALUE, dir=$BASE" >&2
  exit 1
fi

if [[ ! "$NAME_VALUE" =~ ^[a-z0-9-]{1,64}$ ]]; then
  echo "name 必须匹配 ^[a-z0-9-]{1,64}$" >&2
  exit 1
fi

if [[ "$NAME_VALUE" != feipi-* ]]; then
  echo "name 必须以 feipi- 开头: $NAME_VALUE" >&2
  exit 1
fi

if printf "%s" "$NAME_VALUE" | rg -qi '(anthropic|claude)'; then
  echo "name 不能包含保留词 anthropic 或 claude" >&2
  exit 1
fi

if printf "%s" "$NAME_VALUE" | rg -q '<[^>]+>'; then
  echo "name 不能包含 XML 标签" >&2
  exit 1
fi

if printf "%s" "$DESC_VALUE" | rg -q '<[^>]+>'; then
  echo "description 不能包含 XML 标签" >&2
  exit 1
fi

if [[ ${#DESC_VALUE} -gt 1024 ]]; then
  echo "description 长度不能超过 1024 字符" >&2
  exit 1
fi

if printf "%s" "$DESC_VALUE" | rg -q '(我|我们|你|您)'; then
  echo "description 建议使用第三人称，避免“我/我们/你/您”" >&2
  exit 1
fi

BODY_LINES="$(awk '
  NR==1 && $0=="---" { in_yaml=1; next }
  in_yaml && $0=="---" { in_yaml=0; body=1; next }
  body { c++ }
  END { print c+0 }
' "$SKILL_FILE")"

if [[ "$BODY_LINES" -gt 500 ]]; then
  echo "SKILL.md 正文建议 <= 500 行，当前: $BODY_LINES" >&2
  exit 1
fi

if ! rg -Pq '\p{Han}' "$SKILL_FILE"; then
  echo "SKILL.md 必须包含中文内容（检测不到中文字符）" >&2
  exit 1
fi

if ! rg -q '(验证|校验|测试|验收)' "$SKILL_FILE"; then
  echo "SKILL.md 必须包含至少一种验证/校验/测试要求" >&2
  exit 1
fi

if rg -q '[A-Za-z]:\\|\\[A-Za-z0-9._-]+' "$SKILL_FILE"; then
  echo "SKILL.md 检测到 Windows 风格路径，请统一使用正斜杠" >&2
  exit 1
fi

if [[ -f "$DIR/agents/openai.yaml" ]]; then
  # 若存在 UI 元数据文件，则要求关键字段齐全。
  if ! rg -q '^interface:' "$DIR/agents/openai.yaml"; then
    echo "agents/openai.yaml 缺少 interface 根字段" >&2
    exit 1
  fi

  for k in display_name short_description default_prompt; do
    if ! rg -q "^[[:space:]]+$k:" "$DIR/agents/openai.yaml"; then
      echo "agents/openai.yaml 缺少 $k 字段" >&2
      exit 1
    fi
  done

  if ! rg -Pq '\p{Han}' "$DIR/agents/openai.yaml"; then
    echo "agents/openai.yaml 必须包含中文描述字段" >&2
    exit 1
  fi
fi

echo "校验通过: $DIR"
