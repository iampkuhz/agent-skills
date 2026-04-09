#!/bin/bash
# SearXNG MCP Service 运行脚本
# 用法：./run.sh [stdio|http|test]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/env/.env"

cd "$PROJECT_DIR"

# 加载环境变量
if [[ -f "$ENV_FILE" ]]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

case "${1:-stdio}" in
  stdio)
    echo "🚀 启动 SearXNG MCP (Stdio 模式)..."
    echo "📌 此模式用于 Claude Code MCP 集成"
    uv run python src/server.py
    ;;

  http)
    echo "🚀 启动 SearXNG MCP (Streamable HTTP 模式)..."
    echo "📌 访问地址：http://localhost:${SEARXNG_MCP_PORT:-8888}"
    uv run python -m fastmcp.server src/server.py \
      --transport streamable-http \
      --port ${SEARXNG_MCP_PORT:-8888}
    ;;

  test)
    echo "🧪 运行测试..."
    uv run pytest tests/ -v
    ;;

  *)
    echo "用法：$0 {stdio|http|test}"
    echo ""
    echo "模式说明："
    echo "  stdio  - 通过 stdin/stdout 通信（Claude Code 推荐）"
    echo "  http   - 通过 HTTP 通信（独立服务模式）"
    echo "  test   - 运行测试套件"
    exit 1
    ;;
esac
