"""Tests for Sessions page table restructure."""

from __future__ import annotations

import pytest


class TestSessionsTemplateColumns:
    """Verify sessions.html has the correct restructured columns."""

    def test_has_title_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Title</th>" in content

    def test_has_project_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Project</th>" in content

    def test_has_agent_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Agent</th>" in content

    def test_has_model_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Model</th>" in content

    def test_has_tokens_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Tokens</th>" in content

    def test_has_output_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Output</th>" in content

    def test_has_tools_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Tools</th>" in content

    def test_has_duration_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Duration</th>" in content

    def test_has_anomaly_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Anomaly</th>" in content

    def test_has_time_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Time</th>" in content


class TestSessionsTemplateRemovedColumns:
    """Verify removed columns are no longer present."""

    def test_no_standalone_dot_column(self):
        """No empty dot th element."""
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        # Should not have an empty th with agent-dot inside
        assert "class=\"agent-dot" not in content

    def test_no_cache_r_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Cache R</th>" not in content

    def test_no_cache_w_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Cache W</th>" not in content

    def test_no_output_percent_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Output%</th>" not in content

    def test_no_standalone_failed_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Failed</th>" not in content

    def test_no_tools_per_round_column(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert ">Tools/R</th>" not in content


class TestSessionsTemplateFailedMerged:
    """Verify failed info is merged into Tools column."""

    def test_tools_cell_shows_failed_badge(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        # Should have failed badge inside tools cell
        assert "badge-error" in content
        # The pattern should show failed count with 'f' suffix
        assert "failed_tool_count" in content


class TestSessionsTemplateAnomalyCell:
    """Verify anomaly cell is readable."""

    def test_anomaly_has_tooltip(self):
        """Anomaly cell should have data-tooltip with full reason."""
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert "data-tooltip" in content
        assert "anomaly-cell" in content

    def test_anomaly_limits_to_two_badges(self):
        """Should show at most 2 badges inline."""
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert "s.anomalies[:2]" in content

    def test_anomaly_plus_badge_for_extra(self):
        """Should show +N for anomalies beyond 2."""
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert "length > 2" in content


class TestSessionsTemplateSortOptions:
    """Verify sort options are correct."""

    def test_has_total_tokens_sort(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert "Sort: Tokens" in content

    def test_no_input_tokens_sort(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert "Sort: Input Tokens" not in content

    def test_has_failed_tools_sort(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert "Sort: Failed Tools" in content


class TestSessionsTemplateDataAttributes:
    """Verify data attributes are updated for new column structure."""

    def test_has_total_tokens_data_attr(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert "data-total-tokens=" in content

    def test_no_cache_data_attrs(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        assert "data-total-cache-r=" not in content
        assert "data-total-cache-w=" not in content

    def test_agent_column_uses_badge(self):
        with open("src/session_browser/web/templates/sessions.html") as f:
            content = f.read()
        # Agent should use badge, not separate dot column
        assert "badge-claude" in content
        assert "badge-qoder" in content
        assert "badge-codex" in content
