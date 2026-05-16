"""Tests for Inspector/Viewer tab structure.

Ensures that the LLM Call Inspector has:
- 7 required tabs: Overview, Rendered Context, Request Payload,
  Rendered Response, Response Payload, Tools, Raw.
- Tab buttons and tabpanels with active state and basic ARIA attributes.
- "Request Payload unavailable" empty-state text.
- Safe HTML escaping for raw JSON/<pre> content.
- Guarded viewerHtml fallback that doesn't break non-LLM Inspector.

Before tab shell implementation, these tests SHOULD FAIL because the
current inspector lacks tabs, unavailable states, and proper structure.
"""

import re
from pathlib import Path

TEMPLATE_DIR = Path(__file__).parent.parent / "src" / "session_browser" / "web"

_REQUIRED_TABS = [
    "Overview",
    "Rendered Context",
    "Request Payload",
    "Rendered Response",
    "Response Payload",
    "Tools",
    "Raw",
]


def _read_all_sources() -> dict[str, str]:
    result = {}
    for rel in [
        "templates/components/inspector.html",
        "templates/components/viewer.html",
        "templates/session.html",
        "static/js/inspector.js",
    ]:
        p = TEMPLATE_DIR / rel
        if p.exists():
            result[rel] = p.read_text(encoding="utf-8")
    return result


def _combined(sources: dict[str, str]) -> str:
    return "\n".join(sources.values())


# ── Required tabs ────────────────────────────────────────────────────

def test_all_seven_tabs_exist():
    """All 7 required tab labels must be present across templates/JS."""
    sources = _read_all_sources()
    combined = _combined(sources)
    missing = [tab for tab in _REQUIRED_TABS if tab not in combined]
    assert not missing, f"Missing tab labels: {', '.join(missing)}"


# ── ARIA and active state ────────────────────────────────────────────

def test_tab_buttons_have_aria_role():
    """Tab buttons must have role='tab' ARIA attribute."""
    sources = _read_all_sources()
    combined = _combined(sources)
    assert 'role="tab"' in combined or "role='tab'" in combined, (
        "Tab buttons must have role='tab' ARIA attribute"
    )


def test_tabpanel_exists():
    """Tab panels must exist (role='tabpanel' or class='tab-content')."""
    sources = _read_all_sources()
    combined = _combined(sources)
    has = (
        'role="tabpanel"' in combined
        or "role='tabpanel'" in combined
        or 'class="tab-content"' in combined
        or 'class="tabpanel"' in combined
    )
    assert has, "No tabpanel element found"


def test_active_state_class_exists():
    """Tab structure must have an 'active' state class."""
    sources = _read_all_sources()
    combined = _combined(sources)
    assert re.search(r'class="[^"]*\bactive\b[^"]*"', combined), (
        "No 'active' state class found in tab structure"
    )


# ── Empty state ──────────────────────────────────────────────────────

def test_request_payload_unavailable():
    """'Request Payload unavailable' or equivalent empty-state text must exist."""
    sources = _read_all_sources()
    combined = _combined(sources)
    patterns = [
        r'Request Payload.*unavailable',
        r'unavailable.*Request Payload',
        r'Request Payload.*not available',
        r'No request payload',
        r'request.*payload.*unavailable',
    ]
    found = any(re.search(p, combined, re.IGNORECASE) for p in patterns)
    assert found, (
        "No 'Request Payload unavailable' empty-state text found. "
        "Add a clear unavailable message for missing request payload."
    )


# ── Content escaping ─────────────────────────────────────────────────

def test_raw_content_html_escaping():
    """Raw JSON/<pre> content must be HTML-escaped in JS."""
    js_path = TEMPLATE_DIR / "static" / "js" / "inspector.js"
    if not js_path.exists():
        return  # Skip if JS file missing
    js = js_path.read_text(encoding="utf-8")

    assert re.search(r"replace\s*\(\s*/&/g\s*,\s*['\"]&amp;['\"]", js), (
        "Missing & -> &amp; escaping in JS"
    )
    assert re.search(r"replace\s*\(\s*/</g\s*,\s*['\"]&lt;['\"]", js), (
        "Missing < -> &lt; escaping in JS"
    )
    assert re.search(r"/>/g\s*,\s*['\"]&gt;['\"]", js), (
        "Missing > -> &gt; escaping in JS"
    )


# ── viewerHtml fallback ─────────────────────────────────────────────

def test_viewerhtml_fallback_guarded():
    """viewerHtml injection must be guarded by a conditional check."""
    js_path = TEMPLATE_DIR / "static" / "js" / "inspector.js"
    if not js_path.exists():
        return
    js = js_path.read_text(encoding="utf-8")
    assert re.search(r'if\s*\(\s*payload\.viewerHtml\s*\)', js), (
        "viewerHtml injection is not guarded by a conditional check"
    )


def test_inspector_has_default_viewer_slot():
    """Inspector template must have a fallback/empty state for the viewer slot."""
    inspector_path = TEMPLATE_DIR / "templates" / "components" / "inspector.html"
    if not inspector_path.exists():
        return
    inspector = inspector_path.read_text(encoding="utf-8")
    assert re.search(
        r'(No .*? available|Not available|—|viewer__fallback|inspector-viewer-slot)',
        inspector,
    ), "Inspector template must have fallback content for absent viewerHtml"


# ── Inspector tab shell ──────────────────────────────────────────────

def test_inspector_has_tab_shell():
    """Inspector must have its own tab shell (HTML or JS)."""
    sources = _read_all_sources()
    combined = _combined(sources)
    has = bool(re.search(
        r'(inspector-tab|data-inspector-tab|class="inspector.*tab|tab.*panel|tabpanel|role.*tab)',
        combined,
        re.IGNORECASE,
    ))
    assert has, (
        "Inspector lacks a dedicated tab shell. "
        "Add inspector-level tabs for: Overview, Rendered Context, "
        "Request Payload, Rendered Response, Response Payload, Tools, Raw."
    )


# ── Rendered/raw separation ─────────────────────────────────────────

def test_rendered_raw_separation():
    """Rendered and raw content must have separate containers."""
    sources = _read_all_sources()
    combined = _combined(sources)
    has_rendered = bool(re.search(
        r'(rendered|markdown|viewer__markdown|viewer__part-markdown)',
        combined,
    ))
    has_raw = bool(re.search(
        r'(viewer__raw|raw-pre|raw-json|__raw)',
        combined,
    ))
    assert has_rendered and has_raw, (
        "Rendered and raw containers are not clearly separated"
    )
