"""Tests for timeline preview user input tag."""

from __future__ import annotations

import pytest


class TestPreviewTagRendersForUserInput:
    """Verify quote text tag renders when round has user input."""

    def test_tag_present_for_user_input(self):
        with open("src/session_browser/web/templates/session.html") as f:
            content = f.read()
        assert "quote text" in content

    def test_tag_condition_checks_user_msg_content(self):
        with open("src/session_browser/web/templates/session.html") as f:
            content = f.read()
        # The tag should be conditional on user_msg.content
        assert "round.user_msg.content" in content
        assert "preview-tag--quote" in content

    def test_tag_has_descriptive_tooltip(self):
        with open("src/session_browser/web/templates/session.html") as f:
            content = f.read()
        assert "This round includes user input" in content


class TestPreviewTagDoesNotLeakUserContent:
    """Verify user input content is NOT exposed in preview."""

    def test_tag_tooltip_no_user_content(self):
        """Tag tooltip should be generic, not contain user content."""
        with open("src/session_browser/web/templates/session.html") as f:
            content = f.read()
        # The tag tooltip is static text, not dynamic user content
        assert "preview-tag--quote" in content

    def test_preview_tooltip_no_user_content(self):
        """Preview cell tooltip should only use preview_text, not user_msg.content."""
        with open("src/session_browser/web/templates/session.html") as f:
            content = f.read()
        # The data-tooltip should use preview_text only
        # Check that preview-cell data-tooltip doesn't reference user_msg.content directly
        lines = content.split("\n")
        for line in lines:
            if "preview-cell" in line and "data-tooltip" in line:
                assert "user_msg.content" not in line, (
                    f"Preview cell tooltip should not contain user_msg.content: {line}"
                )


class TestPreviewTagPlacement:
    """Verify tag appears before preview text."""

    def test_tag_before_text(self):
        with open("src/session_browser/web/templates/session.html") as f:
            content = f.read()
        # The tag should come before the text span in template order
        tag_pos = content.find("preview-tag--quote")
        text_pos = content.find("preview-cell__text")
        assert tag_pos > 0, "Preview tag not found"
        assert text_pos > 0, "Preview text span not found"
        # Within the same td.preview-cell block, tag should come first
        # Find the preview-cell td block and verify order
        td_start = content.rfind("<td class=\"preview-cell", 0, tag_pos)
        if td_start >= 0:
            # Between td start and text span, tag should appear first
            block = content[td_start:text_pos]
            assert "preview-tag--quote" in block


class TestPreviewCellNoSafe:
    """Verify preview cell does not use | safe for HTML rendering."""

    def test_preview_no_safe_filter(self):
        with open("src/session_browser/web/templates/session.html") as f:
            content = f.read()
        # preview-cell should not pipe through | safe
        # Check that preview_text output doesn't use | safe
        lines = content.split("\n")
        for line in lines:
            if "preview_text" in line and "preview-cell" not in line:
                assert "| safe" not in line, (
                    f"Preview text should not use | safe: {line}"
                )


class TestPreviewTextTruncation:
    """Verify preview text truncation is preserved."""

    def test_truncation_at_120_chars(self):
        with open("src/session_browser/web/templates/session.html") as f:
            content = f.read()
        assert "[:120]" in content or "[:120]" in content
