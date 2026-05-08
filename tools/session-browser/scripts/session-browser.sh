#!/usr/bin/env bash
# Unified local and Podman entry point for session-browser.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$TOOL_DIR/../.." && pwd)"
CALLER_DIR="$(pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/../src" && pwd)"
VERSION_FILE="$TOOL_DIR/VERSION"
VENV_DIR="${SESSION_BROWSER_VENV_DIR:-$TOOL_DIR/.venv}"
DEFAULT_DATA_DIR="$HOME/.local/share/feipi/session-browser/index"

export PYTHONPATH="$SRC_DIR:${PYTHONPATH:-}"

CMD="${1:-help}"
shift || true

read_version() {
    if [[ -n "${SESSION_BROWSER_VERSION:-}" ]]; then
        printf '%s\n' "$SESSION_BROWSER_VERSION"
    elif [[ -f "$VERSION_FILE" ]]; then
        tr -d '[:space:]' < "$VERSION_FILE"
        printf '\n'
    else
        printf '0.0.0-dev\n'
    fi
}

validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9._-]+)?$ ]]; then
        echo "版本号不合法：$version" >&2
        echo "请使用语义化版本，例如 0.2.0 或 0.2.0-rc.1" >&2
        exit 1
    fi
}

set_version() {
    local version="$1"
    validate_version "$version"
    printf '%s\n' "$version" > "$VERSION_FILE"
    echo "版本已更新：$version"
}

image_repo() {
    printf '%s\n' "${SESSION_BROWSER_IMAGE_REPO:-localhost/feipi/session-browser}"
}

container_name() {
    printf '%s\n' "${SESSION_BROWSER_CONTAINER_NAME:-session-browser}"
}

host_port() {
    printf '%s\n' "${SESSION_BROWSER_HOST_PORT:-${SERVER_PORT:-8899}}"
}

