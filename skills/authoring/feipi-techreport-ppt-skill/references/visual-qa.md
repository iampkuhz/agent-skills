# 视觉 QA 检查（Visual QA）

## 与 Static QA 的关系

本文件定义的是 **Render QA**（渲染后视觉检查），是 Static QA 的后置门禁。

- **Static QA**（`helpers/static-qa.js`）：在 Slide IR 层面检查几何约束，无需渲染。检查元素边界、重叠、间距、字号等。
- **Render QA**（本文件）：在渲染为 PNG 后检查视觉级别的问题，能发现 Static QA 无法覆盖的渲染差异、字体渲染、实际视觉效果等。

**两者都是必需的**。Static QA 是 Render QA 的前置门禁，但 Static QA 通过不能替代 Render QA。

## Render QA 是必需闭环

Render QA 是交付前的 **强制门禁**。只要环境中存在渲染引擎（LibreOffice/soffice），就必须执行。

```
Static QA 通过 → PPTX 编译 → PPTX → PNG 渲染 → Render Manifest → Visual QA Report → Auto Repair
```

**如果无法渲染**：
1. 必须报告"无法进行完整视觉 QA"，并说明已完成哪些替代检查（Static QA、内容完整性）。
2. 不允许只凭生成脚本成功就交付。
3. 必须输出人工检查清单，明确哪些项需要人工在 PowerPoint 中确认。

## 工程入口

| 文件 | 职责 |
|------|------|
| `scripts/render_pptx.sh` | PPTX → PNG 渲染包装器（shell 层） |
| `scripts/render_pptx.js` | 渲染 manifest 生成（Node 层） |
| `scripts/visual_qa_report.js` | Visual QA 报告生成 |
| `helpers/render/manifest.js` | PNG header 解析 + manifest 构建工具 |

### 使用方式

```bash
# 1. 渲染 PPTX 为 PNG
bash scripts/render_pptx.sh <input.pptx> <output_dir>

# 2. 生成 Visual QA 报告
node scripts/visual_qa_report.js <output_dir>/render-manifest.json
node scripts/visual_qa_report.js <output_dir>/render-manifest.json --json
```

### 渲染策略

按可用性依次尝试：
1. `soffice --headless`
2. `libreoffice --headless`
3. macOS `/Applications/LibreOffice.app/Contents/MacOS/soffice`

如果以上均不可用：
- 输出特定退出码 100（非失败，是跳过状态）。
- 生成 skip 状态的 manifest，说明缺失原因和安装建议。
- 不自动安装系统软件。
- `visual_qa_report.js` 接收到 skip manifest 后，输出"无法进行完整视觉 QA"警告和人工检查清单。

PNG 转换策略：
- 优先：`PPTX → PNG` 直接转换
- 降级：`PPTX → PDF → PNG`（使用 sips/macOS 内置或 ImageMagick convert）

## QA 态度

默认第一版一定有问题。**QA 是找 bug，不是确认成功。** 主动寻找溢出、重叠、截断、过密等视觉缺陷。

## 检查清单

逐一检查以下项：

| # | 检查项 | 关注点 |
|---|--------|--------|
| 1 | 元素溢出 | 是否有元素超出页面边界 |
| 2 | 文本截断 | 是否有文字被裁剪或显示不全 |
| 3 | 非预期重叠 | 是否有元素互相覆盖或穿插 |
| 4 | 箭头穿过文字 | 是否有连接线穿过文本块 |
| 5 | 表格可读性 | 行列是否清晰可辨，是否过密 |
| 6 | 文字密度 | bullet 之间是否有足够间距 |
| 7 | 字号下限 | 是否有文字低于 10pt（正文）/ 8.5pt（表格/标签） |
| 8 | 元素间距 | 是否有元素间距过近（< 0.1 inch） |
| 9 | 页面边距 | 四周边距是否满足最小要求 |
| 10 | 颜色对比 | 文字和背景是否有足够对比度 |
| 11 | 主图突出 | 主图是否是视觉中心，是否被其他元素分散注意力 |
| 12 | Takeaway 存在 | 页面是否有明确的一行结论 |
| 13 | Placeholder 残留 | 是否存在 xxxx、lorem、placeholder 文本 |
| 14 | 未提供的事实 | 是否包含用户未提供的信息 |

## 硬失败门禁

出现以下任一情况，视觉 QA 必须判定失败，并进入修复：

- 任意文本、图形、表格、卡片发生非预期重叠。
- 表格、卡片或脚注超出页面边界。
- 文本被截断、行高不足、字符挤压或内容被遮挡。
- 脚注压在主体内容上，或脚注与表格/图形重叠。
- 主表超过 5 行 × 4 列且没有明显降维。
- 页面上有两个以上同等视觉中心，导致 CTO 无法快速抓住结论。
- 页面上半部分拥挤、下半部分大面积空白。
- 字号低于硬规则下限。
- 右侧说明卡、结论卡、图例覆盖主视觉。

不要把这些问题描述为“可接受的小瑕疵”。它们会直接降低可信度。

## 失败样例识别

如果渲染图出现以下形态，默认按失败处理：

- 大表占据页面主体，但右下角又叠加说明卡。
- 表格底部文字与脚注混在一起。
- 单元格文字被强行换行到 3 行以上。
- 颜色只高亮一整列，其他结论没有视觉表达。
- 标题很大但内容区没有足够空间。
- 页面底部留白很大，说明布局预算分配错误。

## 使用底层 pptx Skill

- 使用底层 `pptx` skill 的文本提取能力检查幻灯片内容，确认无残留 placeholder 或错误文本。
- 使用底层 `pptx` skill 的渲染/缩略图/图片检查能力做视觉 QA。
- 如果能渲染成图片，应直接视觉检查图片。
- 如果不能渲染，至少做文本和结构检查，并明确说明："无法进行完整视觉 QA，已做文本和结构检查，以下限制需要注意：..."

## QA 输出格式

视觉 QA 结果应输出：

```
## Visual QA

- 通过项：...
- 硬失败：...（如有）
- 发现问题：...（如有）
- 修复操作：...（如需要修复）
```

如果发现硬失败，不能直接交付，应先执行 `references/repair-policy.md` 中的修复策略。
