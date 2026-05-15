"""Tests for Profile tab LLM Call modal Open button reliability.

Ensures that:
- Profile Open buttons use sibling templates + data-*-template-id (no nested <template>).
- Corresponding sibling <template> elements exist with unique IDs.
- openContentModal() supports both new template-id and old nested-template fallback.
- Capture-phase event handler exists with a closest() polyfill.
- Conversation/Timeline old buttons still use nested templates (backward compat).
"""

import re
from pathlib import Path

TEMPLATE_DIR = Path(__file__).parent.parent / "src" / "session_browser" / "web" / "templates"


def _session_source():
    return (TEMPLATE_DIR / "session.html").read_text(encoding="utf-8")


def _base_source():
    return (TEMPLATE_DIR / "base.html").read_text(encoding="utf-8")


# ── Profile button structure ──────────────────────────────────────────


def _extract_profile_llm_call_buttons(source):
    """Extract the Profile LLM call detail grid block to analyse buttons."""
    m = re.search(
        r'<strong class="text-xs">Request Context:</strong>.*?'
        r'<strong class="text-xs">Tool Calls',
        source,
        re.DOTALL,
    )
    assert m, "Could not find Request Context / Tool Calls block in Profile template"
    return m.group()


def test_profile_request_open_has_data_template_ids():
    """Request Open button must have data-raw-template-id and data-md-template-id."""
    source = _session_source()
    block = _extract_profile_llm_call_buttons(source)

    # Find the Request button block
    btn_m = re.search(
        r'<button\s[^>]*data-content-modal="LLM Call #\{\{ loop\.index \}} · Request"[^>]*>.*?</button>',
        block,
        re.DOTALL,
    )
    assert btn_m, "Request Open button not found with expected data-content-modal"
    btn_html = btn_m.group()

    assert 'data-raw-template-id=' in btn_html, (
        "Request button must have data-raw-template-id attribute"
    )
    assert 'data-md-template-id=' in btn_html, (
        "Request button must have data-md-template-id attribute"
    )
    assert 'type="button"' in btn_html, (
        "Request button must have type='button'"
    )


def test_profile_response_open_has_data_template_ids():
    """Response Open button must have data-raw-template-id and data-md-template-id."""
    source = _session_source()

    btn_m = re.search(
        r'<button\s[^>]*data-content-modal="LLM Call #\{\{ loop\.index \}} · Response"[^>]*>.*?</button>',
        source,
        re.DOTALL,
    )
    assert btn_m, "Response Open button not found with expected data-content-modal"
    btn_html = btn_m.group()

    assert 'data-raw-template-id=' in btn_html, (
        "Response button must have data-raw-template-id attribute"
    )
    assert 'data-md-template-id=' in btn_html, (
        "Response button must have data-md-template-id attribute"
    )
    assert 'type="button"' in btn_html, (
        "Response button must have type='button'"
    )


def test_profile_buttons_have_no_nested_template():
    """Open buttons must NOT contain nested <template> elements."""
    source = _session_source()

    # Find all button blocks in the Profile section
    for match in re.finditer(
        r'<button\s[^>]*class="content-open-btn[^"]*"[^>]*>.*?</button>',
        source,
        re.DOTALL,
    ):
        btn_html = match.group()
        assert '<template>' not in btn_html, (
            f"Button should not contain nested <template> elements:\n{btn_html}"
        )


def test_profile_sibling_templates_exist_for_request():
    """After the Request Open button, sibling <template> with matching id must exist."""
    source = _session_source()

    # Check the template id pattern uses loop.index with Jinja2 ~ concatenation
    assert "profile-call-" in source, (
        "Template id must reference 'profile-call-' prefix"
    )
    assert "'profile-call-' ~ loop.index ~ '-request-raw'" in source, (
        "Request raw template id must be built from 'profile-call-' + loop.index + '-request-raw'"
    )
    assert "'profile-call-' ~ loop.index ~ '-request-md'" in source, (
        "Request md template id must be built from 'profile-call-' + loop.index + '-request-md'"
    )
    assert "'profile-call-' ~ loop.index ~ '-response-raw'" in source, (
        "Response raw template id must be built from 'profile-call-' + loop.index + '-response-raw'"
    )
    assert "'profile-call-' ~ loop.index ~ '-response-md'" in source, (
        "Response md template id must be built from 'profile-call-' + loop.index + '-response-md'"
    )


