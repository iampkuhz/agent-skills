#!/bin/bash
# SearXNG 启动/停止脚本
# 用法：./start.sh | ./stop.sh | ./restart.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$COMPOSE_DIR/compose/docker-compose.yml"
ENV_FILE="$COMPOSE_DIR/env/.env"

cd "$COMPOSE_DIR"

case "${1:-up}" in
  up|start)
    echo "🚀 启动 SearXNG..."
    docker compose -f "$COMPOSE_FILE" up -d
    echo "✅ SearXNG 已启动"
    echo "📌 访问地址：http://localhost:8873"
    echo "📌 健康检查：curl http://localhost:8873/healthz"
    ;;

  down|stop)
    echo "🛑 停止 SearXNG..."
    docker compose -f "$COMPOSE_FILE" down
    echo "✅ SearXNG 已停止"
    ;;

  restart)
    echo "🔄 重启 SearXNG..."
    docker compose -f "$COMPOSE_FILE" restart
    echo "✅ SearXNG 已重启"
    ;;

  logs)
    docker compose -f "$COMPOSE_FILE" logs -f
    ;;

  status)
    docker compose -f "$COMPOSE_FILE" ps
    ;;

  *)
    echo "用法：$0 {up|down|restart|logs|status}"
    exit 1
    ;;
esac
