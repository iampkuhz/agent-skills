#!/usr/bin/env bash
set -euo pipefail

# 自动调用 PlantUML 渲染器执行语法检查。
# 默认策略：按候选列表顺序尝试，直到首个可用 server。

usage() {
  cat <<'USAGE'
用法:
  scripts/check_plantuml.sh <input.puml> [--svg-output <path>] [--server-url <url>|auto]
                            [--servers-config <path>] [--append-server <url>] [--timeout <sec>]
                            [--skip-layout-lint]

环境变量:
  AGENT_PLANTUML_SERVER_PORT   本地 server 端口，默认 8199

示例:
  bash scripts/check_plantuml.sh ./tmp/diagram.puml
  bash scripts/check_plantuml.sh ./tmp/diagram.puml --svg-output ./tmp/diagram.svg
  bash scripts/check_plantuml.sh ./tmp/diagram.puml --servers-config ./assets/server_candidates.txt
  bash scripts/check_plantuml.sh ./tmp/diagram.puml --server-url http://127.0.0.1:8080/plantuml
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_SERVERS_CONFIG="$SKILL_DIR/assets/server_candidates.txt"
DEFAULT_TIMEOUT=20
DEFAULT_LOCAL_PORT="${AGENT_PLANTUML_SERVER_PORT:-8199}"

trim() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

normalize_server_url() {
  local raw="$1"
  local cleaned
  cleaned="$(trim "$raw")"
  cleaned="${cleaned%/}"
  if [[ -z "$cleaned" ]]; then
    return 1
  fi
  if [[ "$cleaned" =~ /plantuml$ ]]; then
    printf '%s\n' "$cleaned"
  else
    printf '%s/plantuml\n' "$cleaned"
  fi
}

CANDIDATES=()

append_candidate() {
  local raw="$1"
  local candidate
  if ! candidate="$(normalize_server_url "$raw")"; then
    return 0
  fi

  local item
  for item in "${CANDIDATES[@]:-}"; do
    if [[ "$item" == "$candidate" ]]; then
      return 0
    fi
  done
  CANDIDATES+=("$candidate")
}

load_candidates() {
  local config_file="$1"
  shift
  local extra_servers=("$@")
  local local_port="$DEFAULT_LOCAL_PORT"

  if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [[ "$local_port" -lt 1 ]] || [[ "$local_port" -gt 65535 ]]; then
    echo "环境变量 AGENT_PLANTUML_SERVER_PORT 必须是 1-65535 的整数，当前: $local_port" >&2
    exit 1
  fi

  expand_port_placeholder() {
    local raw_line="$1"
    local expanded="$raw_line"
    expanded="${expanded//\$\{AGENT_PLANTUML_SERVER_PORT\}/$local_port}"
    expanded="${expanded//\$AGENT_PLANTUML_SERVER_PORT/$local_port}"
    printf '%s\n' "$expanded"
  }

  if [[ -n "$config_file" && -f "$config_file" ]]; then
    while IFS= read -r raw || [[ -n "$raw" ]]; do
      local line
      line="${raw%%#*}"
      line="$(trim "$line")"
      [[ -z "$line" ]] && continue
      line="$(expand_port_placeholder "$line")"
      append_candidate "$line"
    done < "$config_file"
  else
    # 配置缺失时使用内置默认列表（顺序与 assets/server_candidates.txt 一致）。
    append_candidate "http://127.0.0.1:${local_port}/plantuml"
    append_candidate "http://localhost:${local_port}/plantuml"
    append_candidate "https://www.plantuml.com/plantuml"
    append_candidate "https://www.planttext.com/api/plantuml"
    append_candidate "https://www.planttext.com/plantuml"
    append_candidate "https://kroki.io/plantuml"
  fi

  # CLI 显式追加候选。
  local extra
  for extra in "${extra_servers[@]}"; do
    append_candidate "$extra"
  done
}

encode_plantuml_file() {
  local input_file="$1"
  python3 - "$input_file" <<'PY'
import sys
import zlib
from pathlib import Path

ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"


def encode6bit(value: int) -> str:
    if value < 10:
        return chr(48 + value)
    value -= 10
    if value < 26:
        return chr(65 + value)
    value -= 26
    if value < 26:
        return chr(97 + value)
    value -= 26
    if value == 0:
        return "-"
    if value == 1:
        return "_"
    return "?"


def append3bytes(b1: int, b2: int, b3: int) -> str:
    c1 = b1 >> 2
    c2 = ((b1 & 0x3) << 4) | (b2 >> 4)
    c3 = ((b2 & 0xF) << 2) | (b3 >> 6)
    c4 = b3 & 0x3F
    return "".join(
        [
            encode6bit(c1 & 0x3F),
            encode6bit(c2 & 0x3F),
            encode6bit(c3 & 0x3F),
            encode6bit(c4 & 0x3F),
        ]
    )


def encode_plantuml_text(text: bytes) -> str:
    compressor = zlib.compressobj(level=9, wbits=-15)
    compressed = compressor.compress(text) + compressor.flush()

    out = []
    for idx in range(0, len(compressed), 3):
        chunk = compressed[idx : idx + 3]
        if len(chunk) == 3:
            out.append(append3bytes(chunk[0], chunk[1], chunk[2]))
        elif len(chunk) == 2:
            out.append(append3bytes(chunk[0], chunk[1], 0))
        else:
            out.append(append3bytes(chunk[0], 0, 0))
    return "".join(out)


try:
    p = Path(sys.argv[1])
    data = p.read_bytes()
    print(encode_plantuml_text(data))
except Exception as exc:
    print(f"编码失败: {exc}", file=sys.stderr)
    sys.exit(1)
PY
}

LAST_CHECK_ERROR=""
LAST_SYNTAX_MSG=""

check_on_server() {
  local server_url="$1"
  local encoded="$2"
  local svg_output="$3"
  local timeout_sec="$4"

  LAST_CHECK_ERROR=""
  LAST_SYNTAX_MSG=""

  local txt_body_file txt_status_file txt_err_file
  txt_body_file="$(mktemp)"
  txt_status_file="$(mktemp)"
  txt_err_file="$(mktemp)"

  if ! curl -sS --max-time "$timeout_sec" \
    -o "$txt_body_file" \
    -w '%{http_code}' \
    "$server_url/txt/$encoded" >"$txt_status_file" 2>"$txt_err_file"; then
    LAST_CHECK_ERROR="$(cat "$txt_err_file")"
    rm -f "$txt_body_file" "$txt_status_file" "$txt_err_file"
    return 10
  fi

  local txt_status txt_body
  txt_status="$(cat "$txt_status_file")"
  txt_body="$(cat "$txt_body_file")"
  rm -f "$txt_status_file" "$txt_err_file" "$txt_body_file"

  if [[ ! "$txt_status" =~ ^[0-9]{3}$ ]]; then
    LAST_CHECK_ERROR="txt 接口返回非法状态码: $txt_status"
    return 11
  fi

  if [[ "$txt_status" -ge 500 || "$txt_status" -eq 404 || "$txt_status" -eq 000 ]]; then
    LAST_CHECK_ERROR="txt 接口不可用，HTTP $txt_status"
    return 12
  fi

  if printf '%s\n' "$txt_body" | grep -Eqi 'Syntax Error\?|\[From string \(line'; then
    LAST_SYNTAX_MSG="$txt_body"
    return 2
  fi

  local svg_body_file svg_status_file svg_err_file
  svg_body_file="$(mktemp)"
  svg_status_file="$(mktemp)"
  svg_err_file="$(mktemp)"

  if ! curl -sS --max-time "$timeout_sec" \
    -o "$svg_body_file" \
    -w '%{http_code}' \
    "$server_url/svg/$encoded" >"$svg_status_file" 2>"$svg_err_file"; then
    LAST_CHECK_ERROR="$(cat "$svg_err_file")"
    rm -f "$svg_body_file" "$svg_status_file" "$svg_err_file"
    return 13
  fi

  local svg_status
  svg_status="$(cat "$svg_status_file")"
  rm -f "$svg_status_file" "$svg_err_file"

  if [[ ! "$svg_status" =~ ^[0-9]{3}$ ]]; then
    LAST_CHECK_ERROR="svg 接口返回非法状态码: $svg_status"
    rm -f "$svg_body_file"
    return 14
  fi

  if [[ "$svg_status" -eq 400 ]]; then
    local svg_body
    svg_body="$(cat "$svg_body_file")"
    if printf '%s\n' "$svg_body" | grep -Eqi 'syntax|error'; then
      LAST_SYNTAX_MSG="$svg_body"
      rm -f "$svg_body_file"
      return 2
    fi
    LAST_CHECK_ERROR="svg 接口返回 HTTP 400"
    rm -f "$svg_body_file"
    return 15
  fi

  if [[ "$svg_status" -ne 200 ]]; then
    LAST_CHECK_ERROR="svg 接口不可用，HTTP $svg_status"
    rm -f "$svg_body_file"
    return 16
  fi

  if ! grep -Eqi '<svg[[:space:]>]' "$svg_body_file"; then
    LAST_CHECK_ERROR="svg 接口响应不含 <svg>，可能不是 PlantUML 渲染结果"
    rm -f "$svg_body_file"
    return 17
  fi

  mv "$svg_body_file" "$svg_output"
  return 0
}

INPUT_FILE=""
SERVER_URL="auto"
SERVERS_CONFIG="$DEFAULT_SERVERS_CONFIG"
EXTRA_SERVERS=()
SVG_OUTPUT=""
TIMEOUT_SEC="$DEFAULT_TIMEOUT"
SKIP_LAYOUT_LINT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-url)
      SERVER_URL="$2"
      shift 2
      ;;
    --servers-config)
      SERVERS_CONFIG="$2"
      shift 2
      ;;
    --append-server)
      EXTRA_SERVERS+=("$2")
      shift 2
      ;;
    # 兼容旧参数：内部统一并入候选列表。
    --local-config)
      SERVERS_CONFIG="$2"
      shift 2
      ;;
    --public-server)
      EXTRA_SERVERS+=("$2")
      shift 2
      ;;
    --svg-output)
      SVG_OUTPUT="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SEC="$2"
      shift 2
      ;;
    --skip-layout-lint)
      SKIP_LAYOUT_LINT=1
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$INPUT_FILE" ]]; then
        INPUT_FILE="$1"
        shift 1
      else
        echo "未知参数: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$INPUT_FILE" ]]; then
  echo "缺少输入文件: input.puml" >&2
  usage
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "输入文件不存在: $INPUT_FILE" >&2
  exit 1
