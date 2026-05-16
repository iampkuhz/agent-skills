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
     Tab definitions for LLM Call Inspector
     ────────────────────────────────────────────── */
  var DEFAULT_TABS = [
    'Overview',
    'Rendered Context',
    'Request Payload',
    'Rendered Response',
    'Response Payload',
    'Tools',
    'Raw'
  ];

  /* ──────────────────────────────────────────────
     HTML-escape utility for raw content
     ────────────────────────────────────────────── */
  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

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

    // Tab mode: payload.tabs or tabs present
    var tabs = payload.tabs || DEFAULT_TABS;
    if (tabs && tabs.length > 0) {
      Inspector._renderTabs(tabs);
      // Hide legacy sections when tabs are active
      var legacySections = panel.querySelectorAll('.inspector-legacy-section');
      for (var i = 0; i < legacySections.length; i++) {
        legacySections[i].style.display = 'none';
      }
    } else {
      // Non-tab mode: show legacy sections
      var legacySections2 = panel.querySelectorAll('.inspector-legacy-section');
      for (var i2 = 0; i2 < legacySections2.length; i2++) {
        legacySections2[i2].style.display = '';
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
     Render multipart content parts (I-08)
     ────────────────────────────────────────────── */
  Inspector._renderMultipartParts = function (parts, totalLength) {
    if (!parts || parts.length === 0) {
      return '<div class="multipart-fallback">' +
        '<p class="multipart-fallback__note">No multipart structure available.</p>' +
      '</div>';
    }

    var html = '<div class="inspector-tab-panel-content">';
    if (totalLength > 0) {
      html += '<div class="rendered-context-header">' +
        '<span class="rendered-context-header__length">' + parts.length + ' part(s) · ' + totalLength + ' chars</span>' +
        '<button class="viewer__fullscreen-btn" onclick="openViewerFullscreen(this)" title="View in fullscreen">&#x26f6;</button>' +
      '</div>';
    } else {
      html += '<div class="rendered-context-header">' +
        '<span class="rendered-context-header__length">' + parts.length + ' part(s)</span>' +
        '<button class="viewer__fullscreen-btn" onclick="openViewerFullscreen(this)" title="View in fullscreen">&#x26f6;</button>' +
      '</div>';
    }

    html += '<div class="viewer viewer--parts">';

    for (var i = 0; i < parts.length; i++) {
      var part = parts[i];
      var partType = part.context_type || '';
      var partKind = part.kind || part.part_type || 'unknown';
      var partTitle = part.title || '';
      var partLang = part.language || '';
      var partContent = part.content || '';
      var partBytes = part.content_bytes || 0;
      var partTokens = part.token_hint || 0;
      var partRaw = part.raw || partContent;

      var escapedContent = escapeHtml(partContent);
      var escapedRaw = escapeHtml(partRaw);

      html += '<div class="viewer__part viewer__part--' + escapeHtml(partKind) + '">';

      // Header with badges.
      html += '<div class="viewer__part-header">';

      // Context type badge.
      if (partType) {
        var typeClass = 'viewer__context-type--unknown';
        if (partType === 'system_prompt') typeClass = 'viewer__context-type--system';
        else if (partType === 'user_message') typeClass = 'viewer__context-type--user';
        else if (partType === 'assistant_message') typeClass = 'viewer__context-type--assistant';
        else if (partType === 'tool_result') typeClass = 'viewer__context-type--tool';
        else if (partType === 'attachment') typeClass = 'viewer__context-type--attachment';
        html += '<span class="viewer__context-type ' + typeClass + '" title="' + escapeHtml(partType) + '">' + escapeHtml(partType.replace(/_/g, ' ')) + '</span>';
      }

      // Content format badge.
      html += '<span class="viewer__part-type viewer__part-type--' + (partKind === 'code' ? 'code' : partKind === 'json' ? 'tool' : 'md') + '" title="' + escapeHtml(partKind) + '"></span>';

      // Title.
      if (partTitle) {
        html += '<span class="viewer__part-title">' + escapeHtml(partTitle) + '</span>';
      }

      // Language tag.
      if (partLang) {
        html += '<code class="viewer__lang-tag">' + escapeHtml(partLang) + '</code>';
      }

      // Size hints.
      html += '<span class="viewer__part-meta">';
      if (partBytes > 0) {
        html += '<span class="viewer__part-size" title="' + partBytes + ' bytes">' + Inspector._formatBytes(partBytes) + '</span>';
      }
      if (partTokens > 0) {
        html += '<span class="viewer__part-tokens" title="~' + partTokens + ' tokens">' + partTokens + 't</span>';
      }
      html += '</span>';

      // Raw toggle (if content is long enough).
      if (partBytes > 200) {
        html += '<button class="viewer__raw-toggle" onclick="Inspector._togglePartRaw(this)" title="View raw content">Raw</button>';
      }

      html += '</div>'; // viewer__part-header

      // Content area.
      html += '<div class="viewer__part-content">';

      // Rendered view (markdown-as-pre for simplicity).
      html += '<div class="viewer__part-rendered">';
      if (partKind === 'code') {
        html += '<pre class="viewer__code-block"><code class="language-' + escapeHtml(partLang) + '">' + escapedContent + '</code></pre>';
      } else if (partKind === 'json') {
        html += '<pre class="viewer__json-block">' + escapedContent + '</pre>';
      } else {
        // Render as pre-formatted text (safe).
        html += '<pre class="viewer__part-markdown">' + escapedContent + '</pre>';
      }
      html += '</div>';

      // Raw view (hidden by default, shown for long content).
      if (partBytes > 200) {
        html += '<div class="viewer__part-raw" style="display:none">';
        html += '<div class="viewer__part-raw-header">';
        html += '<span class="viewer__part-raw-label">Raw content</span>';
        html += '<button class="viewer__raw-toggle viewer__raw-toggle--small" onclick="Inspector._togglePartRaw(this)" title="Back to rendered view">Rendered</button>';
        html += '</div>';
        html += '<pre class="viewer__part-raw-pre">' + escapedRaw + '</pre>';
        html += '</div>';
      }

      html += '</div>'; // viewer__part-content
      html += '</div>'; // viewer__part
    }

    html += '</div>'; // viewer
    html += '</div>'; // inspector-tab-panel-content

    return html;
  };

  /* ──────────────────────────────────────────────
     Toggle raw/rendered view for a single part
     ────────────────────────────────────────────── */
  Inspector._togglePartRaw = function (btn) {
    var partEl = btn.closest('.viewer__part');
    if (!partEl) return;
    var rendered = partEl.querySelector('.viewer__part-rendered');
    var raw = partEl.querySelector('.viewer__part-raw');
    if (!rendered || !raw) return;

    var isShowingRaw = raw.style.display !== 'none';
    if (isShowingRaw) {
      raw.style.display = 'none';
      rendered.style.display = '';
    } else {
      raw.style.display = '';
      rendered.style.display = 'none';
    }
  };

  /* ──────────────────────────────────────────────
     Format bytes to human-readable string
     ────────────────────────────────────────────── */
  Inspector._formatBytes = function (bytes) {
    if (bytes < 1024) return bytes + 'B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + 'KB';
    return (bytes / (1024 * 1024)).toFixed(1) + 'MB';
  };

  /* ──────────────────────────────────────────────
     Wrap viewer HTML with a header containing fullscreen button
     ────────────────────────────────────────────── */
  Inspector._wrapViewerWithTitle = function (title, viewerHtml) {
    return '<div class="inspector-tab-panel-content">' +
      '<div class="rendered-context-header">' +
        '<span class="rendered-context-header__title">' + escapeHtml(title) + '</span>' +
        '<button class="viewer__fullscreen-btn" onclick="openViewerFullscreen(this)" title="View in fullscreen">&#x26f6;</button>' +
      '</div>' +
      viewerHtml +
    '</div>';
  };

  /* ──────────────────────────────────────────────
     Also expose togglePartRaw globally for server-rendered parts
     ────────────────────────────────────────────── */
  window.togglePartRaw = function (btn) {
    var partEl = btn.closest('.viewer__part');
    if (!partEl) return;
    var rendered = partEl.querySelector('.viewer__part-rendered');
    var raw = partEl.querySelector('.viewer__part-raw');
    if (!rendered || !raw) return;

    var isShowingRaw = raw.style.display !== 'none';
    if (isShowingRaw) {
      raw.style.display = 'none';
      rendered.style.display = '';
    } else {
      raw.style.display = '';
      rendered.style.display = 'none';
    }
  };

  /* ──────────────────────────────────────────────
     Render tab shell
     ────────────────────────────────────────────── */
  Inspector._renderTabs = function (tabLabels) {
    var container = document.getElementById('inspector-tabs');
    var tablist = document.getElementById('inspector-tablist');
    if (!container || !tablist) return;

    // Show container
    container.style.display = '';

    // Build tab buttons
    tablist.innerHTML = '';
    for (var i = 0; i < tabLabels.length; i++) {
      var btn = document.createElement('button');
      btn.className = 'tab' + (i === 0 ? ' active' : '');
      btn.setAttribute('role', 'tab');
      btn.setAttribute('aria-selected', i === 0 ? 'true' : 'false');
      btn.setAttribute('aria-controls', 'inspector-tabpanel-' + i);
      btn.setAttribute('data-inspector-tab', i);
      btn.textContent = tabLabels[i];
      tablist.appendChild(btn);
    }

    // Build tab panels
    var panelsContainer = container.querySelector('.inspector-tabpanels');
    if (!panelsContainer) {
      panelsContainer = document.createElement('div');
      panelsContainer.className = 'inspector-tabpanels';
      container.appendChild(panelsContainer);
    }
    panelsContainer.innerHTML = '';

    for (var j = 0; j < tabLabels.length; j++) {
      var panel = document.createElement('div');
      panel.className = 'tab-content' + (j === 0 ? ' active' : '');
      panel.setAttribute('role', 'tabpanel');
      panel.setAttribute('id', 'inspector-tabpanel-' + j);
      panel.setAttribute('aria-labelledby', 'inspector-tab-' + j);
      panel.style.display = j === 0 ? '' : 'none';

      // Content placeholder per tab
      if (j === 0) {
        // Overview tab placeholder
        panel.innerHTML = '<div class="inspector-tab-panel-content"><p class="text-muted text-sm">Overview content will be populated here.</p></div>';
      } else if (j === 1) {
        // Rendered Context tab — shows request_full / prompt_preview
        var rcRaw = payload.rendered_context_raw || '';
        var rcLen = payload.rendered_context_length || 0;

        // Check for multipart content parts (I-08).
        var contentParts = payload.content_parts || [];
        if (contentParts.length > 0) {
          panel.innerHTML = Inspector._renderMultipartParts(contentParts, rcLen);
        } else if (rcRaw && rcRaw.length > 0) {
          var escapedRc = escapeHtml(rcRaw);
          var rcViewerHtml =
            '<div class="viewer viewer--raw">' +
              '<div class="viewer__raw">' +
                '<pre class="viewer__raw-pre">' + escapedRc + '</pre>' +
              '</div>' +
            '</div>';
          panel.innerHTML = Inspector._wrapViewerWithTitle('Rendered Context', rcViewerHtml);
        } else {
          var rcMissingReason = payload.rendered_context_missing_reason || 'No rendered context available for this call.';
          panel.innerHTML =
            '<div class="inspector-tab-panel-content">' +
              '<div class="payload-unavailable">' +
                '<h3 class="payload-unavailable__title">Rendered Context unavailable</h3>' +
                '<p class="payload-unavailable__reason"><strong>Reason:</strong> ' + escapeHtml(rcMissingReason) + '</p>' +
              '</div>' +
            '</div>';
        }
      } else if (j === 2) {
        // Request Payload tab
        var contentParts = payload.content_parts || [];
        var reqPayload = payload.request_payload_raw;

        if (contentParts.length > 0) {
          // Multipart parts available — show them with raw payload fallback.
          var partsHtml = Inspector._renderMultipartParts(contentParts, 0);
          if (reqPayload) {
            var escapedReq = escapeHtml(reqPayload);
            partsHtml +=
              '<div class="multipart-fallback">' +
                '<p class="multipart-fallback__note">Raw request payload also available below.</p>' +
                '<div class="multipart-fallback__raw">' +
                  '<pre>' + escapedReq + '</pre>' +
                '</div>' +
              '</div>';
          }
          panel.innerHTML = partsHtml;
        } else if (reqPayload) {
          var escapedReq = escapeHtml(reqPayload);
          var reqViewerHtml = '<div class="viewer viewer--raw">' +
            '<div class="viewer__raw">' +
              '<pre class="viewer__raw-pre">' + escapedReq + '</pre>' +
            '</div>' +
          '</div>';
          panel.innerHTML = Inspector._wrapViewerWithTitle('Request Payload', reqViewerHtml);
        } else {
          var missingReason = payload.request_payload_missing_reason || 'Current session data source does not persist raw request payload.';
          var inputTokens = payload.request_payload_input_tokens || 0;
          var outputTokens = payload.request_payload_output_tokens || 0;
          var cacheRead = payload.request_payload_cache_read_tokens || 0;
          var cacheWrite = payload.request_payload_cache_write_tokens || 0;
          var renderedLen = payload.request_payload_rendered_context_length || 0;
          var obsInput = inputTokens + cacheRead + cacheWrite;

          panel.innerHTML =
            '<div class="inspector-tab-panel-content">' +
              '<div class="payload-unavailable">' +
                '<h3 class="payload-unavailable__title">Request Payload unavailable</h3>' +
                '<p class="payload-unavailable__reason"><strong>Reason:</strong> ' + escapeHtml(missingReason) + '</p>' +
                '<div class="payload-unavailable__observed">' +
                  '<h4 class="payload-unavailable__observed-title">Observed call data (from rendered/logged context)</h4>' +
                  '<dl class="payload-unavailable__meta">' +
                    '<dt>Observed input tokens</dt><dd>' + obsInput + '</dd>' +
                    '<dt>Observed output tokens</dt><dd>' + outputTokens + '</dd>' +
                    (cacheRead > 0 ? '<dt>Cache read tokens</dt><dd>' + cacheRead + '</dd>' : '') +
                    (cacheWrite > 0 ? '<dt>Cache write tokens</dt><dd>' + cacheWrite + '</dd>' : '') +
                    '<dt>Rendered context length</dt><dd>' + renderedLen + ' chars</dd>' +
                  '</dl>' +
                  '<p class="payload-unavailable__note">Note: <code>request_full</code> in this session contains the rendered/logged context, NOT the raw HTTP request payload. The raw payload is not available because the data source does not persist it.</p>' +
                '</div>' +
              '</div>' +
            '</div>';
        }
      } else if (j === 3) {
        // Rendered Response tab — shows assistant_content (rendered text)
        var assistantContent = payload.assistant_content || '';
        var assistantContentLen = payload.assistant_content_length || 0;
        if (assistantContent && assistantContent.length > 0) {
          var escapedAsst = escapeHtml(assistantContent);
          var asstViewerHtml =
            '<div class="viewer viewer--raw">' +
              '<div class="viewer__raw">' +
                '<pre class="viewer__raw-pre">' + escapedAsst + '</pre>' +
              '</div>' +
            '</div>';
          panel.innerHTML = Inspector._wrapViewerWithTitle('Rendered Response', asstViewerHtml);
        } else {
          var noResponseReason = 'No response content for this call.';
          var noResponseHint = 'This call may have only used tool calls (no assistant text response).';
          panel.innerHTML =
            '<div class="inspector-tab-panel-content">' +
              '<div class="payload-unavailable">' +
                '<h3 class="payload-unavailable__title">No rendered response</h3>' +
                '<p class="payload-unavailable__reason"><strong>Reason:</strong> ' + escapeHtml(noResponseReason) + '</p>' +
                '<p class="payload-unavailable__note">' + escapeHtml(noResponseHint) + '</p>' +
              '</div>' +
            '</div>';
        }
      } else if (j === 4) {
        // Response Payload tab — raw response / finish reason / usage / tool calls
        var respPayload = payload.response_payload_raw;
        var missingReason = payload.response_payload_missing_reason || '';
        var finishReason = payload.finish_reason || '';
        var toolCallsRaw = payload.tool_calls_raw || '';
        var assistantContent = payload.assistant_content || '';
        var assistantContentLen = payload.assistant_content_length || 0;

        if (respPayload && respPayload.length > 0) {
          // Raw response is available — show it
          var escapedResp = escapeHtml(respPayload);
          var respViewerHtml =
            '<div class="viewer viewer--raw">' +
              '<div class="viewer__raw">' +
                '<pre class="viewer__raw-pre">' + escapedResp + '</pre>' +
              '</div>' +
            '</div>';
          panel.innerHTML = Inspector._wrapViewerWithTitle('Response Payload', respViewerHtml);
        } else {
          // No raw response — show unavailable with observed call data
          var finishHtml = '';
          if (finishReason) {
            finishHtml = '<dt>Finish reason</dt><dd>' + escapeHtml(finishReason) + '</dd>';
          }

          panel.innerHTML =
            '<div class="inspector-tab-panel-content">' +
              '<div class="payload-unavailable">' +
                '<h3 class="payload-unavailable__title">Response Payload unavailable</h3>' +
                '<p class="payload-unavailable__reason"><strong>Reason:</strong> ' + escapeHtml(missingReason || 'current session data source does not persist raw HTTP response') + '</p>' +
                '<div class="payload-unavailable__observed">' +
                  '<h4 class="payload-unavailable__observed-title">Observed call data (from rendered/logged context)</h4>' +
                  '<dl class="payload-unavailable__meta">' +
                    finishHtml +
                    (assistantContentLen > 0 ? '<dt>Assistant content length</dt><dd>' + assistantContentLen + ' chars</dd>' : '') +
                    (toolCallsRaw ? '<dt>Tool calls (raw)</dt><dd><details><summary>View raw JSON</summary><div class="viewer viewer--raw" style="margin-top:8px"><div class="viewer__raw"><pre class="viewer__raw-pre">' + escapeHtml(toolCallsRaw) + '</pre></div></div></details></dd>' : '<dt>Tool calls</dt><dd>No tool calls for this call</dd>') +
                  '</dl>' +
                  '<p class="payload-unavailable__note">Note: <code>response_full</code> in this session contains the rendered response text, NOT the raw HTTP response JSON. The raw payload is not available because the data source does not persist it.</p>' +
                '</div>' +
              '</div>' +
            '</div>';
        }
      } else if (j === 5) {
        // Tools tab — list tool calls for this LLM call
        var toolCalls = payload.tool_calls || [];
        if (toolCalls && toolCalls.length > 0) {
          var toolHtml = '<div class="inspector-tab-panel-content"><div class="tools-tab-header"><span class="tools-tab-header__count">' + toolCalls.length + ' tool call(s)</span></div><div class="tools-tab-list">';
          for (var ti = 0; ti < toolCalls.length; ti++) {
            var tc = toolCalls[ti];
            var statusClass = tc.status === 'failed' ? 'tool-call-item--failed' : '';
            var statusText = tc.status === 'failed' ? 'Failed' : 'OK';
            var durationStr = tc.duration_ms ? (tc.duration_ms >= 1000 ? (tc.duration_ms / 1000).toFixed(1) + 's' : tc.duration_ms + 'ms') : '';

            // Parameters summary: flatten to key=value pairs
            var paramSummary = '';
            if (tc.parameters && typeof tc.parameters === 'object') {
              var keys = Object.keys(tc.parameters);
              var parts = [];
              for (var pk = 0; pk < Math.min(keys.length, 5); pk++) {
                var v = tc.parameters[keys[pk]];
                if (typeof v === 'string') v = v.length > 60 ? v.slice(0, 60) + '...' : v;
                else if (typeof v !== 'string' && typeof v !== 'number' && typeof v !== 'boolean') v = JSON.stringify(v).slice(0, 60);
                parts.push(keys[pk] + '=' + v);
              }
              paramSummary = parts.join(', ');
              if (keys.length > 5) paramSummary += ', ...';
            }

            // Result preview with truncation
            var resultHtml = '';
            if (tc.result_preview && tc.result_preview.length > 0) {
              var resultEscaped = escapeHtml(tc.result_preview);
              var isLong = tc.result_length > 300;
              resultHtml = '<div class="tool-call-item__result">';
              resultHtml += '<span class="tool-call-item__result-label">Result: </span>';
              resultHtml += '<span class="tool-call-item__result-text">' + resultEscaped + (isLong ? '<span class="tool-call-item__truncated-hint">…(' + (tc.result_length - 200) + ' more chars)</span>' : '') + '</span>';
              resultHtml += '</div>';
            }

            toolHtml +=
              '<div class="tool-call-item ' + statusClass + '">' +
                '<div class="tool-call-item__header">' +
                  '<span class="tool-call-item__name">' + escapeHtml(tc.name) + '</span>' +
                  '<span class="tool-call-item__status ' + statusClass + '">' + statusText + '</span>' +
                  (durationStr ? '<span class="tool-call-item__duration">' + durationStr + '</span>' : '') +
                '</div>' +
                (paramSummary ? '<div class="tool-call-item__params mono text-xs">' + escapeHtml(paramSummary) + '</div>' : '') +
                resultHtml +
              '</div>';
          }
          toolHtml += '</div></div>';
          panel.innerHTML = toolHtml;
        } else {
          panel.innerHTML =
            '<div class="inspector-tab-panel-content">' +
              '<div class="payload-unavailable">' +
                '<h3 class="payload-unavailable__title">No tool calls</h3>' +
                '<p class="payload-unavailable__reason">This LLM call did not invoke any tools.</p>' +
              '</div>' +
            '</div>';
        }
      } else if (j === 6) {
        // Raw tab — normalized debug JSON
        var debugJson = payload.debug_json || {};
        // Enrich with additional available fields
        if (payload.model && !debugJson.model) debugJson.model = payload.model;
        if (payload.scope && !debugJson.scope) debugJson.scope = payload.scope;

        var debugStr = JSON.stringify(debugJson, null, 2);
        var escapedDebug = escapeHtml(debugStr);
        var rawContent =
          '<div class="inspector-tab-panel-content">' +
            '<div class="rendered-context-header">' +
              '<span class="rendered-context-header__title">Raw (debug JSON)</span>' +
              '<button class="viewer__fullscreen-btn" onclick="openViewerFullscreen(this)" title="View in fullscreen">&#x26f6;</button>' +
            '</div>' +
            '<div class="viewer viewer--raw raw-debug-viewer">' +
              '<div class="viewer__raw">' +
                '<pre class="viewer__raw-pre raw-debug-pre">' + escapedDebug + '</pre>' +
              '</div>' +
            '</div>' +
          '</div>';
        panel.innerHTML = rawContent;
      }

      panelsContainer.appendChild(panel);
    }

    // Bind click events on tab buttons
    var tabs = tablist.querySelectorAll('.tab');
    for (var k = 0; k < tabs.length; k++) {
      (function (tabEl) {
        tabEl.addEventListener('click', function () {
          Inspector._switchTab(parseInt(this.getAttribute('data-inspector-tab')));
        });
      })(tabs[k]);
    }
  };

  /* ──────────────────────────────────────────────
     Switch active tab
     ────────────────────────────────────────────── */
  Inspector._switchTab = function (index) {
    var tablist = document.getElementById('inspector-tablist');
    if (!tablist) return;

    var buttons = tablist.querySelectorAll('[role="tab"]');
    for (var i = 0; i < buttons.length; i++) {
      var isActive = parseInt(buttons[i].getAttribute('data-inspector-tab')) === index;
      buttons[i].classList.toggle('active', isActive);
      buttons[i].setAttribute('aria-selected', isActive ? 'true' : 'false');
    }

    var panelsContainer = document.querySelector('.inspector-tabpanels');
    if (!panelsContainer) return;
    var panels = panelsContainer.querySelectorAll('[role="tabpanel"]');
    for (var j = 0; j < panels.length; j++) {
      var panelIdx = parseInt(panels[j].getAttribute('id').replace('inspector-tabpanel-', ''));
      var panelActive = panelIdx === index;
      panels[j].classList.toggle('active', panelActive);
      panels[j].style.display = panelActive ? '' : 'none';
    }
  };

  /* ──────────────────────────────────────────────
     Fullscreen viewer overlay (I-09)
     ────────────────────────────────────────────── */
  var _fullscreenOverlay = null;

  window.openViewerFullscreen = function (btn) {
    if (_fullscreenOverlay) return;

    var viewer = btn.closest('.viewer');
    if (!viewer) return;

    var header = viewer.querySelector('.viewer__header');
    var title = header ? (header.querySelector('.viewer__title') || {}).textContent || 'Fullscreen Viewer' : 'Fullscreen Viewer';

    _fullscreenOverlay = document.createElement('div');
    _fullscreenOverlay.className = 'viewer-fullscreen-overlay';
    _fullscreenOverlay.setAttribute('role', 'dialog');
    _fullscreenOverlay.innerHTML =
      '<div class="viewer-fullscreen__header">' +
        '<span class="viewer-fullscreen__title">' + escapeHtml(title) + '</span>' +
        '<button class="viewer-fullscreen__close" onclick="closeViewerFullscreen()" title="Close (Esc)">&#x2715;</button>' +
      '</div>' +
      '<div class="viewer-fullscreen__body">' + viewer.innerHTML + '</div>';

    document.body.appendChild(_fullscreenOverlay);
    _fullscreenOverlay.querySelector('.viewer-fullscreen__close').focus();
  };

  window.closeViewerFullscreen = function () {
    if (_fullscreenOverlay) {
      document.body.removeChild(_fullscreenOverlay);
      _fullscreenOverlay = null;
    }
  };

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && _fullscreenOverlay) {
      e.preventDefault();
      e.stopPropagation();
      closeViewerFullscreen();
    }
  });

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
