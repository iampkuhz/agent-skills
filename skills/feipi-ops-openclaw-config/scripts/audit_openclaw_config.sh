#!/usr/bin/env bash
set -euo pipefail

# OpenClaw 配置审计脚本（仓库策略版）
# 目标：
# 1) 检测敏感字段是否使用 ${ENV_NAME} 引用
# 2) 检测是否残留已弃用路径
# 3) 检测常见字段类型是否合理

usage() {
  cat <<'USAGE'
用法:
  scripts/audit_openclaw_config.sh [--config <path>]

示例:
  scripts/audit_openclaw_config.sh --config ~/.openclaw/openclaw.json
USAGE
}

CONFIG="./openclaw.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "缺少依赖: jq" >&2
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  echo "配置文件不存在: $CONFIG" >&2
  exit 1
fi

if ! jq . "$CONFIG" >/dev/null 2>&1; then
  echo "配置文件不是合法 JSON: $CONFIG" >&2
  exit 1
fi

ERRORS=0
WARNS=0

report_error() {
  local msg="$1"
  echo "[ERROR] $msg" >&2
  ERRORS=$((ERRORS + 1))
}

report_warn() {
  local msg="$1"
  echo "[WARN] $msg"
  WARNS=$((WARNS + 1))
}

is_env_ref() {
  local v="$1"
  [[ "$v" =~ ^\$\{[A-Z0-9_]+\}$ ]]
}

# 1) 检测敏感字段是否明文。
while IFS=$'\t' read -r path type value; do
  lower_path="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"

  # 仅对字符串值审计明文风险。
  if [[ "$type" != "string" ]]; then
    continue
  fi

  if [[ "$lower_path" =~ (api.?key|token|password|secret|bot.?token|access.?key|auth\.token) ]]; then
    if ! is_env_ref "$value"; then
      report_error "检测到敏感字段疑似明文: $path=$value"
    fi
  fi
done < <(
  jq -r '
    paths(scalars) as $p
    | [($p | join(".")), (getpath($p) | type), (if (getpath($p) | type) == "string" then getpath($p) else (getpath($p) | tostring) end)]
    | @tsv
  ' "$CONFIG"
)

# 2) 检测已弃用路径痕迹（当前用户场景规则）。
if jq -e '.. | strings | select(test("/Users/zhehan/第二大脑"))' "$CONFIG" >/dev/null 2>&1; then
  report_error "检测到废弃路径 /Users/zhehan/第二大脑，请迁移到新的 Obsidian Vault 子目录"
fi

# 3) skills.load.extraDirs 类型检查（若配置存在）。
if jq -e '.skills.load.extraDirs? != null' "$CONFIG" >/dev/null 2>&1; then
  if ! jq -e '.skills.load.extraDirs | type == "array"' "$CONFIG" >/dev/null 2>&1; then
    report_error "skills.load.extraDirs 必须是数组"
  else
    while IFS= read -r item; do
      if [[ "$item" != "~/"* && "$item" != /* ]]; then
        report_warn "skills.load.extraDirs 建议使用绝对路径或 ~/ 开头: $item"
      fi
    done < <(jq -r '.skills.load.extraDirs[] | tostring' "$CONFIG")
  fi
fi

# 4) workspace 字段检查（若存在）。
if jq -e '.agents.defaults.workspace? != null' "$CONFIG" >/dev/null 2>&1; then
  workspace="$(jq -r '.agents.defaults.workspace' "$CONFIG")"
  if [[ -z "$workspace" || "$workspace" == "null" ]]; then
    report_error "agents.defaults.workspace 不能为空"
  fi
fi

echo "审计完成: config=$CONFIG, errors=$ERRORS, warns=$WARNS"

if [[ "$ERRORS" -gt 0 ]]; then
  exit 2
fi

echo "审计通过"
