#!/usr/bin/env bash
set -euo pipefail

# 校验创新提案交底书格式与硬约束。
# 用法：bash scripts/check_disclosure_format.sh <markdown-file>

usage() {
  cat <<'USAGE'
用法:
  scripts/check_disclosure_format.sh <markdown-file>

示例:
  scripts/check_disclosure_format.sh ./tmp/innovation/disclosure.md
USAGE
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

DOC="$1"
if [[ ! -f "$DOC" ]]; then
  echo "文件不存在: $DOC" >&2
  exit 1
fi

FAILED=0
WARNED=0

err() {
  echo "[ERROR] $1" >&2
  FAILED=1
}

warn() {
  echo "[WARN] $1"
  WARNED=1
}

require_heading() {
  local heading="$1"
  if ! rg -Fxq "$heading" "$DOC"; then
    err "缺少章节标题: $heading"
  fi
}

extract_section() {
  local heading="$1"
  local capture=0
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$capture" -eq 0 ]]; then
      if [[ "$line" == "$heading" ]]; then
        capture=1
      fi
      continue
    fi

    if [[ "$line" =~ ^#[#]?[#]?[[:space:]] ]]; then
      break
    fi
    printf "%s\n" "$line"
  done < "$DOC"
}

extract_subsection_from_content() {
  local content="$1"
  local heading="$2"
  local capture=0
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$capture" -eq 0 ]]; then
      if [[ "$line" == "$heading" ]]; then
        capture=1
      fi
      continue
    fi

    if [[ "$line" =~ ^####[[:space:]] ]]; then
      break
    fi
    printf "%s\n" "$line"
  done <<< "$content"
}

content_without_code() {
  awk '
    BEGIN { in_code = 0 }
    /^```/ { in_code = !in_code; next }
    in_code { next }
    { print }
  ' "$DOC"
}

count_chars() {
  local content="$1"
  # 章节无有效内容时直接返回 0，避免被末尾换行计为 1。
  if [[ -z "$(printf "%s" "$content" | tr -d '[:space:]')" ]]; then
    echo "0"
    return
  fi

  printf "%s\n" "$content" | awk '
    BEGIN { in_code = 0 }
    /^```/ { in_code = !in_code; next }
    in_code { next }
    {
      line = $0
      sub(/^[[:space:]]*[-*][[:space:]]+/, "", line)
      sub(/^[[:space:]]*[0-9]+[.)][[:space:]]+/, "", line)
      sub(/^[[:space:]]*>[[:space:]]*/, "", line)
      gsub(/[[:space:]]/, "", line)
      printf "%s", line
    }
  ' | wc -m | awk '{print $1}'
}

count_list_items() {
  local content="$1"
  local matches
  matches="$(printf "%s\n" "$content" | rg '^[[:space:]]*(-|\*|[0-9]+[.)])[[:space:]]+' || true)"
  printf "%s\n" "$matches" | sed '/^[[:space:]]*$/d' | wc -l | awk '{print $1}'
}

check_limit() {
  local heading="$1"
  local max_chars="$2"
  local optional="${3:-0}"
  local content
  local chars

  content="$(extract_section "$heading")"
  chars="$(count_chars "$content")"

  if [[ "$optional" -eq 0 && "$chars" -eq 0 ]]; then
    err "章节内容为空: $heading"
    return
  fi

  if [[ "$chars" -gt "$max_chars" ]]; then
    err "章节超出字数上限: $heading (当前=$chars, 上限=$max_chars)"
    return
  fi

  echo "[OK] $heading 字数=$chars/$max_chars"
}

check_list_range() {
  local heading="$1"
  local min_count="$2"
  local max_count="$3"
  local allow_empty_token="${4:-0}"
  local content
  local compact
  local count

  content="$(extract_section "$heading")"
  compact="$(printf "%s\n" "$content" | tr -d '[:space:]')"
  if [[ "$allow_empty_token" -eq 1 ]]; then
    if [[ "$compact" == "无" || "$compact" == "暂无" || "$compact" == "无其他方案" || -z "$compact" ]]; then
      echo "[OK] $heading 允许为空或“无”"
      return
    fi
  fi

  count="$(count_list_items "$content")"
  if [[ "$count" -lt "$min_count" || "$count" -gt "$max_count" ]]; then
    err "$heading 列表条目应为 $min_count-$max_count 条，当前=$count"
    return
  fi

  echo "[OK] $heading 列表条目数=$count"
}

check_no_second_level_list() {
  local heading="$1"
  local content
  content="$(extract_section "$heading")"
  if printf "%s\n" "$content" | rg -q '^[[:space:]]{2,}(-|\*|[0-9]+[.)])[[:space:]]+'; then
    err "$heading 只允许一层列表，检测到二层列表"
  else
    echo "[OK] $heading 未检测到二层列表"
  fi
}

check_bold_summary_format() {
  local heading="$1"
  local content
  local lines
  local bad_lines=""
  content="$(extract_section "$heading")"
  lines="$(printf "%s\n" "$content" | rg '^[[:space:]]*[0-9]+[.)][[:space:]]+' || true)"

  if [[ -z "$(printf "%s\n" "$lines" | sed '/^[[:space:]]*$/d')" ]]; then
    err "$heading 缺少编号条目"
    return
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    if ! printf "%s\n" "$line" | rg -q '^[[:space:]]*[0-9]+[.)][[:space:]]+\*\*[^*]+\*\*[:：]'; then
      bad_lines="${bad_lines}${line}\n"
    fi
  done <<< "$lines"

  if [[ -n "$bad_lines" ]]; then
    err "$heading 存在不符合“[序号] **摘要**：描述”格式的条目"
  else
    echo "[OK] $heading 条目格式正确"
  fi
}

FIRST_LINE="$(sed -n '1p' "$DOC" | tr -d '\r')"
if [[ ! "$FIRST_LINE" =~ ^#\ 一种.+(方法/系统|方法|系统)$ ]]; then
  err "标题必须为 '# 一种XXX方法/系统' 形式"
fi
if [[ "$FIRST_LINE" == *"{{"* || "$FIRST_LINE" == *"XXX"* ]]; then
  err "标题仍包含占位符，请替换为真实专利名"
fi

HEADINGS=(
  "## 基本信息"
  "### 申请说明"
  "## 提案内容"
  "### 术语解释"
  "### 关键词"
  "### 应用本方案的产品"
  "### 本方案的背景是什么"
  "### 行业内哪些竞争对手的业务、产品和本方案相关？请列出竞争对手的名称和相关业务、产品的名称（如有多个请一并列出）"
  "### 本方案是否有敏感的部分不适合作为专利申请公开？"
  "### 详细介绍与本方案相似的方案及其缺点"
  "### 详细描述本方案，包括组合部分、步骤"
  "### 是否还有其他解决方案，如有，请详细说明"
  "### 技术效果总结"
  "### 提炼本方案的关键技术创新点"
)

for heading in "${HEADINGS[@]}"; do
  require_heading "$heading"
done

# 字数硬约束（单一真源）
check_limit "### 申请说明" 1000
check_limit "### 术语解释" 1000
check_limit "### 关键词" 200
check_limit "### 应用本方案的产品" 100
check_limit "### 本方案的背景是什么" 2000
check_limit "### 行业内哪些竞争对手的业务、产品和本方案相关？请列出竞争对手的名称和相关业务、产品的名称（如有多个请一并列出）" 400
check_limit "### 本方案是否有敏感的部分不适合作为专利申请公开？" 400 1
check_limit "### 详细介绍与本方案相似的方案及其缺点" 1000
check_limit "### 详细描述本方案，包括组合部分、步骤" 5000
check_limit "### 是否还有其他解决方案，如有，请详细说明" 1000
check_limit "### 技术效果总结" 1000
check_limit "### 提炼本方案的关键技术创新点" 5000

# 列表与章节结构约束
check_list_range "### 申请说明" 3 6
check_no_second_level_list "### 申请说明"
check_list_range "### 本方案的背景是什么" 3 20
check_list_range "### 行业内哪些竞争对手的业务、产品和本方案相关？请列出竞争对手的名称和相关业务、产品的名称（如有多个请一并列出）" 2 3
check_list_range "### 详细介绍与本方案相似的方案及其缺点" 2 3
check_list_range "### 技术效果总结" 1 3
check_list_range "### 提炼本方案的关键技术创新点" 1 10
check_bold_summary_format "### 技术效果总结"
check_bold_summary_format "### 提炼本方案的关键技术创新点"

# 术语解释：5-10 条，禁止机械模板
TERMS_CONTENT="$(extract_section "### 术语解释")"
TERMS_COUNT="$(count_list_items "$TERMS_CONTENT")"
if [[ "$TERMS_COUNT" -lt 5 || "$TERMS_COUNT" -gt 10 ]]; then
  err "术语解释应包含 5-10 条术语，当前=$TERMS_COUNT"
else
  echo "[OK] 术语条目数=$TERMS_COUNT"
fi

if printf "%s\n" "$TERMS_CONTENT" | rg -q '标准术语=|本方案含义=|差异点='; then
  err "术语解释检测到机械模板（标准术语= / 本方案含义= / 差异点=）"
fi

# 关键词 5-10 条
KEYWORDS_CONTENT="$(extract_section "### 关键词")"
KEYWORDS_COUNT="$(count_list_items "$KEYWORDS_CONTENT")"
if [[ "$KEYWORDS_COUNT" -lt 5 || "$KEYWORDS_COUNT" -gt 10 ]]; then
  err "关键词应包含 5-10 条词组，当前=$KEYWORDS_COUNT"
else
  echo "[OK] 关键词条目数=$KEYWORDS_COUNT"
fi

# 其他方案：1-4 条，且应为本方案变体
check_list_range "### 是否还有其他解决方案，如有，请详细说明" 1 4 1
ALTERNATIVE_CONTENT="$(extract_section "### 是否还有其他解决方案，如有，请详细说明")"
if [[ "$(printf "%s\n" "$ALTERNATIVE_CONTENT" | tr -d '[:space:]')" != "无" ]]; then
  if ! printf "%s\n" "$ALTERNATIVE_CONTENT" | rg -q '(变体|替换|调整|简化|改为|仍可达到)'; then
    err "“其他解决方案”应描述本方案变体，需包含变体特征词"
  fi
fi

# 详细描述：固定顺序与一致性约束
DETAIL_CONTENT="$(extract_section "### 详细描述本方案，包括组合部分、步骤")"
DETAIL_CHARS="$(count_chars "$DETAIL_CONTENT")"
if [[ "$DETAIL_CHARS" -lt 1000 || "$DETAIL_CHARS" -gt 1500 ]]; then
  warn "详细描述建议控制在 1000-1500 字，当前=$DETAIL_CHARS"
else
  echo "[OK] 详细描述字数位于建议区间: $DETAIL_CHARS"
fi

DETAIL_SUBHEADINGS=(
  "#### 技术本质与价值"
  "#### 模块图"
  "#### 模块说明"
  "#### 主流程（最常见场景）"
  "#### 核心创新展开"
)
for sub in "${DETAIL_SUBHEADINGS[@]}"; do
  if ! printf "%s\n" "$DETAIL_CONTENT" | rg -Fxq "$sub"; then
    err "详细描述缺少小节: $sub"
  fi
done

MODULE_DESC="$(extract_subsection_from_content "$DETAIL_CONTENT" "#### 模块说明")"
MODULE_COUNT="$(count_list_items "$MODULE_DESC")"
if [[ "$MODULE_COUNT" -lt 3 ]]; then
  err "模块说明至少需要 3 条列表，当前=$MODULE_COUNT"
else
  echo "[OK] 模块说明条目数=$MODULE_COUNT"
fi

FLOW_CONTENT="$(extract_subsection_from_content "$DETAIL_CONTENT" "#### 主流程（最常见场景）")"
FLOW_COUNT="$(count_list_items "$FLOW_CONTENT")"
if [[ "$FLOW_COUNT" -lt 6 ]]; then
  err "主流程至少需要 6 条步骤，当前=$FLOW_COUNT"
else
  echo "[OK] 主流程条目数=$FLOW_COUNT"
fi

FLOW_NUMBERED_LINES="$(printf "%s\n" "$FLOW_CONTENT" | rg '^[[:space:]]*[0-9]+[.)][[:space:]]+S[0-9]+' || true)"
FLOW_NUMBERED_COUNT="$(printf "%s\n" "$FLOW_NUMBERED_LINES" | sed '/^[[:space:]]*$/d' | wc -l | awk '{print $1}')"
if [[ "$FLOW_NUMBERED_COUNT" -lt 6 ]]; then
  err "主流程每步应以 S 序号开头（如 S1），当前符合条目=$FLOW_NUMBERED_COUNT"
else
  echo "[OK] 主流程 S 序号条目数=$FLOW_NUMBERED_COUNT"
fi

DIAGRAM_MATCHES="$(printf "%s\n" "$DETAIL_CONTENT" | rg -o '@startuml' || true)"
DIAGRAM_COUNT="$(printf "%s\n" "$DIAGRAM_MATCHES" | sed '/^[[:space:]]*$/d' | wc -l | awk '{print $1}')"
if [[ "$DIAGRAM_COUNT" -lt 1 ]]; then
  err "详细描述章节至少包含 1 个图（PlantUML 代码块）"
elif [[ "$DIAGRAM_COUNT" -lt 2 ]]; then
  warn "图数量为 1，满足最低要求；建议提升到 2 个图"
else
  echo "[OK] 图数量=$DIAGRAM_COUNT"
fi

DIAGRAM_SNUM_COUNT="$(printf "%s\n" "$DETAIL_CONTENT" | rg -o 'S[0-9]+' | sed '/^[[:space:]]*$/d' | wc -l | awk '{print $1}')"
if [[ "$DIAGRAM_SNUM_COUNT" -lt 6 ]]; then
  err "图示与正文应使用 S 序号，检测到的 S 序号数量不足: $DIAGRAM_SNUM_COUNT"
else
  echo "[OK] 检测到 S 序号数量=$DIAGRAM_SNUM_COUNT"
fi

# 套话检查（不含代码块）
DOC_TEXT_NO_CODE="$(content_without_code)"
BANNED_PHRASES=(
  "赋能"
  "全方位"
  "行业领先"
  "端到端"
  "生态闭环"
  "大而全"
  "高效协同"
  "全面提升"
)
for phrase in "${BANNED_PHRASES[@]}"; do
  if printf "%s\n" "$DOC_TEXT_NO_CODE" | rg -Fq "$phrase"; then
    err "检测到套话/大话表达：$phrase"
  fi
done

if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi

if [[ "$WARNED" -ne 0 ]]; then
  echo "校验通过（含警告）: $DOC"
else
  echo "校验通过: $DOC"
fi
