#!/usr/bin/env bash
# FastMCP Gateway 启动脚本
#
# 用法：
#   前台启动：./start.sh
#   后台启动：./start.sh &

set -e

# 项目根目录（硬编码，确保路径正确）
PROJECT_DIR="/Users/zhehan/Documents/tools/llm/skills/feipi-agent-kit"

cd "$PROJECT_DIR"

# 加载环境变量
if [ -f "$PROJECT_DIR/.env" ]; then
    export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
fi

# 默认配置
export MCP_HOST="${MCP_HOST:-0.0.0.0}"
export MCP_PORT="${MCP_PORT:-18080}"
export MCP_LOG_LEVEL="${MCP_LOG_LEVEL:-INFO}"

echo "Starting Agent Skills MCP Gateway..."
echo "  Host: $MCP_HOST"
echo "  Port: $MCP_PORT"
echo "  Log Level: $MCP_LOG_LEVEL"
echo ""
echo "Hint: Use Ctrl+C to stop, or run './start.sh &' for background mode"
echo ""

# 使用 env 命令确保 PYTHONPATH 正确传递
exec env PYTHONPATH="$PROJECT_DIR:$PYTHONPATH" python3 -m runtimes.fastmcp.gateway.server
