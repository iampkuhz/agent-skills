---
name: feipi-summarize-video-url
description: 用于根据视频 URL 调用来源技能提取带时间戳文本，并按用户意图分段交付摘要、扩展背景分析或单独的上下文背景。在需要默认只做内容摘要、按需补背景时使用。
---

# 视频 URL 分段总结技能（中文）

## 适用场景

1. 用户给出 YouTube 或 Bilibili URL，只想先拿到结构化摘要，不希望默认继续做背景分析。
2. 用户明确要求“继续扩展分析”“补充背景/影响/相关新闻/最新进展”，希望在摘要后继续补背景。
3. 用户单独追问“这个视频的上下文背景是什么”“这件事的来龙去脉是什么”，只需要背景说明，不需要先看摘要。

## 不适用场景

1. 用户没有提供视频 URL。
2. 只要本地转写，不需要基于视频内容交付摘要或背景说明。
3. 用户要求直接跳过来源技能、手工拼接下载/转写命令。

## 先确认什么

1. 必填
- 视频 URL

2. 按需确认
- 用户原始指令中是否明确要求高质量转写
- 用户是否明确要求扩展分析，还是只做摘要
- 用户是否单独问“上下文背景/来龙去脉”
- 用户是否明确要求“相关新闻/最新进展/当前影响”
- 是否已有视频标题或上下文说明

默认策略：
1. 有“高质量/准确/逐字”等明确要求时，自动走 `accurate`。
2. 其他情况默认走 `fast`。
3. 未明确要求背景时，意图默认为 `summary`，只交付摘要。
4. 明确要求“扩展分析/顺带分析背景/补充影响/结合相关新闻/最新进展”时，意图为 `expand`。
5. 明确只问“上下文背景/背景知识/来龙去脉”时，意图为 `background-only`。
6. 背景阶段若未明确要求“相关新闻/最新/最近/现状”，默认 `--news off`，优先稳定背景资料，不主动搜索相关新闻。

## 核心目标

输入视频 URL，根据用户意图只生成当前需要的请求包与交付结果，不强制把两个任务绑在一起。

1. `summary`（默认）
- 输出 `摘要概述` 与 `附件`。
- 只做内容摘要，不主动补背景、影响或相关新闻。

2. `expand`（显式扩展）
- 先输出 `摘要概述` 与 `附件`。
- 再输出 `相关影响和背景分析`。

3. `background-only`（单独问背景）
- 只输出 `上下文背景`。
- 不强制先生成或展示摘要结果。

## 关键原则

1. 不做本地“伪摘要”
- 本 skill 负责提取文本与构建请求包，交付内容必须由大模型基于转写生成。
- 禁止用词频/规则模板直接拼接结论。

2. 执行严格性（强制）
- 只能使用依赖技能提供的 `whisper.cpp` 转写链路（`whisper-cli`）。
- 禁止改用 Python 版 whisper、OpenAI whisper 或其他转写工具。
- 禁止自动下载或切换其他 whisper 模型文件。
- fast 只允许使用已存在的 `ggml-base.bin`（或 `ggml-small.bin` / `ggml-large-v3-turbo-q5_0.bin`）。
- accurate 只允许使用已存在的 `ggml-large-v3-q5_0.bin`。
- 若模型缺失，只能提示用户按仓库脚本/说明手动安装，禁止自作主张联网下载。
- 必须通过依赖脚本调用转写，禁止手写 `whisper-cli` 参数（例如误用 `-ot` 会触发 `stoi` 错误）。
- 必须通过 `scripts/extract_video_text.sh` 获取转写，禁止直接调用 `download_youtube.sh` / `download_bilibili.sh`。
- 若产物未落在 `source-url_key` 子目录或文件名仍含空格，视为失败，必须重新抽取或重命名后再继续。

3. 分段触发强约束
- 未显式要求背景时，不得自动补第二阶段。
- 只有 `expand` 才允许同一轮连续输出“摘要 + 背景”。
- `background-only` 只输出背景，不强制先给摘要。
- 默认摘要模式禁止主动补充视频外背景、相关影响和相关新闻。

4. 摘要与时间线合并
- 不再单独输出“核心观点时间线”章节。
- 时间线信息必须并入 `摘要概述` 的列表锚点中（仅时间）。
- 时间格式统一：
  - 视频时长未超过 1 小时：`MM:SS`
  - 视频时长超过 1 小时：`HH:MM:SS`
  - 禁止 `T+00:00:00` 与字幕行号。

5. 总分结构强约束
- `摘要概述` 第一段必须是总述（先总后分）。
- 后续列表按关系选型：
  - 有先后/因果链：有序列表。
  - 关系并列：无序列表。
  - 存在总分关系：使用二级列表（最多二级）。

6. 背景模式外部化约束
- 背景内容必须以视频外公开资料为主，不以转写复述冒充背景。
- 如需引用视频内容，仅作为“关联说明”或“对照观点”，不得替代外部背景。
- 未明确要求相关新闻时，优先历史背景、制度沿革、术语解释、官方基础文件、研究资料，不主动搜索相关新闻。
- 明确要求“相关新闻/最新进展/现状”时，才允许补充时效性材料，并在来源中写清日期。

