/**
 * Timeline control bar: expand-all, collapse-all, type filter, jump-to.
 *
 * Works with both the round-summary-table (current) and the
 * timeline-structured / timeline-node tree (future).
 *
 * Exposes `window.TimelineCtrl` for inline onclick handlers.
 */
(function () {
    'use strict';

    var _activeFilter = 'all';

    /* ── Expand / Collapse ───────────────────────────────── */

    function expandAll() {
        // Round summary table rows
        var headers = document.querySelectorAll('.round-header-row');
        headers.forEach(function (header) {
            var detailRow = header.nextElementSibling;
            if (detailRow && detailRow.classList.contains('round-detail-row')) {
                if (detailRow.style.display === 'none' || detailRow.style.display === '') {
                    detailRow.style.display = 'table-row';
                    var chevron = header.querySelector('.round-chevron-inline');
                    if (chevron) chevron.style.transform = 'rotate(90deg)';
                }
            }
        });

        // Future: timeline-structured nodes
        var nodes = document.querySelectorAll('.timeline-node:not(.is-expanded)');
        nodes.forEach(function (node) {
            node.classList.add('is-expanded');
        });

        var key = 'rounds_' + (window._sessionId || '');
        if (window.arpStorage && window._sessionId) {
            var allIdx = [];
            headers.forEach(function (h) { if (h.dataset.roundIdx) allIdx.push(h.dataset.roundIdx); });
            window.arpStorage.set(key, allIdx);
        }
    }

    function collapseAll() {
        var headers = document.querySelectorAll('.round-header-row');
        headers.forEach(function (header) {
            var detailRow = header.nextElementSibling;
            if (detailRow && detailRow.classList.contains('round-detail-row')) {
                if (detailRow.style.display !== 'none' && detailRow.style.display !== '') {
                    detailRow.style.display = 'none';
                    var chevron = header.querySelector('.round-chevron-inline');
                    if (chevron) chevron.style.transform = '';
                }
            }
        });

        var nodes = document.querySelectorAll('.timeline-node.is-expanded');
        nodes.forEach(function (node) {
            node.classList.remove('is-expanded');
        });

        if (window.arpStorage && window._sessionId) {
            window.arpStorage.set('rounds_' + window._sessionId, []);
        }
    }

    /* ── Type filter ──────────────────────────────────────── */

    function filter(type) {
        _activeFilter = type;

        // Update active chip
        document.querySelectorAll('.timeline-toolbar__filter').forEach(function (chip) {
            chip.classList.toggle('active', chip.dataset.filter === type);
        });

        if (type === 'all') {
            _showAllNodes();
            return;
        }

        // Filter round summary table rows by type keywords in preview
        var rows = document.querySelectorAll('.round-header-row');
        rows.forEach(function (row) {
            var visible;
            if (type === 'failed') {
                // Failed only: check for error/fail status badges or row--failed class
                visible = row.classList.contains('row--failed') ||
                    !!row.querySelector('[class*="badge-error"], [class*="badge--status-error"]') ||
                    (row.dataset.status && row.dataset.status.toLowerCase().indexOf('fail') >= 0);
            } else if (type === 'expensive') {
                // High token only: check for token data above a threshold
                visible = _isHighTokenRow(row);
            } else {
                var preview = row.querySelector('.preview-cell__text');
                var text = preview ? preview.textContent.toLowerCase() : '';
                visible = _matchesFilter(text, type);
            }
            row.style.display = visible ? '' : 'none';
            // Hide corresponding detail row too
            var detailRow = row.nextElementSibling;
            if (detailRow && detailRow.classList.contains('round-detail-row')) {
                detailRow.style.display = visible ? '' : 'none';
            }
        });

        // Filter future timeline-structured nodes
        var nodes = document.querySelectorAll('.timeline-node');
        nodes.forEach(function (node) {
            var cls = node.className;
            if (type === 'failed') {
                visible = cls.indexOf('--error') >= 0 || cls.indexOf('row--failed') >= 0;
            } else if (type === 'expensive') {
                visible = !!node.querySelector('[data-tokens]') && parseInt(node.dataset.tokens || '0') > 50000;
            } else {
                visible = _nodeMatchesType(cls, type);
            }
            node.style.display = visible ? '' : 'none';
        });
    }

    function _isHighTokenRow(row) {
        // Check for data attributes with raw token counts
        var tokens = row.dataset.tokens || row.dataset.totalTokens;
        if (tokens) {
            var n = parseInt(tokens, 10);
            if (!isNaN(n)) return n > 50000;
        }
        // Fallback: look for formatted token text like "123.4K" or "1.2M"
        var tokenCell = row.querySelector('[class*="token-cell"], td.numeric');
        if (tokenCell) {
            var text = tokenCell.textContent.trim();
            var m = text.match(/^([+-]?\d+\.?\d*)\s*([kKmM])?$/);
            if (m) {
                var val = parseFloat(m[1]);
                var suffix = (m[2] || '').toLowerCase();
                if (suffix === 'k') val *= 1000;
                else if (suffix === 'm') val *= 1000000;
                return val > 50000;
            }
        }
        return false;
    }

    function _matchesFilter(text, type) {
        if (type === 'message') return text.indexOf('user') >= 0 || text.indexOf('assistant') >= 0 || text.indexOf('msg') >= 0;
        if (type === 'tool') return text.indexOf('tool') >= 0 || text.indexOf('bash') >= 0;
        if (type === 'error') return text.indexOf('error') >= 0 || text.indexOf('fail') >= 0;
        return true;
    }

    function _nodeMatchesType(className, type) {
        if (type === 'message') return className.indexOf('timeline-node--message') >= 0;
        if (type === 'tool') return className.indexOf('timeline-node--tool-call') >= 0;
        if (type === 'error') return className.indexOf('timeline-node--error') >= 0;
        return true;
    }

    function _showAllNodes() {
        document.querySelectorAll('.round-header-row').forEach(function (row) {
            row.style.display = '';
            var detailRow = row.nextElementSibling;
            if (detailRow && detailRow.classList.contains('round-detail-row')) {
                detailRow.style.display = '';
            }
        });
        document.querySelectorAll('.timeline-node').forEach(function (node) {
            node.style.display = '';
        });
    }

    /* ── Jump to node ─────────────────────────────────────── */

    function _escapeSelector(s) {
        // CSS.escape polyfill for safe querySelector
        return s.replace(/"/g, '\\"').replace(/\\/g, '\\\\');
    }

    function jumpOnKey(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            jump();
        }
    }

    function jump() {
        var input = document.getElementById('timeline-jump-input');
        if (!input) return;
        var query = input.value.trim();
        if (!query) return;

        var target = null;

        // Try round number first: "#42" or "42" (most common, safest)
        var num = query.replace(/^#/, '');
        if (/^\d+$/.test(num)) {
            target = document.querySelector('.round-header-row[data-round-idx="' + _escapeSelector(num) + '"]');
        }

        // Try getElementById (safe, no selector injection)
        if (!target) {
            target = document.getElementById(query);
        }

        // Try data-timeline-id with escaped selector
        if (!target) {
            try {
                target = document.querySelector('[data-timeline-id="' + _escapeSelector(query) + '"]');
            } catch (e) {
                // Malformed selector, skip
            }
        }

        if (target) {
            // Expand parent if needed
            _ensureVisible(target);

            // Scroll into view
            target.scrollIntoView({ behavior: 'smooth', block: 'center' });

            // Brief highlight
            _flashHighlight(target);
        }
    }

    function _ensureVisible(el) {
        // If inside a collapsed round detail, expand it
        var detailRow = el.closest('.round-detail-row');
        if (detailRow && detailRow.style.display === 'none') {
            var headerRow = detailRow.previousElementSibling;
            if (headerRow && headerRow.classList.contains('round-header-row')) {
                if (window.toggleRoundDetail) {
                    window.toggleRoundDetail(headerRow);
                }
            }
        }
        // Expand timeline-node parents
        var parent = el.parentElement;
        while (parent) {
            if (parent.classList && parent.classList.contains('timeline-node') &&
                !parent.classList.contains('is-expanded')) {
                parent.classList.add('is-expanded');
            }
            parent = parent.parentElement;
        }
    }

    function _flashHighlight(el) {
        el.classList.add('timeline-node--jump-target');
        setTimeout(function () {
            el.classList.add('timeline-node--jump-fade');
        }, 1500);
        setTimeout(function () {
            el.classList.remove('timeline-node--jump-target', 'timeline-node--jump-fade');
        }, 3000);
    }

    /* ── Public API ───────────────────────────────────────── */

    window.TimelineCtrl = {
        expandAll: expandAll,
        collapseAll: collapseAll,
        filter: filter,
        jump: jump,
        jumpOnKey: jumpOnKey,
        getActiveFilter: function () { return _activeFilter; }
    };

    /* ── Init: mark "All" filter as active on load ────────── */
    document.addEventListener('DOMContentLoaded', function () {
        var allChip = document.querySelector('.timeline-toolbar__filter[data-filter="all"]');
        if (allChip) allChip.classList.add('active');
    });

})();
