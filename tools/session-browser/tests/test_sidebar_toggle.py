"""Tests for sidebar collapse toggle in base.html."""

from __future__ import annotations


class TestSidebarToggleButton:
    """Verify sidebar toggle button exists with correct attributes."""

    def test_toggle_button_exists(self):
        """A <button class="sidebar-toggle"> should be present."""
        with open("src/session_browser/web/templates/base.html") as f:
            content = f.read()
        assert 'class="sidebar-toggle"' in content

    def test_button_not_div(self):
        """Toggle must be a real <button>, not a <div>."""
        with open("src/session_browser/web/templates/base.html") as f:
            content = f.read()
        assert '<button class="sidebar-toggle"' in content
        assert '<div class="sidebar-toggle"' not in content

    def test_has_aria_label(self):
        """Button must have aria-label for screen readers."""
        with open("src/session_browser/web/templates/base.html") as f:
            content = f.read()
        assert 'aria-label=' in content
        assert 'sidebar-toggle' in content

    def test_has_aria_expanded(self):
        """Button must have aria-expanded to convey state."""
        with open("src/session_browser/web/templates/base.html") as f:
            content = f.read()
        assert 'aria-expanded=' in content

    def test_toggle_inside_sidebar(self):
        """Collapse button should be inside the <aside class="sidebar">."""
        with open("src/session_browser/web/templates/base.html") as f:
            content = f.read()
        sidebar_start = content.index('<aside class="sidebar">')
        sidebar_end = content.index('</aside>', sidebar_start)
        sidebar_content = content[sidebar_start:sidebar_end]
        assert 'sidebar-toggle"' in sidebar_content

    def test_expand_button_outside_sidebar(self):
        """Expand button must be outside the sidebar so it stays visible when collapsed."""
        with open("src/session_browser/web/templates/base.html") as f:
            content = f.read()
        sidebar_start = content.index('<aside class="sidebar">')
        sidebar_end = content.index('</aside>', sidebar_start)
        sidebar_content = content[sidebar_start:sidebar_end]
        assert 'sidebar-toggle-expand' not in sidebar_content


class TestSidebarExpandButton:
    """Verify expand button exists and is visible when collapsed."""

    def test_expand_button_exists(self):
        """A <button class="sidebar-toggle-expand"> should be present."""
        with open("src/session_browser/web/templates/base.html") as f:
            content = f.read()
        assert 'class="sidebar-toggle-expand"' in content

    def test_expand_button_has_aria_label(self):
        """Expand button must have aria-label."""
        with open("src/session_browser/web/templates/base.html") as f:
            content = f.read()
        assert 'aria-label=' in content
        assert 'sidebar-toggle-expand' in content

    def test_expand_button_has_aria_expanded(self):
        """Expand button must have aria-expanded."""
        with open("src/session_browser/web/templates/base.html") as f:
            content = f.read()
        assert 'aria-expanded=' in content

    def test_expand_button_css_visible_when_collapsed(self):
        """CSS should show expand button when sidebar is collapsed."""
        with open("src/session_browser/web/static/style.css") as f:
            content = f.read()
        assert ".sidebar-toggle-expand" in content
        assert "body.sidebar-collapsed .sidebar-toggle-expand" in content
        assert "opacity: 1" in content
        assert "pointer-events: auto" in content

    def test_collapse_button_hidden_when_collapsed(self):
        """CSS should hide collapse button when sidebar is collapsed."""
        with open("src/session_browser/web/static/style.css") as f:
            content = f.read()
        assert "body.sidebar-collapsed .sidebar-toggle" in content
        assert "opacity: 0" in content
        assert "pointer-events: none" in content


class TestSidebarPersistence:
    """Verify sidebar collapse state persistence uses arpStorage."""

    def test_persistence_key(self):
        """Should use 'sidebar_collapsed' as the localStorage key."""
        with open("src/session_browser/web/templates/base.html") as f:
            content = f.read()
        assert "'sidebar_collapsed'" in content

    def test_uses_arpstorage_set(self):
        """Should save state via arpStorage.set."""
        with open("src/session_browser/web/templates/base.html") as f:
            content = f.read()
        assert "arpStorage.set(" in content

    def test_uses_arpstorage_get(self):
        """Should restore state via arpStorage.get."""
        with open("src/session_browser/web/templates/base.html") as f:
            content = f.read()
        assert "arpStorage.get(" in content


class TestSidebarCollapsedCSS:
    """Verify CSS supports sidebar-collapsed class."""

    def test_sidebar_collapsed_selector(self):
        """CSS should have body.sidebar-collapsed .sidebar rule."""
        with open("src/session_browser/web/static/style.css") as f:
            content = f.read()
        assert "body.sidebar-collapsed .sidebar" in content

    def test_main_area_zero_margin(self):
        """Collapsed main-area should have margin-left: 0."""
        with open("src/session_browser/web/static/style.css") as f:
            content = f.read()
        assert "body.sidebar-collapsed .main-area" in content
        assert "margin-left: 0" in content

    def test_sidebar_toggle_button_style(self):
        """CSS should style the .sidebar-toggle button."""
        with open("src/session_browser/web/static/style.css") as f:
            content = f.read()
        assert ".sidebar-toggle" in content
