"""TASK-035: Session Detail QA 与回归测试

Covers:
- 4 个 tab 渲染：Conversation, Timeline, Hotspots, Profile
- Tab 按钮与 data-tab 属性对应
- Viewer modal 渲染（content-modal）
- Profile inspector 渲染（LLM inspector modal + openLLMInspector）
- Tab 切换 JS 函数存在
- 各 tab 基本结构元素完整
"""

from __future__ import annotations

import re
from pathlib import Path

TEMPLATE_DIR = Path(__file__).parent.parent / "src" / "session_browser" / "web" / "templates"


def _session_source():
    return (TEMPLATE_DIR / "session.html").read_text(encoding="utf-8")


def _base_source():
    return (TEMPLATE_DIR / "base.html").read_text(encoding="utf-8")


# ──────────────────────────────────────────────────────────────────────
# Tab 按钮
# ──────────────────────────────────────────────────────────────────────

TAB_NAMES = ["conversation", "timeline", "hotspots", "profile"]


class TestTabButtons:
    """Verify each tab has a corresponding button with data-tab attribute."""

    def _source(self):
        return _session_source()

    def test_four_tab_buttons_exist(self):
        source = self._source()
        for name in TAB_NAMES:
            assert f'data-tab="{name}"' in source, f"Missing tab button for: {name}"

    def test_tab_buttons_are_buttons_not_divs(self):
        source = self._source()
        for name in TAB_NAMES:
            pattern = f'<button class="tab"'
            assert pattern in source, f"Tab buttons must be <button> elements"

    def test_conversation_tab_button_active_by_default(self):
        source = self._source()
        # The first tab button should have 'active' class
        assert 'class="tab active" data-tab="conversation"' in source or \
               'class="tab active"' in source, \
               "Conversation tab button should be active by default"

    def test_switchTab_js_exists(self):
        source = self._source()
        assert "switchTab" in source, "switchTab JS function must exist for tab switching"

    def test_tab_button_onclick_calls_switchTab(self):
        source = self._source()
        for name in TAB_NAMES:
            assert f"onclick=\"switchTab('{name}')\"" in source, \
                f"Tab button for {name} must call switchTab('{name}')"


# ──────────────────────────────────────────────────────────────────────
# Tab 内容面板
# ──────────────────────────────────────────────────────────────────────

class TestTabContentPanels:
    """Verify each tab has a matching content panel with correct id."""

    def _source(self):
        return _session_source()

    def test_four_tab_content_panels_exist(self):
        source = self._source()
        for name in TAB_NAMES:
            assert f'id="{name}"' in source, f"Missing content panel id: {name}"
            assert f'class="tab-content' in source, "Tab content panels must have tab-content class"

    def test_conversation_panel_active_by_default(self):
        source = self._source()
        assert 'id="conversation" class="tab-content active"' in source, \
            "Conversation panel should be active by default"

    def test_tab_id_matches_button_data_tab(self):
        """Each tab content id must match a button's data-tab value."""
        source = self._source()
        for name in TAB_NAMES:
            has_button = f'data-tab="{name}"' in source
            has_panel = f'id="{name}"' in source
            assert has_button and has_panel, \
                f"Tab {name}: button={has_button}, panel={has_panel} — both required"


# ──────────────────────────────────────────────────────────────────────
# Conversation tab
# ──────────────────────────────────────────────────────────────────────

class TestConversationTab:
    """Verify Conversation tab renders messages with viewer component."""

    def _source(self):
        return _session_source()

    def test_has_msg_flow_container(self):
        source = self._source()
        assert 'class="msg-flow"' in source, "Conversation tab must have msg-flow container"

    def test_has_user_message_block(self):
        source = self._source()
        assert 'msg--user' in source, "Must have user message block"

    def test_has_assistant_message_block(self):
        source = self._source()
        assert 'msg--assistant' in source, "Must have assistant message block"

    def test_uses_viewer_component_in_parts_mode(self):
        source = self._source()
        assert "viewer(" in source, "Conversation tab should use viewer component"
        assert "mode='parts'" in source, "Viewer should use parts mode for messages"

    def test_show_more_button_for_long_content(self):
        source = self._source()
        assert 'class="show-more"' in source, "Must have show-more button for long messages"
        assert "openContentModal" in source, "show-more must trigger content modal"

    def test_has_all_messages_card_title(self):
        source = self._source()
        assert "All Messages" in source, "Conversation tab should have 'All Messages' title"

    def test_round_index_displayed(self):
        source = self._source()
        assert "Round #" in source, "Round index must be displayed in messages"


