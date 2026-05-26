#!/usr/bin/env bash
set -euo pipefail

video="${1:?usage: extract-video-frames.sh <video.mp4> [output-dir]}"
out_dir="${2:-/tmp/playwright-video-frames}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required to inspect video evidence" >&2
  exit 2
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "ffprobe is required to inspect video evidence" >&2
  exit 2
fi

if [ ! -s "$video" ]; then
  echo "video is missing or empty: $video" >&2
  exit 1
fi

duration="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$video")"
awk -v d="$duration" 'BEGIN { exit !(d >= 3) }' || {
  echo "video is too short to prove an interaction: ${duration}s" >&2
  exit 1
}

rm -rf "$out_dir"
mkdir -p "$out_dir"
ffmpeg -hide_banner -loglevel error -y -i "$video" -vf fps=1 "$out_dir/frame-%03d.png"

count="$(find "$out_dir" -type f -name 'frame-*.png' | wc -l | tr -d ' ')"
if [ "$count" -lt 3 ]; then
  echo "expected at least 3 extracted frames, got $count" >&2
  exit 1
fi

echo "Extracted $count frames to $out_dir"
echo "Inspect first, middle, and last frame before committing:"
find "$out_dir" -type f -name 'frame-*.png' | sort | awk -v count="$count" '
  NR == 1 || NR == int((count + 1) / 2) || NR == count { print }
'
