#!/usr/bin/env python3
"""Check scroll shadow behavior for Timeline/table regions.

Static analysis script that verifies:
1. Left and right shadow states exist in CSS.
2. Shadows are bound to .table-wrap or explicit scroll containers.
3. State rules: scrollLeft==0 hides left shadow, scrollLeft>0 shows it,
   right-edge hides right shadow, not-at-edge shows it.
4. pointer-events: none on shadows.
5. resize / Profile lazy-load / sidebar-collapse refresh coverage.

Usage:
    cd tools/session-browser
    PYTHONPATH=src python scripts/check_scroll_shadow_behavior.py

Exit codes:
    0 — all checks pass
    1 — one or more FAILs detected
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Resolve paths relative to this script's parent repo root
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
SRC = REPO_ROOT / "src" / "session_browser" / "web"

CSS_FILE = SRC / "static" / "style.css"
JS_FILES = [
    SRC / "static" / "js" / "app.js",
    SRC / "static" / "js" / "data-table.js",
    SRC / "static" / "js" / "timeline.js",
    SRC / "static" / "js" / "keyboard.js",
]
INLINE_JS_FILES = [
    SRC / "templates" / "base.html",
    SRC / "templates" / "session.html",
]

_pass = 0
_fail = 0
_warn = 0
_findings: list[tuple[str, str]] = []


def _reset_counters() -> None:
    """Reset global counters for test isolation."""
    global _pass, _fail, _warn, _findings
    _pass = 0
    _fail = 0
    _warn = 0
    _findings = []


def report(level: str, check: str, detail: str = "") -> None:
    global _pass, _fail, _warn
    tag = {"OK": "OK", "FAIL": "FAIL", "WARN": "WARN"}.get(level, "??")
    line = f"  [{tag}] {check}"
    if detail:
        line += f" — {detail}"
    print(line)
    _findings.append((level, check))
    if level == "OK":
        _pass += 1
    elif level == "FAIL":
        _fail += 1
    else:
        _warn += 1


def read_file(p: Path) -> str:
    if not p.exists():
        return ""
    return p.read_text(encoding="utf-8")


def read_all_js() -> str:
    parts: list[str] = []
    for f in JS_FILES:
        content = read_file(f)
        if content:
            parts.append(content)
    return "\n".join(parts)


def read_all_inline_js() -> str:
    parts: list[str] = []
    for f in INLINE_JS_FILES:
        content = read_file(f)
        if not content:
            continue
        # Extract inline <script> blocks
        for m in re.finditer(r'<script[^>]*>(.*?)</script>', content, re.DOTALL):
            parts.append(m.group(1))
    return "\n".join(parts)


# ─── 1. CSS: right shadow ───────────────────────────────────────────

def check_right_shadow(css: str) -> None:
    """Verify .table-wrap::after right shadow exists."""
    has_after = bool(re.search(r'\.table-wrap\s*::after\s*\{', css))
    has_gradient = 'linear-gradient' in css and 'to right' in css
    has_width = bool(re.search(r'width:\s*40px', css))

    if has_after and has_gradient:
        report("OK", "Right shadow (.table-wrap::after) exists")
    else:
        report("FAIL", "Right shadow (.table-wrap::after) missing",
               f"::after rule={has_after}, gradient={has_gradient}")

    if has_width:
        report("OK", "Right shadow has width (40px fade zone)")
    else:
        report("WARN", "Right shadow width not explicitly 40px")


# ─── 2. CSS: left shadow ────────────────────────────────────────────

def check_left_shadow(css: str) -> None:
    """Verify .table-wrap::before left shadow exists."""
    has_before = bool(re.search(r'\.table-wrap\s*::before\s*\{', css))
    has_left_gradient = bool(re.search(r'linear-gradient\s*\(\s*to\s+left', css))
    # Also check for ::before on .is-scroll-left / .table-wrap.scrolled-left variants
    has_scroll_left = bool(re.search(r'\.is-scroll-left\s*::before', css))
    has_scrolled_left = bool(re.search(r'\.table-wrap\.scrolled-left\s*::before', css))

    if has_before:
        report("OK", "Left shadow (.table-wrap::before) exists")
    else:
        report("FAIL", "Left shadow (.table-wrap::before) missing — only right shadow implemented")

    if has_left_gradient or has_scroll_left or has_scrolled_left:
        report("OK", "Left shadow gradient (to left) or scroll state variant exists")
    else:
        report("WARN", "No left shadow gradient (to left) found")


# ─── 3. CSS: shadow binding to scroll container ─────────────────────

def check_shadow_binding(css: str) -> None:
    """Verify shadows are bound to .table-wrap (the scroll container)."""
    # Check all .table-wrap blocks (there may be multiple)
    all_blocks = re.findall(
        r'\.table-wrap\s*\{([^}]*)\}', css)
    combined = "\n".join(all_blocks)

    if all_blocks:
        has_position_relative = 'position' in combined and 'relative' in combined
        has_overflow_auto = 'overflow-x' in combined and 'auto' in combined

        if has_position_relative:
            report("OK", ".table-wrap has position:relative (shadow anchor)")
        else:
            report("FAIL", ".table-wrap missing position:relative")

        if has_overflow_auto:
            report("OK", ".table-wrap has overflow-x:auto (scroll container)")
        else:
            report("WARN", ".table-wrap overflow-x not confirmed in primary block")
    else:
        report("FAIL", ".table-wrap CSS rule not found")


# ─── 4. CSS: state rules (scrolled-right / scrolled-left) ───────────

def check_state_rules(css: str) -> None:
    """Verify CSS handles scroll state classes (is-scroll-right/left or scrolled-right/left)."""
    # Accept either naming convention
    has_scroll_right_hide = bool(
        re.search(r'\.is-scroll-right\s*::after\s*\{[^}]*opacity\s*:\s*0', css, re.DOTALL))
    has_scrolled_right_hide = bool(
        re.search(r'\.table-wrap\.scrolled-right\s*::after\s*\{[^}]*opacity\s*:\s*0', css, re.DOTALL))
    has_right_hide = has_scroll_right_hide or has_scrolled_right_hide

    has_right_any = '.is-scroll-right' in css or '.table-wrap.scrolled-right' in css

    if has_right_hide:
        report("OK", "Right shadow hidden at edge (opacity:0)")
    elif has_right_any:
        report("WARN", "Scroll-right class exists but opacity:0 not confirmed")
    else:
        report("FAIL", "No scroll-right state rule found (.is-scroll-right or .scrolled-right)")

    # Check for left shadow state rule
    has_scroll_left_hide = bool(
        re.search(r'\.is-scroll-left\s*::before\s*\{[^}]*opacity\s*:\s*[01]', css, re.DOTALL))
    has_scrolled_left_hide = bool(
        re.search(r'\.table-wrap[^}]*scrolled-left[^}]*::before[^}]*opacity\s*:\s*[01]', css, re.DOTALL))
    has_left_state = has_scroll_left_hide or has_scrolled_left_hide

    has_left_default = bool(
        re.search(r'\.table-wrap\s*::before\s*\{[^}]*opacity\s*:\s*0', css, re.DOTALL))

    if has_left_state or has_left_default:
        report("OK", "Left shadow has opacity-based state rule")
    else:
        report("FAIL", "No left shadow state rule")


# ─── 5. CSS: pointer-events:none ────────────────────────────────────

def check_pointer_events(css: str) -> None:
    """Verify shadows have pointer-events:none."""
    after_block = re.search(
        r'\.table-wrap\s*::after\s*\{([^}]*)\}', css, re.DOTALL)
    if after_block and 'pointer-events' in after_block.group(1) and 'none' in after_block.group(1):
        report("OK", ".table-wrap::after has pointer-events:none")
    else:
        report("FAIL", ".table-wrap::after missing pointer-events:none")

    before_block = re.search(
        r'\.table-wrap\s*::before\s*\{([^}]*)\}', css, re.DOTALL)
    if before_block:
        if 'pointer-events' in before_block.group(1) and 'none' in before_block.group(1):
            report("OK", ".table-wrap::before has pointer-events:none")
        else:
            report("WARN", ".table-wrap::before missing pointer-events:none")
    else:
        report("WARN", ".table-wrap::before not present to check pointer-events")


# ─── 6. JS: scroll event listener ───────────────────────────────────

def check_scroll_listener(js: str, inline_js: str) -> None:
    """Verify JS has scroll event listener handling scrollLeft."""
    all_js = js + "\n" + inline_js

    has_scroll_listener = bool(
        re.search(r"addEventListener\s*\(\s*['\"]scroll['\"]", all_js))
    if has_scroll_listener:
        report("OK", "scroll event listener registered")
    else:
        report("FAIL", "No scroll event listener found")

    has_scrollleft = 'scrollLeft' in all_js
    if has_scrollleft:
        report("OK", "scrollLeft property referenced in JS")
    else:
        report("FAIL", "scrollLeft not referenced — shadow cannot track position")

    # Check scrollLeft > 0 or scrollLeft == 0 logic for left shadow
    has_scrollleft_comparison = bool(
        re.search(r'scrollLeft.*[><=!]', all_js))
    if has_scrollleft_comparison:
        report("OK", "scrollLeft comparison logic found")
    else:
        report("FAIL", "No scrollLeft comparison logic — cannot determine scroll position")

    # Check scroll state class toggling (accept either naming)
    has_scroll_right_toggle = bool(
        re.search(r"['\"]is-scroll-right['\"]|['\"]scrolled-right['\"]", all_js))
    if has_scroll_right_toggle:
        report("OK", "Right scroll state class toggling in JS")
    else:
        report("WARN", "No right scroll state class toggle found in JS")

    # Check left scroll state class toggling
    has_scroll_left_toggle = bool(
        re.search(r"['\"]is-scroll-left['\"]|['\"]scrolled-left['\"]", all_js))
    if has_scroll_left_toggle:
        report("OK", "Left scroll state class toggling in JS")
    else:
        report("FAIL", "No left scroll state class toggle — left shadow never activated")


# ─── 7. JS: init / resize / refresh ─────────────────────────────────

def check_init_refresh(js: str, inline_js: str, css: str) -> None:
    """Verify shadow state is initialized on load and refreshed on resize."""
    all_js = js + "\n" + inline_js

    # Check for resize listener
    has_resize = bool(
        re.search(r"addEventListener\s*\(\s*['\"]resize['\"]", all_js))
    if has_resize:
        report("OK", "resize event listener registered")
    else:
        report("FAIL", "No resize listener — shadow state won't update on window resize")

    # Check for init/refresh function called on load
    has_init_call = bool(
        re.search(r'(initScrollShadows?|refreshScrollShadows?|updateScrollShadows?|updateShadow)',
                  all_js))
    has_domcontent = bool(
        re.search(r'DOMContentLoaded', all_js))
    has_init_on_wrap = bool(
        re.search(r'(init|refresh|update).*[Ss]croll', all_js))

    if has_init_call:
        report("OK", "Dedicated shadow init/refresh function found")
    elif has_init_on_wrap:
        report("WARN", "Generic scroll-related init found, but no dedicated shadow function")
    else:
        report("FAIL", "No shadow initialization function — shadows not set on page load")

    # Check sidebar-collapse handling
    has_sidebar_collapse = 'sidebar-collapsed' in css
    has_sidebar_toggle = 'toggleSidebar' in all_js or 'sidebar-toggle' in all_js

    if has_sidebar_collapse and has_sidebar_toggle:
        report("OK", "Sidebar collapse support present in CSS + JS")
    else:
        report("WARN", "Sidebar collapse/shadow interaction not verified")

    # Check Profile lazy-load — profile tab is loaded via <template>
    has_profile_lazy = bool(
        re.search(r"(profile.*lazy|lazy.*profile|profile-template|data-loaded)", all_js, re.I))
    if has_profile_lazy:
        report("OK", "Profile lazy-load mechanism detected")
    else:
        report("WARN", "Profile lazy-load not detected — shadow may need manual refresh after load")


# ─── 8. HTML: table-wrap usage ──────────────────────────────────────

def check_table_wrap_usage(session_html: str, base_html: str) -> None:
    """Verify .table-wrap is used for Timeline and Profile tables."""
    timeline_wrap = 'table-wrap' in session_html and 'class=' in session_html
    profile_wrap = 'profile-table-wrap' in session_html

    if timeline_wrap:
        report("OK", "Timeline table uses .table-wrap wrapper")
    else:
        report("WARN", "Timeline table may not have .table-wrap wrapper")

    if profile_wrap:
        report("OK", "Profile table uses .profile-table-wrap wrapper")
    else:
        report("WARN", "Profile table may not have scroll wrapper")

    # Check .profile-table-wrap has shadow support
    css = read_file(CSS_FILE)
    has_profile_shadow = bool(
        re.search(r'\.profile-table-wrap', css))
    if has_profile_shadow:
        report("OK", ".profile-table-wrap has CSS rules")
    else:
        report("WARN", ".profile-table-wrap has no dedicated CSS rules")


# ─── Main ───────────────────────────────────────────────────────────

def main() -> int:
    print("=" * 60)
    print("  Scroll Shadow Behavior Check")
    print("=" * 60)

    css = read_file(CSS_FILE)
    js = read_all_js()
    inline_js = read_all_inline_js()
    session_html = read_file(SRC / "templates" / "session.html")
    base_html = read_file(SRC / "templates" / "base.html")

    if not css:
        print(f"\n  ERROR: CSS file not found: {CSS_FILE}")
        return 2
    if not js and not inline_js:
        print(f"\n  ERROR: No JS content found")
        return 2

    print("\n  [1] Right shadow")
    print("  " + "-" * 40)
    check_right_shadow(css)

    print("\n  [2] Left shadow")
    print("  " + "-" * 40)
    check_left_shadow(css)

    print("\n  [3] Shadow binding to scroll container")
    print("  " + "-" * 40)
    check_shadow_binding(css)

    print("\n  [4] State rules (scrollLeft-based)")
    print("  " + "-" * 40)
    check_state_rules(css)

    print("\n  [5] pointer-events:none")
    print("  " + "-" * 40)
    check_pointer_events(css)

    print("\n  [6] JS: scroll event & scrollLeft handling")
    print("  " + "-" * 40)
    check_scroll_listener(js, inline_js)

    print("\n  [7] JS: init / resize / refresh coverage")
    print("  " + "-" * 40)
    check_init_refresh(js, inline_js, css)

    print("\n  [8] HTML: table-wrap usage")
    print("  " + "-" * 40)
    check_table_wrap_usage(session_html, base_html)

    # Summary
    print("\n" + "=" * 60)
    total = _pass + _fail + _warn
    print(f"  Results: {_pass} OK, {_warn} WARN, {_fail} FAIL (total: {total})")
    if _fail:
        print("  Status: FAIL — scroll shadow behavior is incomplete")
    elif _warn:
        print("  Status: PASS with warnings")
    else:
        print("  Status: PASS")
    print("=" * 60)

    return 1 if _fail > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