# ──────────────────────────────────────────────────────────────────────
# Timeline tab
# ──────────────────────────────────────────────────────────────────────

class TestTimelineTab:
    """Verify Timeline tab has conversation flow table and controls."""

    def _source(self):
        return _session_source()

    def test_has_conversation_flow_title(self):
        source = self._source()
        assert "Conversation Flow" in source, "Timeline must have 'Conversation Flow' title"

    def test_has_timeline_toolbar(self):
        source = self._source()
        assert 'class="timeline-toolbar"' in source, "Timeline must have toolbar"

    def test_has_expand_all_button(self):
        source = self._source()
        assert 'data-action="expand-all"' in source, "Timeline must have Expand All button"

    def test_has_collapse_all_button(self):
        source = self._source()
        assert 'data-action="collapse-all"' in source, "Timeline must have Collapse All button"

    def test_has_filter_buttons(self):
        source = self._source()
        for filt in ["all", "message", "tool", "error"]:
            assert f'data-filter="{filt}"' in source, \
                f"Timeline must have filter button for: {filt}"

    def test_has_jump_to_node(self):
        source = self._source()
        assert "timeline-jump-input" in source, "Timeline must have jump-to-node input"

    def test_has_round_summary_table(self):
        source = self._source()
        assert 'class="round-summary-table"' in source, "Timeline must have round summary table"

    def test_table_has_required_columns(self):
        source = self._source()
        # Verify table header columns exist
        for col in ["#", "Preview", "Signal", "Tokens", "LLM", "Tools", "Time"]:
            assert f"<th>{col}</th>" in source or f'<th class="numeric">{col}</th>' in source, \
                f"Table must have column: {col}"

    def test_has_round_detail_row(self):
        source = self._source()
        assert "round-detail-row" in source, "Must have expandable round detail row"

    def test_has_timeline_container_for_detail(self):
        source = self._source()
        assert 'id="timeline-round-' in source, "Round detail must have timeline container"

    def test_has_build_timeline_nodes_macro(self):
        source = self._source()
        assert "build_timeline_nodes" in source, "Timeline must define build_timeline_nodes macro"

    def test_imports_timeline_component(self):
        source = self._source()
        assert 'from "components/timeline.html" import' in source, \
            "Timeline must import timeline component macros"

    def test_toggleRoundDetail_js(self):
        source = self._source()
        assert "toggleRoundDetail" in source, "Must have toggleRoundDetail JS function"

    def test_TimelineCtrl_js(self):
        source = self._source()
        assert "TimelineCtrl" in source, "Must have TimelineCtrl JS for expand/collapse/filter"


# ──────────────────────────────────────────────────────────────────────
# Hotspots tab
# ──────────────────────────────────────────────────────────────────────

class TestHotspotsTab:
    """Verify Hotspots tab has diagnostic display."""

    def _source(self):
        return _session_source()

    def test_has_hotspots_container(self):
        source = self._source()
        assert 'class="hotspots-diagnostic"' in source, "Hotspots must have diagnostic container"

    def test_has_hotspots_count_display(self):
        source = self._source()
        assert "hotspots-diagnostic__count" in source, "Hotspots must show item count"

    def test_has_severity_badges(self):
        source = self._source()
        assert "badge--anomaly-critical" in source, "Hotspots must have critical severity badge"
        assert "badge--anomaly-warning" in source, "Hotspots must have warning severity badge"

    def test_has_hotspot_item_structure(self):
        source = self._source()
        assert "hotspot-item" in source, "Hotspots must have hotspot-item structure"
        assert "hotspot-item__round" in source, "Hotspot items must show round number"
        assert "hotspot-item__type" in source, "Hotspot items must show type"
        assert "hotspot-item__reason" in source, "Hotspot items must show reason"

    def test_has_jump_to_round_button(self):
        source = self._source()
        assert "hotspot-item__jump-btn" in source or "hotspot-item__jump" in source, \
            "Hotspot items must have jump-to-round button"

    def test_has_HotspotsCtrl_js(self):
        source = self._source()
        assert "HotspotsCtrl" in source, "Must have HotspotsCtrl JS for jump"

    def test_has_empty_state(self):
        source = self._source()
        assert "hotspots-diagnostic__empty" in source, "Hotspots must have empty state for no anomalies"


