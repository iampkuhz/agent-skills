#!/usr/bin/env bash
# FastMCP Gateway 后台启动脚本
#
# 用法：./start-background.sh
# 停止：pkill -f "runtimes.fastmcp.gateway"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"

mkdir -p "$LOG_DIR"

cd "$PROJECT_DIR/../.."

# 加载环境变量
if [ -f "$PROJECT_DIR/../../../.env" ]; then
    export $(grep -v '^#' "$PROJECT_DIR/../../../.env" | xargs)
fi

# 默认配置
export MCP_HOST="${MCP_HOST:-0.0.0.0}"
export MCP_PORT="${MCP_PORT:-18080}"
export MCP_LOG_LEVEL="${MCP_LOG_LEVEL:-INFO}"

echo "Starting Feipi Agent Kit MCP Gateway in background..."
echo "  Host: $MCP_HOST"
echo "  Port: $MCP_PORT"
echo "  Log file: $LOG_DIR/gateway.log"

env PYTHONPATH="$PROJECT_DIR/../..:$PYTHONPATH" nohup \
    python3 -m runtimes.fastmcp.gateway.server > "$LOG_DIR/gateway.log" 2>&1 &

PID=$!
echo $PID > "$LOG_DIR/gateway.pid"
echo "  PID: $PID"

# 等待 2 秒后检查进程状态
sleep 2
if ! ps -p $PID > /dev/null 2>&1; then
    echo "ERROR: Gateway failed to start. Check log file for details:"
    echo "  $LOG_DIR/gateway.log"
    exit 1
fi

echo ""
echo "Gateway started. Endpoint: http://localhost:$MCP_PORT/mcp"
echo "Use 'pkill -f runtimes.fastmcp.gateway' to stop."