expand_path() {
    local value="$1"
    local expanded
    case "$value" in
        "~") expanded="$HOME" ;;
        "~/"*) expanded="$HOME/${value#~/}" ;;
        *) expanded="$value" ;;
    esac

    case "$expanded" in
        /*) printf '%s\n' "$expanded" ;;
        tools/session-browser/*) printf '%s/%s\n' "$REPO_DIR" "$expanded" ;;
        *) printf '%s/%s\n' "$CALLER_DIR" "$expanded" ;;
    esac
}

require_podman() {
    if ! command -v "${PODMAN_BIN:-podman}" >/dev/null 2>&1; then
        echo "未找到 podman。请安装 Podman，或设置 PODMAN_BIN=/path/to/podman。" >&2
        exit 1
    fi
}

python_bin() {
    if [[ -x "$VENV_DIR/bin/python" ]]; then
        printf '%s\n' "$VENV_DIR/bin/python"
    else
        printf 'python3\n'
    fi
}

run_tests() {
    cd "$TOOL_DIR"
    PYTHONPATH="$SRC_DIR:${PYTHONPATH:-}" "$(python_bin)" -m pytest tests "$@"
}

install_deps() {
    cd "$TOOL_DIR"
    if [[ ! -x "$VENV_DIR/bin/python" ]]; then
        python3 -m venv "$VENV_DIR"
    fi
    "$VENV_DIR/bin/python" -m pip install -r requirements-dev.txt "$@"
}

ensure_runtime_deps() {
    "$(python_bin)" - <<'PY'
import importlib
import sys

missing = []
for module, package in (("jinja2", "jinja2"), ("markdown_it", "markdown-it-py")):
    try:
        importlib.import_module(module)
    except ModuleNotFoundError:
        missing.append(package)

if missing:
    print(
        "缺少 Python 运行依赖：" + ", ".join(missing),
        file=sys.stderr,
    )
    print(
        "请执行：./scripts/session-browser.sh deps",
        file=sys.stderr,
    )
    sys.exit(1)
PY
}

build_image() {
    local version="${1:-$(read_version)}"
    validate_version "$version"
    require_podman

    local repo
    repo="$(image_repo)"

    echo "构建本地镜像："
    echo "  image: $repo:$version"
    echo "  latest: $repo:latest"
    "${PODMAN_BIN:-podman}" build \
        --build-arg "SESSION_BROWSER_VERSION=$version" \
        --label "org.opencontainers.image.version=$version" \
        --label "org.opencontainers.image.title=session-browser" \
        --label "org.opencontainers.image.source=feipi-agent-kit/tools/session-browser" \
        -t "$repo:$version" \
        -t "$repo:latest" \
        "$TOOL_DIR"
}

podman_up() {
    local version="${1:-$(read_version)}"
    validate_version "$version"
    require_podman

    local repo name port index_dir claude_dir codex_dir qoder_dir
    repo="$(image_repo)"
    name="$(container_name)"
    port="$(host_port)"
    index_dir="$(expand_path "${SESSION_BROWSER_DATA_DIR:-$DEFAULT_DATA_DIR}")"
    claude_dir="$(expand_path "${CLAUDE_DATA_DIR:-$HOME/.claude}")"
    codex_dir="$(expand_path "${CODEX_DATA_DIR:-$HOME/.codex}")"
    qoder_dir="$(expand_path "${QODER_DATA_DIR:-$HOME/.qoder}")"

    mkdir -p "$index_dir"

    local -a volume_args
    volume_args=(-v "$index_dir:/data/index")
    if [[ -d "$claude_dir" ]]; then
        volume_args+=(-v "$claude_dir:/data/claude:ro")
    else
        echo "警告：Claude 数据目录不存在，跳过挂载：$claude_dir" >&2
    fi
    if [[ -d "$codex_dir" ]]; then
        volume_args+=(-v "$codex_dir:/data/codex:ro")
    else
        echo "警告：Codex 数据目录不存在，跳过挂载：$codex_dir" >&2
    fi
    if [[ -d "$qoder_dir" ]]; then
        volume_args+=(-v "$qoder_dir:/data/qoder:ro")
    fi

    "${PODMAN_BIN:-podman}" rm -f "$name" >/dev/null 2>&1 || true
    "${PODMAN_BIN:-podman}" run -d \
        --name "$name" \
        -p "$port:8899" \
        "${volume_args[@]}" \
        -e "CLAUDE_DATA_DIR=/data/claude" \
        -e "CODEX_DATA_DIR=/data/codex" \
        -e "QODER_DATA_DIR=/data/qoder" \
        -e "INDEX_DIR=/data/index" \
        -e "SERVER_HOST=0.0.0.0" \
        -e "SERVER_PORT=8899" \
        -e "SESSION_BROWSER_LOG_LEVEL=${SESSION_BROWSER_LOG_LEVEL:-INFO}" \
        -e "SESSION_BROWSER_VERSION=$version" \
        "$repo:$version" \
        ./scripts/session-browser.sh serve --allow-empty --startup-scan

    echo "session-browser 已启动：http://127.0.0.1:$port"
    echo "容器：$name"
    echo "镜像：$repo:$version"
    echo "索引目录：$index_dir"
    echo "数据挂载："
    echo "  Claude: $claude_dir"
    echo "  Codex:  $codex_dir"
    echo "  Qoder:  $qoder_dir"
}

print_usage() {
    cat <<'EOF'
用法：./scripts/session-browser.sh <command> [options]

本地验证：
  deps [pip options]               安装本地运行/测试依赖
  dev [serve options]              前台启动服务，默认 DEBUG 日志
  scan [scan options]              全量或增量扫描
  serve [serve options]            前台启动服务
  stop [--port 8899]               按端口停止服务进程
  test [pytest options]            执行单元测试

版本与本地镜像发布：
  version                          输出当前版本
  set-version <x.y.z>              更新 VERSION
  build [x.y.z]                    构建本地 Podman 镜像
  release [x.y.z]                  先测试，再构建本地 Podman 镜像

Podman 部署：
  deploy [x.y.z]                   构建镜像并用 Podman 启动
  podman-up [x.y.z]                使用已有本地镜像启动
  podman-down                      停止并移除本地容器
  podman-logs                      跟随查看容器日志
  podman-status                    查看容器状态

常用环境变量：
  SESSION_BROWSER_VENV_DIR         默认：tools/session-browser/.venv
  SESSION_BROWSER_IMAGE_REPO       默认：localhost/feipi/session-browser
  SESSION_BROWSER_CONTAINER_NAME   默认：session-browser
  SESSION_BROWSER_HOST_PORT        默认：SERVER_PORT 或 8899
  SESSION_BROWSER_DATA_DIR         默认：~/.local/share/feipi/session-browser/index
  SESSION_BROWSER_LOG_LEVEL        默认：INFO；dev 使用 DEBUG
  CLAUDE_DATA_DIR                  默认：~/.claude
  CODEX_DATA_DIR                   默认：~/.codex
  QODER_DATA_DIR                   默认：~/.qoder

示例：
  ./scripts/session-browser.sh dev --port 8899 --force
  ./scripts/session-browser.sh scan --incremental
  ./scripts/session-browser.sh release 0.2.0
  ./scripts/session-browser.sh deploy 0.2.0
  ./scripts/session-browser.sh podman-logs
EOF
}

case "$CMD" in
    dev)
        ensure_runtime_deps
        export PYTHONUNBUFFERED=1
        export SESSION_BROWSER_LOG_LEVEL="${SESSION_BROWSER_LOG_LEVEL:-DEBUG}"
        export SESSION_BROWSER_VERSION="${SESSION_BROWSER_VERSION:-$(read_version)}"
        echo "启动前台调试服务"
        echo "  版本：$SESSION_BROWSER_VERSION"
        echo "  日志级别：$SESSION_BROWSER_LOG_LEVEL"
        echo "  源码目录：$SRC_DIR"
        exec "$(python_bin)" -m session_browser serve --allow-empty "$@"
        ;;
    deps)
        install_deps "$@"
        ;;
    scan)
        export SESSION_BROWSER_VERSION="${SESSION_BROWSER_VERSION:-$(read_version)}"
        exec "$(python_bin)" -m session_browser scan "$@"
        ;;
    serve)
        ensure_runtime_deps
        export PYTHONUNBUFFERED="${PYTHONUNBUFFERED:-1}"
        export SESSION_BROWSER_VERSION="${SESSION_BROWSER_VERSION:-$(read_version)}"
        exec "$(python_bin)" -m session_browser serve --allow-empty "$@"
        ;;
    stop)
        exec "$(python_bin)" -m session_browser stop "$@"
        ;;
    test)
        run_tests "$@"
        ;;
    version)
        read_version
        ;;
    set-version)
        if [[ $# -lt 1 ]]; then
            echo "用法：$0 set-version <x.y.z>" >&2
            exit 1
        fi
        set_version "$1"
        ;;
    build)
        build_image "${1:-$(read_version)}"
        ;;
    release|publish-local)
        if [[ $# -ge 1 ]]; then
            set_version "$1"
        fi
        version="$(read_version)"
        run_tests
        build_image "$version"
        echo "本地镜像已发布：$(image_repo):$version"
        ;;
    deploy)
        if [[ $# -ge 1 ]]; then
            set_version "$1"
        fi
        version="$(read_version)"
        build_image "$version"
        podman_up "$version"
        ;;
    podman-up|up)
        podman_up "${1:-$(read_version)}"
        ;;
    podman-down|down)
        require_podman
        "${PODMAN_BIN:-podman}" rm -f "$(container_name)" >/dev/null 2>&1 || true
        echo "session-browser 已停止。"
        ;;
    podman-logs|logs)
        require_podman
        if [[ $# -gt 0 ]]; then
            "${PODMAN_BIN:-podman}" logs "$@" "$(container_name)"
        else
            "${PODMAN_BIN:-podman}" logs -f "$(container_name)"
        fi
        ;;
    podman-status|status)
        require_podman
        "${PODMAN_BIN:-podman}" ps -a --filter "name=$(container_name)"
        ;;
    *)
        print_usage
        ;;
esac
