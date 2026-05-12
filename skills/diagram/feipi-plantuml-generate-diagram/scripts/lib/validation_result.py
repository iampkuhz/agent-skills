#!/usr/bin/env python3
"""统一 validation.json 写入工具。"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, asdict
from pathlib import Path


@dataclass
class ValidationResult:
    schema_version: str = "1.0"
    skill_name: str = "feipi-plantuml-generate-diagram"
    diagram_type: str = "fallback"
    profile: str = "fallback"
    brief_path: str = ""
    diagram_path: str = ""
    svg_path: str = ""
    brief_check: str = "skipped"
    coverage_check: str = "skipped"
    layout_check: str = "skipped"
    render_result: str = "pending"
    render_server: str = ""
    puml_sha256: str = ""
    svg_sha256: str = ""
    final_status: str = "pending"
    blocked_reason: str = ""

    def to_dict(self) -> dict:
        return asdict(self)

    def set_success(self) -> None:
        self.final_status = "success"
        self.blocked_reason = ""

    def set_blocked(self, reason: str) -> None:
        self.final_status = "blocked"
        self.blocked_reason = reason

    def set_render_server_unavailable(self) -> None:
        self.render_result = "skipped"
        self.final_status = "render_server_unavailable"
        self.blocked_reason = "render_server_unavailable"

    def set_render_syntax_error(self) -> None:
        self.render_result = "syntax_error"
        self.final_status = "blocked"
        self.blocked_reason = "render_syntax_error"


def compute_sha256(path: str) -> str:
    p = Path(path)
    if not p.exists():
        return ""
    return hashlib.sha256(p.read_bytes()).hexdigest()


def write_validation_json(result: ValidationResult, output_path: str) -> Path:
    p = Path(output_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    if result.diagram_path and not result.puml_sha256:
        result.puml_sha256 = compute_sha256(result.diagram_path)
    if result.svg_path and not result.svg_sha256:
        result.svg_sha256 = compute_sha256(result.svg_path)
    p.write_text(json.dumps(result.to_dict(), indent=2, ensure_ascii=False) + "\n")
    return p
