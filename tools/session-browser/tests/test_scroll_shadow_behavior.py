"""Tests for scroll shadow behavior check script.

These tests verify the static analysis logic in check_scroll_shadow_behavior.py
using synthetic CSS/JS inputs to cover pass, fail, and warning cases.

Usage:
    cd tools/session-browser
    ./scripts/session-browser.sh test tests/test_scroll_shadow_behavior.py
"""

from __future__ import annotations

import pytest


class TestRightShadowCSS:
    """Verify right shadow (.table-wrap::after) detection."""

    def test_right_shadow_present(self):
        css = """
        .table-wrap { position: relative; overflow-x: auto; }
        .table-wrap::after {
            content: '';
            position: absolute;
            top: 0; right: 0; bottom: 0;
            width: 40px;
            background: linear-gradient(to right, transparent, var(--surface));
            pointer-events: none;
        }
        """
        from scripts.check_scroll_shadow_behavior import check_right_shadow
        from scripts.check_scroll_shadow_behavior import _reset_counters
        _reset_counters()
        check_right_shadow(css)
        from scripts.check_scroll_shadow_behavior import _pass, _fail
        assert _pass >= 1
        assert _fail == 0

    def test_right_shadow_missing(self):
        css = ".table-wrap { overflow-x: auto; }"
        from scripts.check_scroll_shadow_behavior import check_right_shadow, _reset_counters
        _reset_counters()
        check_right_shadow(css)
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail >= 1


class TestLeftShadowCSS:
    """Verify left shadow (.table-wrap::before) detection."""

    def test_left_shadow_present(self):
        css = """
        .table-wrap::before {
            content: '';
            position: absolute;
            top: 0; left: 0; bottom: 0;
            width: 40px;
            background: linear-gradient(to left, transparent, var(--surface));
            opacity: 0;
            pointer-events: none;
        }
        .table-wrap.scrolled-left::before { opacity: 1; }
        """
        from scripts.check_scroll_shadow_behavior import check_left_shadow, _reset_counters
        _reset_counters()
        check_left_shadow(css)
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail == 0

    def test_left_shadow_missing(self):
        css = """
        .table-wrap::after { content: ''; }
        """
        from scripts.check_scroll_shadow_behavior import check_left_shadow, _reset_counters
        _reset_counters()
        check_left_shadow(css)
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail >= 1


class TestShadowBinding:
    """Verify shadows are bound to .table-wrap scroll container."""

    def test_proper_binding(self):
        css = ".table-wrap { position: relative; overflow-x: auto; }"
        from scripts.check_scroll_shadow_behavior import check_shadow_binding, _reset_counters
        _reset_counters()
        check_shadow_binding(css)
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail == 0

    def test_missing_position_relative(self):
        css = ".table-wrap { overflow-x: auto; }"
        from scripts.check_scroll_shadow_behavior import check_shadow_binding, _reset_counters
        _reset_counters()
        check_shadow_binding(css)
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail >= 1

    def test_missing_overflow_auto(self):
        css = ".table-wrap { position: relative; }"
        from scripts.check_scroll_shadow_behavior import check_shadow_binding, _reset_counters
        _reset_counters()
        check_shadow_binding(css)
        from scripts.check_scroll_shadow_behavior import _warn
        assert _warn >= 1


class TestStateRules:
    """Verify CSS state rules for shadow visibility."""

    def test_scrolled_right_hide(self):
        css = """
        .table-wrap::before { content: ''; opacity: 0; }
        .table-wrap.scrolled-left::before { opacity: 1; }
        .table-wrap.scrolled-right::after {
            opacity: 0;
            transition: opacity 0.2s;
        }
        """
        from scripts.check_scroll_shadow_behavior import check_state_rules, _reset_counters
        _reset_counters()
        check_state_rules(css)
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail == 0

    def test_scrolled_right_without_opacity(self):
        css = """.table-wrap.scrolled-right { color: red; }"""
        from scripts.check_scroll_shadow_behavior import check_state_rules, _reset_counters
        _reset_counters()
        check_state_rules(css)
        from scripts.check_scroll_shadow_behavior import _warn
        # Should warn or fail, not pass
        from scripts.check_scroll_shadow_behavior import _pass
        assert _pass == 0

    def test_left_shadow_state_rule_present(self):
        css = """
        .table-wrap::before { content: ''; opacity: 0; }
        .table-wrap.scrolled-left::before { opacity: 1; }
        .table-wrap.scrolled-right::after { opacity: 0; }
        """
        from scripts.check_scroll_shadow_behavior import check_state_rules, _reset_counters
        _reset_counters()
        check_state_rules(css)
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail == 0

    def test_left_shadow_state_rule_missing(self):
        css = """
        .table-wrap::before { content: ''; }
        """
        from scripts.check_scroll_shadow_behavior import check_state_rules, _reset_counters
        _reset_counters()
        check_state_rules(css)
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail >= 1


