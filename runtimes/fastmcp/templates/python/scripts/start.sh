#!/usr/bin/env bash
# MCP 服务启动脚本（统一模式）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# 加载环境变量（如果存在）
if [ -f "$PROJECT_DIR/.env" ]; then
    export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
fi

# 默认值
SERVICE_NAME="{{service_name}}"
PREFIX="${SERVICE_NAME//-/_}"
PREFIX_UPPER=$(echo "$PREFIX" | tr '[:lower:]' '[:upper:]')

HOST_VAR="${PREFIX_UPPER}_HOST"
PORT_VAR="${PREFIX_UPPER}_PORT"
LOG_VAR="${PREFIX_UPPER}_LOG_LEVEL"

export ${HOST_VAR}="${!HOST_VAR:-0.0.0.0}"
export ${PORT_VAR}="${!PORT_VAR:-8000}"
export ${LOG_VAR}="${!LOG_VAR:-INFO}"

echo "Starting ${SERVICE_NAME}..."
echo "  Host: ${!HOST_VAR}"
echo "  Port: ${!PORT_VAR}"
echo "  Log Level: ${!LOG_VAR}"

python3 src/server.py
