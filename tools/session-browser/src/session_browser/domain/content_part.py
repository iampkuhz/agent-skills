"""ContentPart — typed content model for chat message rendering.

Defines a ContentPart dataclass and detection helpers so downstream viewers
can safely render text / markdown / json / image / code / html payloads
without guessing the format.

Backward compatibility:
- Existing ChatMessage.content (plain str) can be wrapped via
  ContentPart.from_text() to produce a single 'markdown' part.
- All detection functions are pure and side-effect free.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from typing import Optional

# ─── ContentPart type constants ──────────────────────────────────────────


class ContentPartType:
    """Allowed content part types."""

    TEXT = "text"
    MARKDOWN = "markdown"
    JSON = "json"
    IMAGE = "image"
    CODE = "code"
    HTML = "html"


# ─── Detection helpers ───────────────────────────────────────────────────

# Image URL patterns: common image extensions or data URIs
_IMAGE_URL_RE = re.compile(
    r'(?i)https?://\S+\.(?:png|jpe?g|gif|webp|svg|bmp|ico|tiff?)(?:\?\S*)?$'
    r'|'
    r'^data:image/'
    r'|'
    r'!\[.*?\]\(https?://\S+\)'  # markdown image syntax
)

# JSON detection: starts with { or [ and parses successfully
_JSON_START_RE = re.compile(r'^\s*[\{\[]')

# HTML detection: starts with a tag (possibly after whitespace/BOM)
_HTML_TAG_RE = re.compile(r'^\s*<[a-zA-Z!/][\s\S]*>', re.DOTALL)

# Code block indicators: fenced code block or known code patterns at start
_FENCED_CODE_RE = re.compile(r'^```', re.MULTILINE)

# Python / JS / etc. patterns that strongly suggest code (not prose)
_CODE_PATTERNS = [
    re.compile(r'^(def |class |async def |import |from .+ import )', re.MULTILINE),
    re.compile(r'^(const |let |var |function |export |import \{)', re.MULTILINE),
    re.compile(r'^(func |package |import \()', re.MULTILINE),  # Go
    re.compile(r'^(pub (fn|struct|enum|mod|use|impl|trait))', re.MULTILINE),  # Rust
]

# Common file extensions that indicate code
_CODE_EXTENSIONS = {
    '.py', '.ts', '.tsx', '.js', '.jsx', '.rb', '.rs', '.go', '.java',
    '.cpp', '.c', '.cs', '.swift', '.kt', '.scala', '.php', '.sh', '.bash',
    '.zsh', '.R', '.pl', '.lua', '.dart', '.ex', '.exs', '.erl', '.hs',
    '.ml', '.fs', '.clj', '.lisp', '.rkt', '.sql', '.proto', '.graphql',
    '.tf', '.hcl', '.nix', '.d', '.nim', '.zig', '.v', '.vim', '.el',
    '.cmake', '.gradle', '.groovy', '.bat', '.cmd', '.ps1', '.awk', '.sed',
}

# Extensions that are NOT code (documents, data, config-as-doc)
_NOT_CODE_EXTENSIONS = {
    '.md', '.markdown', '.mdx', '.txt', '.rst', '.org', '.adoc',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
}


def is_image_url(payload: str) -> bool:
    """Return True if payload looks like an image URL or markdown image."""
    if not payload:
        return False
    return bool(_IMAGE_URL_RE.search(payload))


def is_json(payload: str) -> bool:
    """Return True if payload is valid JSON (object or array)."""
    if not payload:
        return False
    if not _JSON_START_RE.match(payload):
        return False
    try:
        json.loads(payload)
        return True
    except (json.JSONDecodeError, ValueError):
        return False


def is_html(payload: str) -> bool:
    """Return True if payload starts with an HTML tag.

    Requires the first non-whitespace characters to be '<tag' or '</tag'
    or '<!--comment' to avoid false positives on markdown angle brackets.
    """
    if not payload:
        return False
    m = _HTML_TAG_RE.match(payload)
    if not m:
        return False
    # Reject if it looks like a single short inline tag in prose
    # (e.g. "Use <code> for inline code")
    first_tag = m.group(0).strip()
    if len(payload.strip()) < 200 and first_tag.count('<') == 1 and first_tag.count('>') == 1:
        # Short text with one inline tag — likely prose, not a full HTML doc
        return False
    return True


def is_code_block(payload: str, filename_hint: str = "") -> bool:
    """Return True if payload looks like a code block.

    Checks for:
    1. Fenced code blocks (```)
    2. File extension hint in _CODE_EXTENSIONS (not in _NOT_CODE_EXTENSIONS)
    3. Strong code patterns at the start of content
    """
    if not payload:
        return False

    # Fenced code
    if _FENCED_CODE_RE.match(payload):
        return True

    # File extension hint
    if filename_hint:
        lower = filename_hint.lower()
        for ext in _CODE_EXTENSIONS:
            if lower.endswith(ext):
                return True
        for ext in _NOT_CODE_EXTENSIONS:
            if lower.endswith(ext):
                return False

    # Code pattern heuristics (at least one pattern must match near the start)
    first_lines = "\n".join(payload.splitlines()[:10])
    for pattern in _CODE_PATTERNS:
        if pattern.search(first_lines):
            return True

    return False


def detect_content_type(payload: str, filename_hint: str = "") -> str:
    """Detect the ContentPartType for a payload string.

    Order of checks (first match wins):
    1. image URL → "image"
    2. JSON → "json"
    3. HTML → "html"
    4. code block → "code"
    5. non-empty text → "markdown"
    6. empty → "text"

    This ordering ensures that structured formats are detected before
    falling back to the markdown default.
    """
    if not payload or not payload.strip():
        return ContentPartType.TEXT

    if is_image_url(payload):
        return ContentPartType.IMAGE

    if is_json(payload):
        return ContentPartType.JSON

    if is_html(payload):
        return ContentPartType.HTML

    if is_code_block(payload, filename_hint):
        return ContentPartType.CODE

    return ContentPartType.MARKDOWN


# ─── ContentPart model ───────────────────────────────────────────────────


@dataclass
class ContentPart:
    """A single typed piece of message content.

    Fields
    ------
    part_type : str
        One of ContentPartType values: text, markdown, json, image, code, html.
    content : str
        The actual payload. For 'image' this is the URL or data URI.
        For 'json' this is the raw JSON string.
    language : str, optional
        Language hint for 'code' parts (e.g. "python", "yaml"). Empty otherwise.
    filename : str, optional
        Source filename if the part originated from a file read.
    metadata : dict, optional
        Free-form key/value for additional context (e.g. image dimensions,
        JSON schema reference, HTML sandbox flag).

    Examples
    --------
    Text (fallback for empty or plain prose)::

        ContentPart(part_type="text", content="")

    Markdown (default for user-facing prose)::

        ContentPart(
            part_type="markdown",
            content="# Hello\\n\\nThis is **bold** text.",
        )

    JSON (parsed tool result)::

        ContentPart(
            part_type="json",
            content='{"key": "value", "count": 42}',
        )

    Image (URL or data URI)::

        ContentPart(
            part_type="image",
            content="https://example.com/diagram.png",
            metadata={"alt": "System architecture", "width": 800},
        )

    Code (with language hint)::

        ContentPart(
            part_type="code",
            content="def hello():\\n    print('world')",
            language="python",
            filename="main.py",
        )

    HTML (sandboxed rendering)::

        ContentPart(
            part_type="html",
            content="<table><tr><td>Cell</td></tr></table>",
            metadata={"sandbox": True},
        )
    """

    part_type: str
    content: str
    language: str = ""
    filename: str = ""
    metadata: dict = field(default_factory=dict)

    @staticmethod
    def from_text(text: str) -> ContentPart:
        """Wrap a plain string into a ContentPart with auto-detected type.

        This is the backward-compatibility bridge: existing code that
        stores ChatMessage.content as str can call this to get a typed
        ContentPart without changing the rendering result.
        """
        if not text or not text.strip():
            return ContentPart(part_type=ContentPartType.TEXT, content=text or "")
        return ContentPart(part_type=ContentPartType.MARKDOWN, content=text)

    @staticmethod
    def from_dict(data: dict) -> ContentPart:
        """Create a ContentPart from a dict (e.g. deserialized JSON)."""
        return ContentPart(
            part_type=data.get("part_type", ContentPartType.TEXT),
            content=data.get("content", ""),
            language=data.get("language", ""),
            filename=data.get("filename", ""),
            metadata=data.get("metadata", {}),
        )

    def to_dict(self) -> dict:
        """Serialize to a dict."""
        return {
            "part_type": self.part_type,
            "content": self.content,
            "language": self.language,
            "filename": self.filename,
            "metadata": self.metadata,
        }

    @property
    def is_text(self) -> bool:
        return self.part_type == ContentPartType.TEXT

    @property
    def is_markdown(self) -> bool:
        return self.part_type == ContentPartType.MARKDOWN

    @property
    def is_json(self) -> bool:
        return self.part_type == ContentPartType.JSON

    @property
    def is_image(self) -> bool:
        return self.part_type == ContentPartType.IMAGE

    @property
    def is_code(self) -> bool:
        return self.part_type == ContentPartType.CODE

    @property
    def is_html(self) -> bool:
        return self.part_type == ContentPartType.HTML