fi

if ! [[ "$TIMEOUT_SEC" =~ ^[0-9]+$ ]] || [[ "$TIMEOUT_SEC" -lt 1 ]]; then
  echo "--timeout 必须是正整数秒" >&2
  exit 1
fi

if ! grep -Eqi '^[[:space:]]*@startuml' "$INPUT_FILE"; then
  echo "输入文件缺少 @startuml" >&2
  exit 1
fi

if ! grep -Eqi '^[[:space:]]*@enduml' "$INPUT_FILE"; then
  echo "输入文件缺少 @enduml" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "缺少依赖: curl" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "缺少依赖: python3" >&2
  exit 1
fi

if [[ "$SKIP_LAYOUT_LINT" -eq 0 ]]; then
  set +e
  "$SCRIPT_DIR/lint_layout.sh" "$INPUT_FILE"
  lint_code=$?
  set -e
  if [[ "$lint_code" -ne 0 ]]; then
    exit "$lint_code"
  fi
fi

if [[ -z "$SVG_OUTPUT" ]]; then
  if [[ "$INPUT_FILE" == *.* ]]; then
    SVG_OUTPUT="${INPUT_FILE%.*}.svg"
  else
    SVG_OUTPUT="$INPUT_FILE.svg"
  fi
fi

mkdir -p "$(dirname "$SVG_OUTPUT")"

