#!/bin/bash
# Feipi Agent Kit 初始化设置脚本
# 用法：./scripts/bootstrap/setup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$REPO_ROOT"

echo "🔧 Feipi Agent Kit 初始化设置"
echo "========================="
echo ""

# 1. 检查 Python 环境
echo "📦 检查 Python 环境..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "✅ Python: $PYTHON_VERSION"
else
    echo "❌ Python3 未安装，请先安装 Python 3.10+"
    exit 1
fi

# 2. 检查 uv（如果使用）
echo "📦 检查 uv..."
if command -v uv &> /dev/null; then
    UV_VERSION=$(uv --version)
    echo "✅ uv: $UV_VERSION"
else
    echo "⚠️  uv 未安装（可选，用于 MCP 服务）"
    echo "   安装命令：curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

# 3. 检查 Docker
echo "📦 检查 Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo "✅ Docker: $DOCKER_VERSION"
else
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

# 4. 检查 Docker Compose
echo "📦 检查 Docker Compose..."
if command -v docker compose &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    echo "✅ Docker Compose: $COMPOSE_VERSION"
else
    echo "❌ Docker Compose 未安装，请先安装"
    exit 1
fi

# 5. 检查环境变量模板
echo "📦 检查环境变量模板..."
if [[ -f "$REPO_ROOT/.env.example" ]]; then
    echo "✅ .env.example 存在"
    if [[ ! -f "$REPO_ROOT/.env" ]]; then
        echo "   建议：cp .env.example .env 并编辑"
    else
        echo "✅ .env 已存在"
    fi
fi

# 6. 检查服务配置
echo "📦 检查服务配置..."

# SearXNG
if [[ -f "$REPO_ROOT/tools/search/searxng/compose/docker-compose.yml" ]]; then
    echo "✅ SearXNG 配置存在"
else
    echo "⚠️  SearXNG 配置不存在"
fi

# LiteLLM
if [[ -f "$REPO_ROOT/tools/gateway/litellm/compose/docker-compose.yml" ]]; then
    echo "✅ LiteLLM 配置存在"
else
    echo "⚠️  LiteLLM 配置不存在"
fi

# SearXNG MCP
if [[ -f "$REPO_ROOT/tools/search/searxng-mcp/pyproject.toml" ]]; then
    echo "✅ SearXNG MCP 配置存在"
else
    echo "⚠️  SearXNG MCP 配置不存在"
fi

echo ""
echo "✅ 初始化检查完成"
echo ""
echo "===== 下一步 ====="
echo "1. 配置环境变量："
echo "   cp .env.example .env"
echo "   # 编辑 .env 填入真实值"
echo ""
echo "2. 启动服务："
echo "   make searxng-up"
echo "   make litellm-up"
echo ""
echo "3. 安装 skills："
echo "   make install-links"
echo ""
echo "4. 运行 MCP 服务："
echo "   make searxng-mcp-run"
echo ""
