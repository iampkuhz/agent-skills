# ContentPart 数据模型

> 定义 `ContentPart` 类型，使后续 viewer 可按类型安全渲染 text/markdown/json/image/code/html。
> 本文件为纯文档 + 检测函数定义，不修改现有数据解析管线。

---

## 1. 模型定义

`ContentPart` 是消息内容的最小可渲染单元。一条 `ChatMessage` 的 `content` 字段仍然是纯字符串（向后兼容），新增的 `content_parts` 字段是 `list[ContentPart]`，按需填充。

```python
@dataclass
class ContentPart:
    part_type: str      # "text" | "markdown" | "json" | "image" | "code" | "html"
    content: str        # 实际载荷
    language: str = ""  # 仅 code 类型有意义，如 "python" / "yaml"
    filename: str = ""  # 来源文件名（可选）
    metadata: dict = field(default_factory=dict)  # 扩展元数据
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `part_type` | `str` | 是 | 类型标识，取值见下方类型常量表 |
| `content` | `str` | 是 | 内容载荷，具体格式取决于 `part_type` |
| `language` | `str` | 否 | 代码语言标识（仅 `code` 类型使用） |
| `filename` | `str` | 否 | 来源文件名，便于 UI 展示 |
| `metadata` | `dict` | 否 | 自由扩展的键值对 |

---

## 2. 类型常量 (`ContentPartType`)

| 常量 | 值 | 用途 |
|------|-----|------|
| `TEXT` | `"text"` | 空内容或纯文本（不渲染 markdown） |
| `MARKDOWN` | `"markdown"` | 默认类型，用户可见的普通消息文本 |
| `JSON` | `"json"` | 结构化 JSON 数据（工具返回的结构体） |
| `IMAGE` | `"image"` | 图片 URL 或 data URI |
| `CODE` | `"code"` | 代码块（带语法高亮） |
| `HTML` | `"html"` | HTML 片段（沙箱渲染） |

---

## 3. 每种类型的 `content` 格式与示例

### 3.1 text

空或无格式的纯文本。通常作为兜底类型。

```python
ContentPart(part_type="text", content="")
ContentPart(part_type="text", content="（无内容）")
```

### 3.2 markdown

默认的消息内容类型。渲染时使用 markdown → HTML 管线。

```python
ContentPart(
    part_type="markdown",
    content="# 分析结果\n\n**关键发现**：\n- 问题 A\n- 问题 B",
)
```

### 3.3 json

JSON 对象或数组的原始字符串。渲染时应使用 JSON 查看器（可折叠/高亮）。

```python
ContentPart(
    part_type="json",
    content='{"status": "ok", "files_changed": 12, "errors": []}',
)
```

### 3.4 image

图片 URL（HTTP/S）或 data URI。`metadata` 可携带 alt text、尺寸等。

```python
ContentPart(
    part_type="image",
    content="https://example.com/architecture.png",
    metadata={"alt": "系统架构图"},
)

ContentPart(
    part_type="image",
    content="data:image/png;base64,iVBORw0KGgo...",
)
```

### 3.5 code

代码片段。`language` 用于语法高亮，`filename` 可选。

```python
ContentPart(
    part_type="code",
    content="def hello():\n    print('world')",
    language="python",
    filename="main.py",
)

ContentPart(
    part_type="code",
    content="key: value\nlist:\n  - item1",
    language="yaml",
    filename="config.yaml",
)
```

### 3.6 html

HTML 片段。渲染时应使用沙箱（如 iframe sandbox），防止 XSS。

```python
ContentPart(
    part_type="html",
    content="<table><thead><tr><th>A</th></tr></thead><tbody><tr><td>1</td></tr></tbody></table>",
    metadata={"sandbox": True},
)
```

---

## 4. 检测函数

位于 `content_part.py`，所有函数为纯函数，无副作用。

| 函数签名 | 返回值 | 说明 |
|----------|--------|------|
| `is_image_url(payload: str) -> bool` | `bool` | 检测 HTTP 图片 URL、data URI、markdown 图片语法 |
| `is_json(payload: str) -> bool` | `bool` | 以 `{` 或 `[` 开头且可被 `json.loads` 解析 |
| `is_html(payload: str) -> bool` | `bool` | 以 HTML 标签开头，排除短文本中的行内标签误判 |
| `is_code_block(payload: str, filename_hint: str) -> bool` | `bool` | 检测 fenced code、代码文件扩展名、代码语法模式 |
| `detect_content_type(payload: str, filename_hint: str) -> str` | `str` | 组合检测，返回 `ContentPartType` 值 |

### 检测顺序

`detect_content_type` 按以下优先级匹配（首个命中即返回）：

1. 空/空白 → `text`
2. 图片 URL → `image`
3. 合法 JSON → `json`
4. HTML 标签开头 → `html`
5. 代码块特征 → `code`
6. 兜底 → `markdown`

### 误判防护

- **行内 HTML 排除**：短文本（<200 字符）中仅含单个行内标签（如 `<code>`）不会判定为 html。
- **有序列表保护**：代码检测只看 fenced code（```）和语法模式，不依赖数字前缀，不会把有序列表误判为代码。
- **JSON 严格验证**：不仅检查开头字符，还实际调用 `json.loads` 验证。

---

## 5. 向后兼容

### 5.1 ChatMessage 扩展

`ChatMessage` 新增字段：

```python
content_parts: list[ContentPart] = field(default_factory=list)
```

- **默认空列表**：旧数据不填充 `content_parts`，行为完全不变。
- **content 字段不动**：仍作为主要的内容存储，`content_html` 仍从 `content` 渲染。
- **按需填充**：viewer 可在需要时调用 `ContentPart.from_text(msg.content)` 生成 parts。

### 5.2 桥接方法

```python
# 旧代码继续用 msg.content 渲染 markdown
msg.content_html = _md_filter(msg.content)

# 新代码可按需拆分
if not msg.content_parts:
    msg.content_parts = [ContentPart.from_text(msg.content)]
```

### 5.3 与现有 normalize_llm_content 的关系

现有的 `normalize_llm_content()` 返回 `list[dict]`，其中 `kind` 字段与 `ContentPart.part_type` 对应但不完全相同。两者并存：

| `normalize_llm_content` kind | 对应 `ContentPart.part_type` |
|-------------------------------|------------------------------|
| `plain_text` | `markdown` |
| `file_code` | `code` |
| `file_markdown` | `markdown` |
| `tool_result` | `markdown`（内部再拆分） |
| `unknown` | `text` |

后续可统一，本次不改动。

---

## 6. 渲染协议

Viewer 按 `part_type` 分发渲染：

```
switch part_type:
  text      → 纯文本 <pre> 或直接显示
  markdown  → markdown_it 渲染为 HTML
  json      → JSON 查看器（可折叠、高亮）
  image     → <img> 标签，data URI 直接内联
  code      → <pre><code class="language-{language}">
  html      → 沙箱 iframe / 白名单 sanitizer
```

---

## 文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `tools/session-browser/src/session_browser/domain/content_part.py` | 新增 | 模型 + 检测函数 |
| `tools/session-browser/src/session_browser/domain/models.py` | 修改 | `ChatMessage` 增加 `content_parts` 字段 |
