#!/usr/bin/env bash
# pre-commit hook 入口
# 按顺序执行所有质量门禁检查
set -euo pipefail

# 解析符号链接，获取真实脚本目录
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

echo "=== pre-commit hooks ==="

bash "$SCRIPT_DIR/check-frontmatter.sh"
bash "$SCRIPT_DIR/check-skill-naming.sh"
bash "$SCRIPT_DIR/check-skill-structure.sh"

echo "=== 所有 hooks 通过 ==="
