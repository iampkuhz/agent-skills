#!/bin/bash
# LiteLLM 启动/停止脚本
# 用法：./start.sh | ./stop.sh | ./restart.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$COMPOSE_DIR/compose/docker-compose.yml"
ENV_FILE="$COMPOSE_DIR/env/.env"

cd "$COMPOSE_DIR"

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    echo "📦 从 $ENV_FILE 加载环境变量..."
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
  else
    echo "⚠️  未找到 env/.env 文件，请确保已 source 环境变量"
  fi
}

case "${1:-up}" in
  up|start)
    load_env

    POSTGRES_DATA_DIR="/Users/zhehan/Documents/service-data/postgres"

    echo "🚀 启动 LiteLLM..."
    echo "📁 PostgreSQL 数据目录：$POSTGRES_DATA_DIR"
    podman compose -f "$COMPOSE_FILE" up -d
    echo "✅ LiteLLM 已启动"
    echo "📌 访问地址：http://localhost:4000"
    echo "📌 就绪检查：curl http://localhost:4000/health/readiness"
    ;;

  down|stop)
    echo "🛑 停止 LiteLLM..."
    podman compose -f "$COMPOSE_FILE" down
    echo "✅ LiteLLM 已停止"
    ;;

  restart)
    load_env
    echo "🔄 重新创建 LiteLLM（应用镜像、配置和资源限制变更）..."
    podman compose -f "$COMPOSE_FILE" up -d --force-recreate litellm
    echo "✅ LiteLLM 已重新创建"
    ;;

  recreate)
    load_env
    echo "🔄 重新创建 LiteLLM 和 PostgreSQL..."
    podman compose -f "$COMPOSE_FILE" up -d --force-recreate
    echo "✅ LiteLLM 栈已重新创建"
    ;;

  logs)
    # 查看特定服务日志，默认查看 litellm 服务
    # 用法：./litellm.sh logs [litellm|postgres|all]
    case "${2:-litellm}" in
      litellm)
        podman compose -f "$COMPOSE_FILE" logs -f litellm
        ;;
      postgres)
        podman compose -f "$COMPOSE_FILE" logs -f postgres
        ;;
      all)
        podman compose -f "$COMPOSE_FILE" logs -f
        ;;
      *)
        echo "用法：$0 logs [litellm|postgres|all]"
        exit 1
        ;;
    esac
    ;;

  status)
    podman compose -f "$COMPOSE_FILE" ps
    ;;

  *)
    echo "用法：$0 {up|down|restart|recreate|logs|status}"
    exit 1
    ;;
esac
