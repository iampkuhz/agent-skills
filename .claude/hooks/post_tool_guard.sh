#!/usr/bin/env bash
# PostToolUse(Edit/Write/Bash) — 规约文件写入后质量门禁
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# 从环境变量或参数获取被修改的文件路径
MODIFIED_FILE="${CLAUDE_FILE_PATH:-${CC_FILE_PATH:-${1:-}}}"
[[ -z "$MODIFIED_FILE" ]] && exit $EXIT_SKIP

case "$MODIFIED_FILE" in
  */SKILL.md)
    hook_log "INFO" "SKILL.md 质量门禁: $MODIFIED_FILE"
    FAIL=0

    # frontmatter 检查
    if ! head -1 "$MODIFIED_FILE" 2>/dev/null | grep -q '^---$'; then
      hook_log "WARN" "SKILL.md 不以 --- 开头: $MODIFIED_FILE"
      FAIL=1
    fi
    if ! head -5 "$MODIFIED_FILE" 2>/dev/null | grep -qE '^name:[[:space:]]+.+'; then
      hook_log "WARN" "SKILL.md 缺少 name 字段: $MODIFIED_FILE"
      FAIL=1
    fi
    if ! head -5 "$MODIFIED_FILE" 2>/dev/null | grep -qE '^description:[[:space:]]+.+'; then
      hook_log "WARN" "SKILL.md 缺少 description 字段: $MODIFIED_FILE"
      FAIL=1
    fi

    # 模板占位符残留
    if grep -q '{{' "$MODIFIED_FILE" 2>/dev/null; then
      hook_log "WARN" "SKILL.md 包含未替换占位符: $MODIFIED_FILE"
      FAIL=1
    fi

    if [[ "$HOOK_DRY_RUN" == "1" ]]; then
      hook_log "DRY-RUN" "结果: $([[ $FAIL -eq 0 ]] && echo '通过' || echo '有告警，但未阻塞')"
      exit $EXIT_WARN
    fi

    [[ $FAIL -ne 0 ]] && exit $EXIT_BLOCK
    exit $EXIT_OK
    ;;

  *.sh)
    hook_log "INFO" "Shell 语法检查: $MODIFIED_FILE"
    if [[ -f "$MODIFIED_FILE" ]]; then
      if ! bash -n "$MODIFIED_FILE" 2>&1; then
        hook_log "WARN" "Shell 语法错误: $MODIFIED_FILE"
        [[ "$HOOK_DRY_RUN" == "1" ]] && exit $EXIT_WARN
        exit $EXIT_BLOCK
      fi
    fi
    exit $EXIT_OK
    ;;

  */openai.yaml|*/openai.yml)
    hook_log "INFO" "YAML 结构检查: $MODIFIED_FILE"
    if [[ -f "$MODIFIED_FILE" ]]; then
      if ! python3 -c "import yaml; yaml.safe_load(open('$MODIFIED_FILE'))" 2>&1; then
        hook_log "WARN" "YAML 解析失败: $MODIFIED_FILE"
        [[ "$HOOK_DRY_RUN" == "1" ]] && exit $EXIT_WARN
        exit $EXIT_BLOCK
      fi
    fi
    exit $EXIT_OK
    ;;

  */templates/*)
    if grep -q '{{' "$MODIFIED_FILE" 2>/dev/null; then
      hook_log "WARN" "模板文件包含未替换占位符（可能误用 Write）: $MODIFIED_FILE"
      [[ "$HOOK_DRY_RUN" == "1" ]] && exit $EXIT_WARN
      exit $EXIT_WARN
    fi
    exit $EXIT_OK
    ;;

  *)
    exit $EXIT_SKIP
    ;;
esac