# ──────────────────────────────────────────────────────────────────────
# Profile tab
# ──────────────────────────────────────────────────────────────────────

class TestProfileTab:
    """Verify Profile tab lazy-loads via template and has LLM calls table."""

    def _source(self):
        return _session_source()

    def test_profile_tab_has_lazy_placeholder(self):
        source = self._source()
        assert 'class="profile-lazy-placeholder"' in source, \
            "Profile tab must have lazy-load placeholder"

    def test_profile_template_exists(self):
        source = self._source()
        assert '<template id="profile-template">' in source, \
            "Profile content must be inside <template id='profile-template'>"

    def test_has_llm_calls_detail_table(self):
        source = self._source()
        assert "LLM Calls Detail" in source, "Profile must have LLM Calls Detail section"
        assert 'class="data-table"' in source, "Profile must have data-table for LLM calls"

    def test_llm_table_columns(self):
        source = self._source()
        for col in ["#", "Round", "Scope", "Model", "Input", "Output", "Tools", "Preview", "Time", "Inspect"]:
            assert f"<th>{col}</th>" in source or f'<th class="numeric">{col}</th>' in source, \
                f"LLM table must have column: {col}"

    def test_has_inspect_button(self):
        source = self._source()
        assert 'class="inspect-btn"' in source, "LLM rows must have inspect button"
        assert "openLLMInspector" in source, "Inspect button must call openLLMInspector"

    def test_inspect_button_has_required_data_attrs(self):
        source = self._source()
        assert "data-call-idx=" in source, "Inspect button must have data-call-idx"
        assert "data-model=" in source, "Inspect button must have data-model"
        assert "data-scope=" in source, "Inspect button must have data-scope"
        assert "data-round=" in source, "Inspect button must have data-round"

    def test_has_request_context_display(self):
        source = self._source()
        assert "Request Context:" in source, "Profile must show request context"

    def test_has_response_display(self):
        source = self._source()
        assert "Response:" in source, "Profile must show response"

    def test_has_tool_calls_display(self):
        source = self._source()
        assert "Tool Calls" in source, "Profile must show tool calls"

    def test_has_raw_session_data(self):
        source = self._source()
        assert "Raw Session Data" in source, "Profile must have Raw Session Data section"

    def test_openLLMInspector_retrieves_templates(self):
        source = self._source()
        assert "getElementById('llm-call-" in source, \
            "openLLMInspector must retrieve content from hidden templates"

    def test_has_inspector_template_ids(self):
        source = self._source()
        assert "inspect-request" in source, "Must have inspect-request template id pattern"
        assert "inspect-response" in source, "Must have inspect-response template id pattern"


# ──────────────────────────────────────────────────────────────────────
# Viewer modal (content-modal)
# ──────────────────────────────────────────────────────────────────────

class TestContentViewerModal:
    """Verify shared content modal for viewing message/tool content."""

    def _source(self):
        return _session_source()

    def test_content_modal_element_exists(self):
        source = self._source()
        assert 'id="content-modal"' in source, "content-modal element must exist"

    def test_content_modal_has_header(self):
        source = self._source()
        assert 'class="content-modal__header"' in source, "Modal must have header"

    def test_content_modal_has_title(self):
        source = self._source()
        assert 'class="content-modal__title"' in source, "Modal must have title element"

    def test_content_modal_has_markdown_tab(self):
        source = self._source()
        assert 'data-view="markdown"' in source, "Modal must have Markdown tab"

    def test_content_modal_has_raw_tab(self):
        source = self._source()
        assert 'data-view="raw"' in source, "Modal must have Raw tab"

    def test_content_modal_has_close_button(self):
        source = self._source()
        assert "content-modal__close" in source, "Modal must have close button"

    def test_content_modal_has_markdown_section(self):
        source = self._source()
        assert 'class="content-modal__markdown"' in source, "Modal must have markdown section"

    def test_content_modal_has_raw_section(self):
        source = self._source()
        assert 'class="content-modal__raw"' in source, "Modal must have raw section"

    def test_closeContentModal_js(self):
        source = self._source()
        assert "closeContentModal" in source, "Must have closeContentModal JS function"

    def test_switchContentView_js(self):
        source = self._source()
        assert "switchContentView" in source, "Must have switchContentView JS function"

    def test_escape_key_closes_modal(self):
        source = self._source()
        # The keydown listener for Escape must be present
        assert "Escape" in source, "Must handle Escape key"

    def test_click_outside_closes(self):
        source = self._source()
        # onclick="if(event.target===this)closeContentModal()"
        assert "event.target===this" in source, "Click outside modal must close it"


