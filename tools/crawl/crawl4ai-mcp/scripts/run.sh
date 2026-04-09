#!/bin/bash
# Crawl4AI MCP Service 运行脚本（占位）
# 用法：./run.sh [stdio|http|test]
# 状态：⏳ 预留位置，待实现

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/env/.env"

cd "$PROJECT_DIR"

echo "⏳ Crawl4AI MCP 服务尚未实现"
echo ""
echo "计划功能："
echo "  1. fetch_url - 抓取指定 URL，返回清理后的内容"
echo "  2. extract_structured - 按 schema 提取结构化数据"
echo ""
echo "与 searxng-mcp 的协同："
echo "  1. 先用 searxng-mcp 搜索相关 URL"
echo "  2. 再用 crawl4ai-mcp 提取页面内容"
echo ""

case "${1:-help}" in
  stdio)
    echo "Crawl4AI MCP 暂未实现（Stdio 模式）"
    ;;

  http)
    echo "Crawl4AI MCP 暂未实现（HTTP 模式）"
    ;;

  test)
    echo "Crawl4AI MCP 暂未实现（测试）"
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
