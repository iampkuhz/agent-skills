# 后端选择策略（Backend Selection）

## 定位

本 skill 是 authoring + orchestration 层，不负责直接写入 PPTX 文件格式。
PPTX 的创建、编辑、shape 生成由 backend 实现。本文档定义后端选择策略。

## 后端类型

### 1. `pptxgenjs-native`（默认后端）

**适用场景**：
- 复杂架构图、流程图、可编辑 shape 组合。
- 需要精细控制位置、大小、颜色、连接线的页面。
- 需要 native editable PPTX（PowerPoint 中可直接编辑）。

**优势**：
- 完全可编程控制，适合 Layout Solver 输出的坐标方案。
- 生成的 PPTX 元素均为原生 shape/text/table，可编辑性强。

**限制**：
- 复杂图形（如自定义路径、渐变）支持有限。
- 需要 Node.js 运行时和 `pptxgenjs` 依赖。

### 2. `template-placeholder`

**适用场景**：
- 企业已有模板（`.potx` / `.pptx` 带 master slide）。
- 固定版式、已有 layout 的页面（如固定 header/footer/logo）。
- 需要严格遵循品牌规范的场景。

**优势**：
- 保留模板中的主题色、字体、logo、母版布局。
- 通过 placeholder 替换，降低坐标计算复杂度。

**限制**：
- 依赖用户或企业提供模板文件。
- 动态内容超出 placeholder 容量时需 fallback 到其他后端。

### 3. `svg-to-drawingml`（后续增强）

**适用场景**：
- 复杂视觉（如自定义图标、数据可视化图）但仍需尽量 editable。
- 需要将外部 SVG 转换为 PowerPoint DrawingML 元素。

**优势**：
- 支持更复杂的矢量图形。
- 转换为 DrawingML 后仍可编辑（优于整页图片）。

**限制**：
- 当前阶段为规划中，未实现。
- SVG 到 DrawingML 的转换可能存在保真度损失。

### 4. `html-to-pptx`（备选）

**适用场景**：
- 排版预览友好、需要快速原型的场景。
- 内容以表格、列表为主，对 editability 要求不高。

**优势**：
- 开发迭代快，CSS 排版成熟。
- 适合内容验证阶段。

**限制**：
- Editability 有损：生成的元素可能是图片组或扁平化 shape。
- 不推荐作为最终交付后端，除非用户明确接受。

## 选择决策树

```
用户是否提供了企业模板？
  ├── 是 → template-placeholder
  └── 否
      ├── 是否需要复杂可编辑 shape（架构图、流程图）？
      │   ├── 是 → pptxgenjs-native
      │   └── 否
      │       ├── 是否以表格/列表为主？
      │       │   ├── 是 → html-to-pptx（预览）或 pptxgenjs-native（最终）
      │       │   └── 否 → pptxgenjs-native（默认）
      │       └──
      └── 是否需要复杂矢量图形？
          ├── 是 → svg-to-drawingml（若可用）否则 pptxgenjs-native
          └── 否 → pptxgenjs-native
```

## 禁止项

- **禁止默认整页截图式图片交付**：除非用户明确要求或当前环境只能这样，否则不要将整页渲染为图片后插入 PPTX。
- **禁止在 backend 不可用时静默降级**：如果环境缺少必要依赖，应报告阻塞点而不是输出低质量结果。
- **禁止绕过 Slide IR 直接写坐标**：所有 backend 调用必须基于 Layout Solver 输出的布局方案。

## 与底层 pptx Skill 的关系

当前默认后端调用底层 `pptx` skill 完成 PPTX 级别的读写。
后续如果引入独立 backend（如直接调用 `pptxgenjs`），仍需遵循本 skill 的 Slide IR 和 Layout Solver 输出。
