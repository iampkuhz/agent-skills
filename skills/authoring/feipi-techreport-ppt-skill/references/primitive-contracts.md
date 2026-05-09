# 渐进式质量基线（Quality Baseline Layers）

## 定位

本 skill 的质量验证遵循**自底向上**的原则：先确保原子元素稳定，再逐步组合为复杂页面。
所有质量门禁分为以下层级，每层依赖下层通过。

```
Token Gate → Text Box Gate → Primitive Gate → Composition Gate → Page Gate
```

## 层级定义

### 1. Token Gate

检查 design token 的一致性和有效性。

| 检查项 | 规则 | 严重性 |
|--------|------|--------|
| 颜色 token | 所有颜色值必须来自 `theme.COLORS` 注册表 | hard_fail |
| 字号 token | 所有字号必须来自 `theme.FONT_SIZES` 注册表 | hard_fail |
| 字体 token | 所有字体必须来自 `theme.FONT_FACES` 注册表 | warning |
| 非 token 颜色 | 散落未登记 hex 色值 | warning |
| 异常字号 | 字号 < 8pt 或 > 40pt（超出合理范围） | warning |

**实现位置**：`helpers/pptx/theme.js`（token 注册表）、`helpers/pptx/postcheck.js`（`scanNonTokenColors`）

### 2. Text Box Gate

检查所有文本框的几何属性和内容承载能力。

| 检查项 | 规则 | 严重性 |
|--------|------|--------|
| 必需坐标 | 每个文本框必须有 `layout.x/y/w/h` | hard_fail |
| 默认 fallback | 不能静默使用 `(0,0,2,0.5)` | hard_fail |
| 宽高不足 | 宽度 < 1 inch 或高度 < 0.2 inch | warning |
| 文本溢出 | 估算渲染高度 > 可用高度 1.2 倍 | warning |
| 元素重叠 | 同一 region 内两个文本框大面积重叠 | hard_fail |

**实现位置**：`helpers/static-qa.js`（几何检查）、`helpers/pptx/postcheck.js`（`checkFallbackClustering`）

### 3. Primitive Gate

检查每个原子组件的内部结构和约束。

每种 primitive 都有独立 contract（见下表），覆盖输入字段、内部子元素、padding、group 要求、允许 token。

| Primitive | 子元素 | 是否 group | 内部 padding | 允许颜色 token |
|-----------|--------|-----------|-------------|---------------|
| Text Box | 文本 ×1 | 否 | margin | navy, gray, blue, red |
| KPI Card | 背景 ×1 + label ×1 + value ×1 | 是 | 0.08 inch | paleBlue, paleOrange, paleGreen |
| Note / Insight | 背景 ×1 + 文本 ×1 | 是 | 0.1 inch | white, paleBlue, paleRed |
| Matrix / Table | 表格框架 | 否 | 0 margin | navy, pale, border |
| Component Node | 形状 ×1 + 文本 ×1 | 是 | 0.05-0.08 inch | paleBlue, paleOrange |
| Badge / Label | 形状 ×1 + 文本 ×1 | 是 | 0.05 inch | paleBlue, paleGreen, paleOrange, paleRed |
| Footer Note | 文本 ×1 | 否 | 0 margin | gray |
| Connector | 线条 ×1 | 否 | N/A | blue |
| Step Marker | 文本 ×1 | 否 | N/A | blue |

**实现位置**：`helpers/pptx/primitives.js`（每个 primitive 函数消费 contract）

### 4. Composition Gate

检查多个 primitive 组合成区域时的关系。

| 检查项 | 规则 | 严重性 |
|--------|------|--------|
| 区域重叠 | 不同 region 的元素大面积重叠 | hard_fail |
| 间距不足 | 非同 region 元素间距 < 0.1 inch | warning |
| 脚注碰撞 | footer_note 与非 footer 元素碰撞 | hard_fail |
| 容器小重叠 | 容器与非标签文本小面积重叠（< 20%） | acceptable_intentional |

**实现位置**：`helpers/static-qa.js`（语义碰撞规则）

### 5. Page Gate

最后检查整页叙事、主视觉和内容压缩。

| 检查项 | 规则 | 严重性 |
|--------|------|--------|
| 有标题 | 页面必须有 title 元素 | hard_fail |
| 有结论 | 页面必须有 takeaway | hard_fail |
| 内容过载 | 元素数量超过 layout_pattern 容量上限 | warning → needs_user_decision |
| 主视觉中心 | 页面应有明确视觉焦点 | warning |
| 无 placeholder | 不得残留 xxxx、lorem 等 | hard_fail |

**实现位置**：`helpers/static-qa.js`（内容完整性检查）、`references/visual-qa.md`

## 质量推进顺序

1. **Token Gate** 先通过：颜色、字号、字体全部来自注册表。
2. **Text Box Gate** 再通过：每个文本框有明确坐标，不重叠，不溢出。
3. **Primitive Gate** 再通过：每个原子组件内部结构正确。
4. **Composition Gate** 再通过：组件之间不对撞。
5. **Page Gate** 最后通过：整页叙事完整。

## Primitive Gallery

本 skill 提供专门的 primitive gallery fixture 用于回归测试：

- `fixtures/primitive-gallery.slide-ir.json`：覆盖所有 primitive 类型的正常样例和压力样例。
- `scripts/generate_primitive_gallery.js`：生成 primitive gallery PPTX。
- 通过 `generate_pptx_pipeline.js` 或 `inspect_pptx_artifact.js` 验证。

## 与 QA Gates 的关系

本文档定义分层 QA 体系的结构和推进顺序。
具体每个 gate 的检查项、严重性分级和误报处理详见 `references/qa-gates.md`。
具体每个 primitive 的实现细节详见 `helpers/pptx/primitives.js`。