if ! ENCODED="$(encode_plantuml_file "$INPUT_FILE")"; then
  echo "PlantUML 文本编码失败" >&2
  exit 1
fi

if [[ -z "$ENCODED" ]]; then
  echo "PlantUML 编码结果为空" >&2
  exit 1
fi

report_syntax_error() {
  local mode="$1"
  local url="$2"
  echo "server_url=$url"
  echo "server_mode=$mode"
  echo "syntax_result=error"
  if [[ -n "$LAST_SYNTAX_MSG" ]]; then
    echo "syntax_message_start"
    printf '%s\n' "$LAST_SYNTAX_MSG"
    echo "syntax_message_end"
  fi
}

if [[ "$SERVER_URL" != "auto" ]]; then
  CHOSEN_SERVER="$(normalize_server_url "$SERVER_URL")"
  if check_on_server "$CHOSEN_SERVER" "$ENCODED" "$SVG_OUTPUT" "$TIMEOUT_SEC"; then
    echo "server_url=$CHOSEN_SERVER"
    echo "server_mode=custom"
    echo "syntax_result=ok"
    echo "svg_output=$SVG_OUTPUT"
    exit 0
  else
    code=$?
    if [[ "$code" -eq 2 ]]; then
      report_syntax_error "custom" "$CHOSEN_SERVER"
      exit 2
    fi

    echo "渲染失败: $CHOSEN_SERVER" >&2
    if [[ -n "$LAST_CHECK_ERROR" ]]; then
      echo "$LAST_CHECK_ERROR" >&2
    fi
    exit 1
  fi
fi

load_candidates "$SERVERS_CONFIG" "${EXTRA_SERVERS[@]-}"

SERVER_ERRORS=()
for candidate in "${CANDIDATES[@]:-}"; do
  if check_on_server "$candidate" "$ENCODED" "$SVG_OUTPUT" "$TIMEOUT_SEC"; then
    echo "server_url=$candidate"
    echo "server_mode=ordered"
    echo "syntax_result=ok"
    echo "svg_output=$SVG_OUTPUT"
    exit 0
  else
    code=$?
    if [[ "$code" -eq 2 ]]; then
      report_syntax_error "ordered" "$candidate"
      exit 2
    fi

    if [[ -n "$LAST_CHECK_ERROR" ]]; then
      SERVER_ERRORS+=("$candidate => $LAST_CHECK_ERROR")
    else
      SERVER_ERRORS+=("$candidate => 未知错误")
    fi
  fi
done

echo "渲染失败：候选列表中的 server 全部不可用" >&2
if [[ ${#SERVER_ERRORS[@]} -gt 0 ]]; then
  echo "候选失败详情:" >&2
  printf '  - %s\n' "${SERVER_ERRORS[@]}" >&2
  if printf '%s\n' "${SERVER_ERRORS[@]}" | grep -q 'HTTP 509'; then
    echo "提示: 检测到 HTTP 509，可能触发公网实例限流，脚本已自动尝试候选列表中的备用 server。" >&2
  fi
fi
exit 1