class TestPointerEvents:
    """Verify pointer-events:none on shadow pseudo-elements."""

    def test_after_has_pointer_events_none(self):
        css = """
        .table-wrap::after {
            content: '';
            pointer-events: none;
        }
        """
        from scripts.check_scroll_shadow_behavior import check_pointer_events, _reset_counters
        _reset_counters()
        check_pointer_events(css)
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail == 0

    def test_after_missing_pointer_events(self):
        css = ".table-wrap::after { content: ''; }"
        from scripts.check_scroll_shadow_behavior import check_pointer_events, _reset_counters
        _reset_counters()
        check_pointer_events(css)
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail >= 1


class TestScrollListener:
    """Verify JS scroll event and scrollLeft handling."""

    def test_scroll_listener_present(self):
        js = """document.addEventListener('scroll', function(e) {
            var wrap = e.target.closest('.table-wrap');
        }, true);"""
        from scripts.check_scroll_shadow_behavior import check_scroll_listener, _reset_counters
        _reset_counters()
        check_scroll_listener(js, "")
        from scripts.check_scroll_shadow_behavior import _pass
        assert _pass >= 1

    def test_scrollleft_present(self):
        js = "var isAtRight = wrap.scrollLeft + wrap.clientWidth >= wrap.scrollWidth - 2;"
        from scripts.check_scroll_shadow_behavior import check_scroll_listener, _reset_counters
        _reset_counters()
        check_scroll_listener(js, "")
        from scripts.check_scroll_shadow_behavior import _pass
        assert _pass >= 1

    def test_scrolled_left_toggle_missing(self):
        js = """
        document.addEventListener('scroll', function(e) {
            var wrap = e.target.closest('.table-wrap');
            if (!wrap) return;
            var isAtRight = wrap.scrollLeft + wrap.clientWidth >= wrap.scrollWidth - 2;
            if (isAtRight) {
                wrap.classList.add('scrolled-right');
            } else {
                wrap.classList.remove('scrolled-right');
            }
        }, true);
        """
        from scripts.check_scroll_shadow_behavior import check_scroll_listener, _reset_counters
        _reset_counters()
        check_scroll_listener(js, "")
        from scripts.check_scroll_shadow_behavior import _fail
        # scrolled-left toggle should be missing
        assert _fail >= 1

    def test_scrolled_left_toggle_present(self):
        js = """
        document.addEventListener('scroll', function(e) {
            var wrap = e.target.closest('.table-wrap');
            if (!wrap) return;
            var isAtLeft = wrap.scrollLeft === 0;
            var isAtRight = wrap.scrollLeft + wrap.clientWidth >= wrap.scrollWidth - 2;
            wrap.classList.toggle('scrolled-left', !isAtLeft);
            wrap.classList.toggle('scrolled-right', isAtRight);
        }, true);
        """
        from scripts.check_scroll_shadow_behavior import check_scroll_listener, _reset_counters
        _reset_counters()
        check_scroll_listener(js, "")
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail == 0


