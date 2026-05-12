#!/usr/bin/env python3
"""Profile 注册表：按图类型路由到对应的 schema、模板、覆盖和布局模式。"""

from __future__ import annotations

from pathlib import Path
from typing import Any

LIB_DIR = Path(__file__).resolve().parent
SKILL_DIR = LIB_DIR.parent.parent

PROFILES: dict[str, dict[str, Any]] = {
    "fallback": {
        "brief_schema": None,
        "template": None,
        "coverage_mode": "basic",
        "layout_mode": "basic",
    },
    "architecture": {
        "brief_schema": str(SKILL_DIR / "assets" / "validation" / "types" / "architecture-brief.schema.json"),
        "template": str(SKILL_DIR / "assets" / "templates" / "types" / "architecture-brief.yaml"),
        "coverage_mode": "architecture",
        "layout_mode": "architecture",
    },
    "sequence": {
        "brief_schema": str(SKILL_DIR / "assets" / "validation" / "types" / "sequence-brief.schema.json"),
        "template": str(SKILL_DIR / "assets" / "templates" / "types" / "sequence-brief.yaml"),
        "coverage_mode": "sequence",
        "layout_mode": "sequence",
    },
}


def get_profile(diagram_type: str) -> dict[str, Any] | None:
    return PROFILES.get(diagram_type)


def list_profiles() -> list[str]:
    return sorted(PROFILES.keys())


def is_typed_profile(diagram_type: str) -> bool:
    return diagram_type != "fallback" and diagram_type in PROFILES