# ── openContentModal compatibility ────────────────────────────────────


def test_open_content_modal_supports_template_id():
    """openContentModal must read data-raw-template-id / data-md-template-id."""
    source = _session_source()

    assert "_getTemplateTextById" in source, (
        "openContentModal must use _getTemplateTextById helper"
    )
    assert "_getTemplateHtmlById" in source, (
        "openContentModal must use _getTemplateHtmlById helper"
    )
    assert "data-raw-template-id" in source, (
        "openContentModal must reference data-raw-template-id attribute"
    )
    assert "data-md-template-id" in source, (
        "openContentModal must reference data-md-template-id attribute"
    )


def test_open_content_modal_fallback_nested_template():
    """openContentModal must fallback to btn.querySelectorAll('template') for old buttons."""
    source = _session_source()

    assert "querySelectorAll('template')" in source or 'querySelectorAll("template")' in source, (
        "openContentModal must fallback to nested template querying"
    )


def test_open_content_modal_warns_on_missing_content():
    """openContentModal must log console.warn when no template content is found."""
    source = _session_source()

    assert "console.warn" in source, (
        "openContentModal must call console.warn on failure, not silently return"
    )


def test_open_content_modal_sets_visible():
    """openContentModal must add 'visible' class to modal."""
    source = _session_source()

    assert "modal.classList.add('visible')" in source, (
        "openContentModal must add 'visible' class to modal"
    )


# ── Event handling ────────────────────────────────────────────────────


def test_capture_phase_click_listener():
    """base.html must have a capture-phase click listener for [data-content-modal]."""
    source = _base_source()

    assert "addEventListener('click'" in source, (
        "base.html must add click event listeners"
    )
    # The capture-phase listener uses `true` as the third argument
    assert ", true)" in source, (
        "base.html must register a capture-phase click listener (third arg = true)"
    )


def test_closest_polyfill():
    """base.html must define a closest helper for older WebView compatibility."""
    source = _base_source()

    assert "_arpClosest" in source, (
        "base.html must define _arpClosest helper function"
    )
    assert "webkitMatchesSelector" in source, (
        "base.html's _arpClosest must support webkitMatchesSelector for old browsers"
    )


def test_capture_handler_sets_handled_flag():
    """The capture-phase handler must set e.__contentModalHandled to skip bubbling handler."""
    source = _base_source()

    assert "__contentModalHandled" in source, (
        "Capture handler must set e.__contentModalHandled flag"
    )


def test_bubble_handler_skips_handled():
    """The bubble-phase .show-more handler must check __contentModalHandled."""
    source = _base_source()

    # The bubble handler should skip if the flag is set
    assert "__contentModalHandled" in source, (
        "Bubble handler must check e.__contentModalHandled to avoid double handling"
    )


# ── Conversation / Timeline backward compatibility ────────────────────


def test_conversation_buttons_still_use_nested_templates():
    """Conversation tab buttons must still have nested <template> for backward compat."""
    source = _session_source()

    # Find Conversation buttons (they're in the msg msg--user/assistant blocks)
    conv_m = re.search(
        r'<div class="msg msg--user.*?</div>\s*</div>',
        source,
        re.DOTALL,
    )
    assert conv_m, "Conversation msg--user block not found"
    conv_block = conv_m.group()

    if "show-more" in conv_block:
        # If a show-more button exists, it should have nested templates
        btn_m = re.search(r'<button class="show-more".*?</button>', conv_block, re.DOTALL)
        if btn_m:
            btn_html = btn_m.group()
            assert "<template>" in btn_html, (
                "Conversation button should still use nested templates for backward compat"
            )


def test_timeline_buttons_still_use_nested_templates():
    """Timeline tab uses the timeline_node macro for round detail rendering."""
    source = _session_source()

    # After refactoring, timeline detail uses the timeline macro instead of
    # inline buttons. Verify the macro is imported and used.
    assert 'from "components/timeline.html" import timeline_node' in source, \
        "Timeline tab should import timeline_node macro"
    assert "build_timeline_nodes" in source, \
        "Timeline tab should define build_timeline_nodes helper"
    assert "timeline-structured" in source, \
        "Timeline tab should contain timeline-structured container"
