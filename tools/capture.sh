#!/bin/bash
# Usage: tools/capture.sh <scenario> [WxH] [scene]
# Renders a scripted capture scenario with the full Forward+ renderer via Xvfb + Vulkan (lavapipe).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
scenario="$1"; size="${2:-1280x720}"; scene="${3:-res://debug/sandbox.tscn}"
out="$root/build/captures/$scenario-$size"
mkdir -p "$out"
cd "$root/game"
xvfb-run -a -s "-screen 0 ${size}x24" godot --rendering-driver vulkan --resolution "$size" \
  --fixed-fps 30 --disable-vsync "$scene" -- --capture-scenario="$scenario" --capture-dir="$out" 2>&1 \
  | grep -vE "ALSA|audio_driver|All audio drivers|audio_server|^\s*at: " || true
ls "$out"