7. `expand` 模式交付约束
- 输出标题必须为 `## 相关影响和背景分析`。
- 章节内固定包含：
  - `### 背景知识补充（约2/3）`
  - `### 关键影响（约1/3）`
- 背景必须覆盖视频中的关键术语/人物/机构/事件（至少 3-6 个），先列清单再补充解释。
- 影响只写最关键 1-2 条，禁止冗长推演与空泛表述。
- 来源清单不少于 3 条；仅在用户明确要求相关新闻/最新进展时，才强制补 1-2 条新闻原文或原始文件。

8. `background-only` 模式交付约束
- 输出标题必须为 `## 上下文背景`。
- 章节内固定包含：
  - `### 关键背景脉络`
  - `### 与视频的关联`
  - `### 来源清单`
- 先从视频中抽取 3-6 个关键术语/人物/机构/事件，再解释它们的背景脉络与相互关系。
- 不强制输出“关键影响”，除非用户额外点明需要。

9. 去套话
- 请求包中显式禁用无意义模板句。
- 目标是直接提炼信息，不是点评文本写法。

10. 详略由模型读文本后决定
- 不依赖本地信息密度脚本。
- 仅按时长给建议条目区间，具体详略由远程模型判断。

## 依赖技能（强约束）

路径基准：相对 `SKILL.md` 所在目录。

必须依赖：
1. `../feipi-read-youtube-video`
2. `../feipi-read-bilibili-video`

规则：
- YouTube：调用 `../feipi-read-youtube-video/scripts/download_youtube.sh`
- Bilibili：调用 `../feipi-read-bilibili-video/scripts/download_bilibili.sh`
- 依赖缺失：立即停止并提示用户先配置。

## 输入与输出

1. 最少输入
- 视频 URL

2. 可选输入
- 视频标题
- 用户原始指令（用于自动判定提取质量档位与交付意图）
- 质量档位参数：`--quality auto|fast|accurate`（默认 `auto`）
- 背景请求模式：`--mode expand|background-only`
- 新闻范围：`--news off|on`（默认 `off`）

3. 输出
- `extract_video_text.sh` 会在 `output_dir` 下按 `source-url_key` 自动建子目录（如 `youtube-5Foo8VUZlFM`、`bilibili-BV1Q5fgBfExq`）。
- 子目录内包含本次 URL 的音频/字幕/转写与日志，避免多视频文件平铺。
- 产物文件名自动去空格（空格替换为下划线）。
- `summary_request.md`：`summary` 或 `expand` 模式使用的摘要请求包（`摘要概述` + `附件`）。
- `summary_result.md`：`summary` 或 `expand` 模式的摘要结果。
- `background_request.md`：`expand` 或 `background-only` 模式使用的背景请求包。
- `background_result.md`：背景结果；`expand` 模式标题为 `相关影响和背景分析`，`background-only` 模式标题为 `上下文背景`。

## 自动选档规则（提速重点）

1. 默认策略（`--quality auto`）
- 指令明确要求高质量（如“高质量/高精度/准确/逐字”）时，选择 `accurate`。
- 其他情况默认选择 `fast`。

2. `mode=auto` 的执行顺序
- `accurate`：先 `whisper`，失败再回退 `subtitle`。
- `fast`：先 `subtitle`，失败再回退 `whisper`。

3. 观测字段
- `extract_video_text.sh` 输出中包含：
  - `run_dir`
  - `whisper_profile`
  - `selection_reason`
  - `strategy`

## 工作流（Explore -> Plan -> Implement -> Verify）

1. Explore
- `scripts/extract_video_text.sh` 内部识别来源（YouTube/Bilibili）。
- `scripts/extract_video_text.sh --check-deps` 校验依赖与自动选档结果。
- 先判断用户意图属于 `summary`、`expand` 还是 `background-only`。
- 再判断背景阶段是否明确要求“相关新闻/最新进展”；未明确时默认 `--news off`。
- 若检测到 YouTube 在 Cookie/浏览器认证下失败，会自动以“无 Cookie”重试，并输出 `*-noauth.log` 便于排查。
- 若转写失败，只能回到依赖技能排查网络/认证/模型缺失；禁止切换转写工具或自动下载模型。

2. Plan
- 根据用户指令选择质量档位（默认快档，显式高质量则慢档）。
- `scripts/extract_video_text.sh` 获取带时间戳文本。
- `summary`：只生成摘要请求包并交付摘要结果。
- `expand`：先交付摘要，再生成背景请求包并继续交付背景分析。
- `background-only`：直接生成背景请求包并交付上下文背景，不强制先展示摘要。