class TestInitRefresh:
    """Verify init/resize/refresh coverage."""

    def test_resize_listener_present(self):
        js = "window.addEventListener('resize', function() { /* refresh */ });"
        from scripts.check_scroll_shadow_behavior import check_init_refresh, _reset_counters
        _reset_counters()
        check_init_refresh(js, "", "")
        from scripts.check_scroll_shadow_behavior import _pass
        assert _pass >= 1

    def test_resize_listener_missing(self):
        js = ""
        from scripts.check_scroll_shadow_behavior import check_init_refresh, _reset_counters
        _reset_counters()
        check_init_refresh(js, "", "")
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail >= 1

    def test_init_function_present(self):
        js = """
        function initScrollShadows() {
            document.querySelectorAll('.table-wrap').forEach(function(w) {
                w.classList.toggle('scrolled-left', w.scrollLeft > 0);
            });
        }
        window.addEventListener('resize', function() { initScrollShadows(); });
        """
        from scripts.check_scroll_shadow_behavior import check_init_refresh, _reset_counters
        _reset_counters()
        check_init_refresh(js, "", "")
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail == 0

    def test_init_function_missing(self):
        js = "// no init function"
        from scripts.check_scroll_shadow_behavior import check_init_refresh, _reset_counters
        _reset_counters()
        check_init_refresh(js, "", "")
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail >= 1


class TestTableWrapUsage:
    """Verify .table-wrap usage in HTML templates."""

    def test_timeline_table_wrap(self):
        session_html = '<div class="table-wrap"><table>...</table></div>'
        base_html = ""
        from scripts.check_scroll_shadow_behavior import check_table_wrap_usage, _reset_counters
        _reset_counters()
        check_table_wrap_usage(session_html, base_html)
        from scripts.check_scroll_shadow_behavior import _pass
        assert _pass >= 1

    def test_profile_table_wrap(self):
        session_html = '<div class="profile-table-wrap">...</div>'
        base_html = ""
        from scripts.check_scroll_shadow_behavior import check_table_wrap_usage, _reset_counters
        _reset_counters()
        check_table_wrap_usage(session_html, base_html)
        from scripts.check_scroll_shadow_behavior import _pass
        assert _pass >= 1

    def test_no_table_wrap_class(self):
        session_html = '<div><table>...</table></div>'
        base_html = ""
        from scripts.check_scroll_shadow_behavior import check_table_wrap_usage, _reset_counters
        _reset_counters()
        check_table_wrap_usage(session_html, base_html)
        from scripts.check_scroll_shadow_behavior import _warn
        assert _warn >= 1


class TestIntegration:
    """Integration-style tests using synthetic minimal fixtures."""

    def test_full_pass_scenario(self):
        """A fully compliant CSS + JS should produce no failures."""
        css = """
        .table-wrap { position: relative; overflow-x: auto; }
        .table-wrap::before {
            content: ''; position: absolute; top: 0; left: 0; bottom: 0;
            width: 40px; background: linear-gradient(to left, transparent, var(--surface));
            pointer-events: none; opacity: 0;
        }
        .table-wrap::after {
            content: ''; position: absolute; top: 0; right: 0; bottom: 0;
            width: 40px; background: linear-gradient(to right, transparent, var(--surface));
            pointer-events: none;
        }
        .table-wrap.scrolled-left::before { opacity: 1; }
        .table-wrap.scrolled-right::after { opacity: 0; transition: opacity 0.2s; }
        .profile-table-wrap { overflow-x: auto; }
        """
        js = """
        function initScrollShadows() {
            document.querySelectorAll('.table-wrap').forEach(wrap => updateWrapShadow(wrap));
        }
        function updateWrapShadow(wrap) {
            wrap.classList.toggle('scrolled-left', wrap.scrollLeft > 0);
            wrap.classList.toggle('scrolled-right',
                wrap.scrollLeft + wrap.clientWidth >= wrap.scrollWidth - 2);
        }
        document.addEventListener('scroll', function(e) {
            var wrap = e.target.closest('.table-wrap');
            if (wrap) updateWrapShadow(wrap);
        }, true);
        window.addEventListener('resize', function() { initScrollShadows(); });
        document.addEventListener('DOMContentLoaded', initScrollShadows);
        """
        from scripts.check_scroll_shadow_behavior import (
            check_right_shadow, check_left_shadow, check_shadow_binding,
            check_state_rules, check_pointer_events, check_scroll_listener,
            check_init_refresh, _reset_counters
        )
        _reset_counters()
        check_right_shadow(css)
        check_left_shadow(css)
        check_shadow_binding(css)
        check_state_rules(css)
        check_pointer_events(css)
        check_scroll_listener(js, "")
        check_init_refresh(js, "", css)
        from scripts.check_scroll_shadow_behavior import _fail
        assert _fail == 0
