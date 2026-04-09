#!/bin/bash
# Crawl4AI 启动/停止脚本（占位）
# 用法：./crawl4ai.sh [up|down|restart|logs|status]
# 状态：⏳ 预留位置，待实现

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$COMPOSE_DIR/compose/docker-compose.yml"

cd "$COMPOSE_DIR"

echo "⏳ Crawl4AI 服务尚未实现"
echo ""
echo "计划功能："
echo "  1. Crawl4AI 服务本体（宿主机运行，无需 Docker）"
echo "  2. Playwright 浏览器依赖"
echo "  3. 网页抓取和提取 API"
echo ""
echo "参考实现："
echo "  - https://github.com/unclecode/crawl4ai"
echo ""

case "${1:-help}" in
  up|start)
    echo "Crawl4AI 暂未实现 Docker 化"
    echo "请参考官方文档在宿主机安装："
    echo "  pip install crawl4ai"
    echo "  playwright install"
    ;;

  down|stop)
    echo "Crawl4AI 未运行（暂未实现）"
    ;;

  restart)
    echo "Crawl4AI 暂未实现"
    ;;

  logs)
    echo "Crawl4AI 暂未实现"
    ;;

  status)
    echo "Crawl4AI 状态：未实现"
    ;;

  *)
    echo "用法：$0 {up|down|restart|logs|status}"
    echo ""
    echo "Crawl4AI 服务计划："
    echo "  up      - 启动服务（暂未实现）"
    echo "  down    - 停止服务（暂未实现）"
    echo "  restart - 重启服务（暂未实现）"
    echo "  logs    - 查看日志（暂未实现）"
    echo "  status  - 查看状态（暂未实现）"
    exit 1
    ;;
esac
