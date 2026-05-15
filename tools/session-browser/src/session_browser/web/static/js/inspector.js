/**
 * inspector.js — 右侧 Inspector 面板
 *
 * 提供 openInspector(payload) / closeInspector() 以及内容渲染。
 * 与 base.html 中的 closeInspector() 配合，保持 Esc 关闭、backdrop 点击关闭。
 */
(function () {
  'use strict';

  var Inspector = {};

  /* ──────────────────────────────────────────────
     打开 Inspector
     ────────────────────────────────────────────── */
  Inspector.open = function (payload) {
    if (!payload) return;

    var panel = document.querySelector('.inspector');
    if (!panel) return;

    // 填充标题
    var titleEl = document.getElementById('inspector-title');
    if (titleEl) {
      titleEl.textContent = payload.title || 'Details';
    }

    // 填充 Metadata
    if (payload.metadata) {
      var metaContainer = document.getElementById('inspector-metadata');
      if (metaContainer) {
        metaContainer.innerHTML = '';
        for (var key in payload.metadata) {
          var item = document.createElement('div');
          item.className = 'meta-item';
          var label = document.createElement('span');
          label.className = 'meta-label';
          label.textContent = key;
          var value = document.createElement('span');
          value.className = 'meta-value';
          if (payload.metadata[key] && payload.metadata[key].mono) {
            value.classList.add('mono');
          }
          value.textContent = payload.metadata[key] ? payload.metadata[key].value : '—';
          item.appendChild(label);
          item.appendChild(value);
          metaContainer.appendChild(item);
        }
      }
    }

    // 填充 Summary
    if (payload.summary) {
      var summaryEl = document.getElementById('inspector-summary');
      if (summaryEl) {
        if (typeof payload.summary === 'string') {
          var p = document.createElement('p');
          p.className = 'text-sm';
          p.textContent = payload.summary;
          summaryEl.innerHTML = '';
          summaryEl.appendChild(p);
        } else {
          summaryEl.innerHTML = '';
          for (var i = 0; i < payload.summary.length; i++) {
            var p = document.createElement('p');
            p.className = 'text-sm';
            p.textContent = payload.summary[i];
            summaryEl.appendChild(p);
          }
        }
      }
    }

    // 填充 Related
    if (payload.related && payload.related.length > 0) {
      var relatedEl = document.getElementById('inspector-related');
      if (relatedEl) {
        relatedEl.innerHTML = '';
        var list = document.createElement('ul');
        list.className = 'inspector-related-list';
        for (var i = 0; i < payload.related.length; i++) {
          var li = document.createElement('li');
          var a = document.createElement('a');
          a.href = payload.related[i].href || '#';
          a.className = 'link';
          a.textContent = payload.related[i].label;
          if (payload.related[i].target) {
            a.target = payload.related[i].target;
          }
          li.appendChild(a);
          list.appendChild(li);
        }
        relatedEl.appendChild(list);
      }
    }

    // Inject Viewer slot — ONLY from trusted server-rendered Jinja2 output (autoescape=True).
    // Do NOT pass user-supplied or untrusted HTML here.
    if (payload.viewerHtml) {
      var slot = document.getElementById('inspector-viewer-slot');
      if (slot) {
        slot.innerHTML = payload.viewerHtml;
      }
    }

    // 触发打开
    document.body.classList.add('inspector-open');

    // Focus 到关闭按钮
    var closeBtn = panel.querySelector('.inspector-close-btn button');
    if (closeBtn) {
      setTimeout(function () { closeBtn.focus(); }, 50);
    }

    // 触发自定义事件，方便业务方扩展
    panel.dispatchEvent(new CustomEvent('inspector:opened', { detail: payload }));
  };

  /* ──────────────────────────────────────────────
     关闭 Inspector
     ────────────────────────────────────────────── */
  Inspector.close = function () {
    document.body.classList.remove('inspector-open');

    var panel = document.querySelector('.inspector');
    if (panel) {
      panel.dispatchEvent(new CustomEvent('inspector:closed'));
    }
  };

  /* ──────────────────────────────────────────────
     Esc 键关闭
     ────────────────────────────────────────────── */
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && document.body.classList.contains('inspector-open')) {
      e.preventDefault();
      Inspector.close();
    }
  });

  /* ──────────────────────────────────────────────
     便捷全局入口
     ────────────────────────────────────────────── */
  window.openInspector = Inspector.open;
  window.closeInspector = Inspector.close;

  window.Inspector = Inspector;
})();
