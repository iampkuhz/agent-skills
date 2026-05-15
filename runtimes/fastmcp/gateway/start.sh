#!/usr/bin/env bash
# FastMCP Gateway 启动脚本
#
# 用法：
#   前台启动：./start.sh
#   后台启动：./start.sh &

set -e

# 项目根目录（从脚本位置自动推算）
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$PROJECT_DIR"

# 加载环境变量
if [ -f "$PROJECT_DIR/.env" ]; then
    export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
fi

# 默认配置
export MCP_HOST="${MCP_HOST:-0.0.0.0}"
export MCP_PORT="${MCP_PORT:-18080}"
export MCP_LOG_LEVEL="${MCP_LOG_LEVEL:-INFO}"

echo "Starting Feipi Agent Kit MCP Gateway..."
echo "  Host: $MCP_HOST"
echo "  Port: $MCP_PORT"
echo "  Log Level: $MCP_LOG_LEVEL"
echo ""
echo "Hint: Use Ctrl+C to stop, or run './start.sh &' for background mode"
echo ""

# 使用 env 命令确保 PYTHONPATH 正确传递
exec env PYTHONPATH="$PROJECT_DIR:$PYTHONPATH" python3 -m runtimes.fastmcp.gateway.server
