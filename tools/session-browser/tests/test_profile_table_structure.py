"""Tests for Profile table DOM structure.

Ensures that:
- Profile template does NOT have inline llm-call-detail expansion rows.
- Profile template does NOT contain .llm-call-detail__pre-block elements.
- Profile template does NOT contain "Request Context:" inline label.
- Each profile row has an Inspect button calling openLLMInspector.
- A marker container exists in the profile template.
- Preview column has truncation class.

After Profile refactoring (P-01/P-02), inline detail rows and Request Context
labels have been removed; details are viewed via Inspector.
"""

import re
from pathlib import Path

TEMPLATE_DIR = Path(__file__).parent.parent / "src" / "session_browser" / "web" / "templates"


def _session_source():
    return (TEMPLATE_DIR / "session.html").read_text(encoding="utf-8")


def _extract_profile_template(source):
    """Extract content of <template id="profile-template">."""
    m = re.search(
        r'<template id="profile-template">(.*?)</template>',
        source,
        re.DOTALL,
    )
    assert m, "Cannot find <template id='profile-template'> in session.html"
    return m.group(1)


# ── Profile must NOT have inline detail expansion ────────────────────

def test_no_inline_llm_call_detail_rows():
    """Profile should NOT expand inline detail rows — details belong in Inspector."""
    template = _extract_profile_template(_session_source())
    assert not re.search(r'class="[^"]*\bllm-call-detail\b[^"]*"', template), (
        "Profile template must not contain <tr class='... llm-call-detail ...'> — "
        "inline detail expansion should be removed; use Inspector instead"
    )


def test_no_pre_block_class():
    """Profile should NOT contain .llm-call-detail__pre-block — no large inline <pre>."""
    template = _extract_profile_template(_session_source())
    assert 'llm-call-detail__pre-block' not in template, (
        "Profile template must not contain .llm-call-detail__pre-block — "
        "large inline <pre> blocks cause unstable row height"
    )


def test_no_request_context_label():
    """Profile should NOT contain 'Request Context:' inline label."""
    template = _extract_profile_template(_session_source())
    assert 'Request Context:' not in template, (
        "Profile template must not contain 'Request Context:' label — "
        "this confuses rendered context with request payload"
    )


# ── Profile must have Inspector entry points ─────────────────────────

def test_inspect_buttons_exist():
    """Each profile row must have an Inspect button."""
    template = _extract_profile_template(_session_source())
    buttons = re.findall(
        r'<button[^>]*class="[^"]*inspect-btn[^"]*"[^>]*>',
        template,
    )
    assert len(buttons) > 0, "Profile must have at least one inspect button"


def test_inspect_buttons_call_open_inspector():
    """Inspect buttons must reference openLLMInspector handler."""
    template = _extract_profile_template(_session_source())
    assert 'openLLMInspector' in template, (
        "Profile template must reference openLLMInspector function"
    )


# ── Marker container ─────────────────────────────────────────────────

def test_marker_container_exists():
    """Profile template should have a marker container for annotations."""
    template = _extract_profile_template(_session_source())
    has_marker = (
        'data-marker' in template
        or 'marker-container' in template
        or 'profile-marker' in template
    )
    assert has_marker, (
        "Profile template must have a marker container "
        "(data-marker / marker-container / profile-marker)"
    )


# ── Preview truncation ───────────────────────────────────────────────

def test_preview_has_truncation_class():
    """Preview column must have a truncation class for single/two-line clipping."""
    template = _extract_profile_template(_session_source())
    assert 'truncate' in template, (
        "Profile preview column must have a truncation class"
    )


