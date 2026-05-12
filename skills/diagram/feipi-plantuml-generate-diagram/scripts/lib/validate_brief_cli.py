#!/usr/bin/env python3
"""CLI wrapper for brief validation from shell scripts."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from lib.brief_loader import validate_brief_file


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a brief YAML file")
    parser.add_argument("brief", help="brief YAML file path")
    parser.add_argument("--schema", required=True, help="schema JSON file path")
    args = parser.parse_args()

    success, errors, warnings, data = validate_brief_file(args.brief, args.schema)

    for w in warnings:
        print(f"[警告] {w}", file=sys.stderr)
    if not success:
        for e in errors:
            print(f"[错误] {e}", file=sys.stderr)
        return 1

    print("brief_check=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