3. Implement
- `summary`：使用 `scripts/render_summary_prompt.sh` 生成 `summary_request.md`，并只产出 `summary_result.md`。
- `expand`：先生成并交付 `summary_result.md`，再使用 `scripts/render_background_prompt.sh --mode expand` 生成 `background_request.md`，继续产出 `background_result.md`。
- `background-only`：直接使用 `scripts/render_background_prompt.sh --mode background-only` 生成 `background_request.md`；若没有现成摘要，第三个参数传 `-`。
- 只有在用户明确要求相关新闻/最新进展时，背景脚本才传 `--news on`；其他情况保持 `--news off`。

4. Verify
- 摘要请求包包含 `<TRANSCRIPT_START>` 与 `<TRANSCRIPT_END>`。
- 摘要请求包包含反套话约束、列表结构约束与时间锚点约束。
- 摘要请求包明确“当前只做摘要，不扩展背景/影响/相关新闻”。
- `expand` 请求包明确要求输出 `## 相关影响和背景分析`，并包含“背景约 2/3 + 影响约 1/3”约束。
- `background-only` 请求包明确要求输出 `## 上下文背景`，且支持在无摘要文件时生成。
- 背景请求包默认包含“不主动搜索相关新闻”的边界；仅 `--news on` 时才出现时效性补充要求。
- 转写文本与产物文件名不包含空格。
- 各模式只要求本模式对应的请求包/结果文件非空：
  - `summary`：`summary_request.md`、`summary_result.md`
  - `expand`：`summary_request.md`、`summary_result.md`、`background_request.md`、`background_result.md`
  - `background-only`：`background_request.md`、`background_result.md`

## 常见失败与修复

1. 执行方默认把摘要和背景一起做完
- 处理：回到意图判断；未显式要求背景时，只执行 `summary`。

2. 用户单独问背景时仍被迫先看摘要
- 处理：改用 `background-only`，并允许 `summary_path` 传 `-`。

3. 摘要模式主动补了相关新闻
- 处理：回到摘要请求包边界，删除背景/影响/相关新闻扩写，只保留内容摘要。

4. 背景分析只是复述视频
- 处理：回到背景模式要求，补充视频外公开资料与来源清单。

5. 用户没提“最新”，却被补了近期新闻
- 处理：确认背景脚本是否误用了 `--news on`；默认应保持 `--news off`。

## 标准命令

1. 检查依赖：
```bash
bash scripts/extract_video_text.sh "<video_url>" "./tmp/video-text" auto \
  --instruction "请快速总结" \
  --check-deps
```

2. 自动选档提取（默认快档）：
```bash
bash scripts/extract_video_text.sh "<video_url>" "./tmp/video-text" auto \
  --instruction "请快速提取并总结重点"
```

3. 高质量提取（触发慢档）：
```bash
bash scripts/extract_video_text.sh "<video_url>" "./tmp/video-text" auto \
  --instruction "请高质量逐字转写，准确优先"
```

4. 生成默认摘要请求包：
```bash
bash scripts/render_summary_prompt.sh \
  "<video_url>" \
  "示例视频标题" \
  1500 \
  "./tmp/video-text/xxx.txt" \
  80000 \
  > "./tmp/video-text/summary_request.md"
```

5. 生成“扩展分析”背景请求包：
```bash
bash scripts/render_background_prompt.sh \
  "<video_url>" \
  "示例视频标题" \
  "./tmp/video-text/summary_result.md" \
  "./tmp/video-text/xxx.txt" \
  --mode expand \
  --news off \
  > "./tmp/video-text/background_request.md"
```

6. 生成“单独问背景”请求包：
```bash
bash scripts/render_background_prompt.sh \
  "<video_url>" \
  "示例视频标题" \
  "-" \
  "./tmp/video-text/xxx.txt" \
  --mode background-only \
  --news off \
  > "./tmp/video-text/background_request.md"
```

7. 生成“扩展分析 + 新闻范围开启”请求包：
```bash
bash scripts/render_background_prompt.sh \
  "<video_url>" \
  "示例视频标题" \
  "./tmp/video-text/summary_result.md" \
  "./tmp/video-text/xxx.txt" \
  --mode expand \
  --news on \
  > "./tmp/video-text/background_request.md"
```

## 验收标准

1. 依赖缺失时失败退出。
2. 输出文本带时间戳。
3. 多 URL 场景下，文件按 `source-url_key` 子目录分组，不在根目录平铺。
4. 自动选档结果可观察（`run_dir`、`whisper_profile`、`selection_reason`、`strategy`）。
5. 默认摘要请求包包含字幕文本、反套话约束、总分结构约束、时间锚点约束（无行号），且明确禁止扩展到背景/影响/相关新闻。
6. `expand` 请求包要求输出 `相关影响和背景分析`，并显式约束“背景优先、影响精简、来源可追溯”。
7. `background-only` 请求包要求输出 `上下文背景`，并支持无摘要输入。
8. 背景模式默认 `--news off`，不主动搜索相关新闻；只有用户明确要求时才用 `--news on`。
9. 仅对当前模式要求对应结果文件非空，不再强制四个产物每次都同时出现。
10. 产物文件名不包含空格。

## 渐进式披露

- 来源：`references/sources.md`