# ──────────────────────────────────────────────────────────────────────
# Profile Inspector modal
# ──────────────────────────────────────────────────────────────────────

class TestProfileInspector:
    """Verify inspector modal is properly wired from Profile tab."""

    def _source(self):
        return _session_source()

    def _base(self):
        return _base_source()

    def test_openInspector_available(self):
        source = self._source()
        assert "window.openInspector" in source, \
            "openLLMInspector must check for window.openInspector"

    def test_inspector_viewers_rendered(self):
        source = self._source()
        assert "inspector-sub-viewer" in source, \
            "Inspector must render sub-viewer panels for request/response"

    def test_inspector_request_viewer(self):
        source = self._source()
        assert "viewer__raw-pre" in source, \
            "Inspector must use viewer raw pre for request display"

    def test_inspector_has_metadata(self):
        source = self._source()
        assert "openInspector({" in source, "Must call openInspector with config object"
        assert "'Call #'" in source or '"Call #"' in source, \
            "Inspector metadata must include Call #"

    def test_inspector_html_escaping(self):
        source = self._source()
        # Inspector must escape HTML to prevent XSS in raw viewer
        assert "replace" in source and "&amp;" in source, \
            "Inspector must escape HTML entities in raw content"

    def test_inspector_base_template_has_modal(self):
        base = self._base()
        # The actual inspector modal container should be in base.html
        assert "inspector" in base.lower(), "base.html must contain inspector references"


# ──────────────────────────────────────────────────────────────────────
# Tab 结构完整性（回归）
# ──────────────────────────────────────────────────────────────────────

class TestTabStructuralIntegrity:
    """Verify overall tab structure is consistent and not broken."""

    def _source(self):
        return _session_source()

    def test_tabs_container(self):
        source = self._source()
        assert 'class="tabs"' in source, "Tabs must be wrapped in tabs container"

    def test_exactly_four_tab_buttons(self):
        source = self._source()
        # Count tab buttons
        buttons = re.findall(r'class="tab[^"]*".*?data-tab="[^"]*"', source)
        assert len(buttons) == 4, f"Expected 4 tab buttons, found {len(buttons)}"

    def test_exactly_four_tab_content_panels(self):
        source = self._source()
        panels = re.findall(r'class="tab-content[^"]*"', source)
        assert len(panels) == 4, f"Expected 4 tab-content panels, found {len(panels)}"

    def test_only_one_active_tab(self):
        source = self._source()
        active_tabs = re.findall(r'class="tab active"', source)
        assert len(active_tabs) == 1, \
            f"Expected exactly 1 active tab, found {len(active_tabs)}"

    def test_no_duplicate_ids(self):
        source = self._source()
        for name in TAB_NAMES:
            ids = re.findall(rf'id="{name}"', source)
            assert len(ids) == 1, f"Tab id '{name}' should appear exactly once, found {len(ids)}"

    def test_session_id_set_for_js(self):
        source = self._source()
        assert "window._sessionId" in source, "Session ID must be set for JS state persistence"

    def test_content_modal_has_visible_class_toggle(self):
        source = self._source()
        assert "classList.add('visible')" in source, \
            "Modal must use classList.add('visible') to show"
        assert "classList.remove('visible')" in source, \
            "Modal must use classList.remove('visible') to hide"
