#!/usr/bin/env bash
set -euo pipefail

# YouTube 下载脚本（中文注释版）
#
# 用法：
#   bash scripts/download_youtube.sh <url> [output_dir] [mode]
#
# 参数说明：
#   1) url        : 必填，YouTube 视频链接
#   2) output_dir : 可选，输出目录，默认 ./downloads
#   3) mode       : 可选，支持三种模式
#      - video  : 下载视频（优先最佳视频+音频并合并 mp4）
#      - audio  : 仅提取音频并转为 mp3
#      - dryrun : 只做“可下载性验证”，不产生任何下载文件
#
# dryrun 说明（关键）：
#   - 使用 yt-dlp 的 --simulate 进行模拟执行
#   - 会输出视频 title/id，确认链接可解析
#   - 不会写入视频/音频文件，适合先探测再正式下载

URL="${1:-}"
OUT_DIR="${2:-./downloads}"
MODE="${3:-video}"

if [[ -z "$URL" ]]; then
  echo "用法: bash scripts/download_youtube.sh <url> [output_dir] [video|audio|dryrun]" >&2
  exit 1
fi

# 依赖检查：无 yt-dlp 无法执行任何模式
if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "缺少依赖: yt-dlp" >&2
  echo "安装示例: brew install yt-dlp" >&2
  exit 1
fi

# dryrun 不做转码/合并，因此不强制 ffmpeg
if [[ "$MODE" != "dryrun" ]] && ! command -v ffmpeg >/dev/null 2>&1; then
  echo "缺少依赖: ffmpeg" >&2
  echo "安装示例: brew install ffmpeg" >&2
  exit 1
fi

# 输出目录若不存在则自动创建
mkdir -p "$OUT_DIR"

# 统一命名模板：
#   <标题> [<视频ID>].<扩展名>
# 说明：restrict-filenames 会移除不安全字符，避免路径问题
OUTPUT_TEMPLATE="$OUT_DIR/%(title).200B [%(id)s].%(ext)s"
COMMON_ARGS=(
  --no-playlist
  --restrict-filenames
  --output "$OUTPUT_TEMPLATE"
)

case "$MODE" in
  dryrun)
    # 仅模拟，不下载：
    # --simulate         : 只模拟流程
    # --print title/id   : 输出标题和 ID 作为“可解析证据”
    yt-dlp "${COMMON_ARGS[@]}" --simulate --print title --print id "$URL"
    ;;
  audio)
    # 音频模式：
    # - 选择最佳音频流
    # - 抽取并转码为 mp3
    yt-dlp "${COMMON_ARGS[@]}" \
      --format "bestaudio/best" \
      --extract-audio \
      --audio-format mp3 \
      --audio-quality 0 \
      "$URL"
    ;;
  video)
    # 视频模式：
    # - 优先“最佳视频+最佳音频”组合
    # - 回退到 best 单流
    # - 最终合并容器为 mp4
    yt-dlp "${COMMON_ARGS[@]}" \
      --format "bv*+ba/b" \
      --merge-output-format mp4 \
      "$URL"
    ;;
  *)
    echo "不支持的 mode: $MODE (可选: video|audio|dryrun)" >&2
    exit 1
    ;;
esac

# 统一完成输出，便于外层日志采集
echo "完成: mode=$MODE, output_dir=$OUT_DIR"
