#!/usr/bin/env python3
"""CLI wrapper for writing validation.json from shell scripts."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from lib.validation_result import ValidationResult, write_validation_json


def main() -> int:
    parser = argparse.ArgumentParser(description="Write validation.json")
    parser.add_argument("--output", required=True)
    parser.add_argument("--skill-name", default="feipi-plantuml-generate-diagram")
    parser.add_argument("--diagram-type", default="fallback")
    parser.add_argument("--profile", default="fallback")
    parser.add_argument("--diagram-path", default="")
    parser.add_argument("--svg-path", default="")
    parser.add_argument("--brief-check", default="skipped")
    parser.add_argument("--coverage-check", default="skipped")
    parser.add_argument("--layout-check", default="skipped")
    parser.add_argument("--render-result", default="pending")
    parser.add_argument("--render-server", default="")
    parser.add_argument("--final-status", default="pending")
    parser.add_argument("--blocked-reason", default="")
    parser.add_argument("--brief-path", default="")
    args = parser.parse_args()

    result = ValidationResult(
        skill_name=args.skill_name,
        diagram_type=args.diagram_type,
        profile=args.profile,
        brief_path=args.brief_path,
        diagram_path=args.diagram_path,
        svg_path=args.svg_path,
        brief_check=args.brief_check,
        coverage_check=args.coverage_check,
        layout_check=args.layout_check,
        render_result=args.render_result,
        render_server=args.render_server,
        final_status=args.final_status,
        blocked_reason=args.blocked_reason,
    )
    write_validation_json(result, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
