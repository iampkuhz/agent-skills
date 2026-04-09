#!/bin/bash
# LiteLLM 启动/停止脚本
# 用法：./start.sh | ./stop.sh | ./restart.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$COMPOSE_DIR/compose/docker-compose.yml"
ENV_FILE="$COMPOSE_DIR/env/.env"

cd "$COMPOSE_DIR"

case "${1:-up}" in
  up|start)
    if [[ -f "$ENV_FILE" ]]; then
      echo "📦 从 $ENV_FILE 加载环境变量..."
      export $(grep -v '^#' "$ENV_FILE" | xargs)
    else
      echo "⚠️  未找到 env/.env 文件，请确保已 source 环境变量"
    fi

    echo "🚀 启动 LiteLLM..."
    docker compose -f "$COMPOSE_FILE" up -d
    echo "✅ LiteLLM 已启动"
    echo "📌 访问地址：http://localhost:4000"
    echo "📌 健康检查：curl http://localhost:4000/health"
    ;;

  down|stop)
    echo "🛑 停止 LiteLLM..."
    docker compose -f "$COMPOSE_FILE" down
    echo "✅ LiteLLM 已停止"
    ;;

  restart)
    echo "🔄 重启 LiteLLM..."
    docker compose -f "$COMPOSE_FILE" restart
    echo "✅ LiteLLM 已重启"
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
