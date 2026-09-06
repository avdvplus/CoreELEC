#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

OUT="${1:-/storage/.kodi/temp/hdmi-state-$(date +%Y%m%d-%H%M%S).log}"
DEFAULT_DIR_USED="${1:+no}"

dump_file() {
  local path="$1"
  [ -r "$path" ] || return
  printf '\n--- %s ---\n' "$path"
  cat "$path" 2>&1 | head -200
}

dump_dir() {
  local dir="$1"
  [ -d "$dir" ] || return
  for f in "$dir"/*; do
    [ -f "$f" ] && dump_file "$f"
  done
}

{
  echo "=== meta ==="
  date
  uptime
  cat /etc/release 2>/dev/null | head -3

  echo
  echo "=== /sys/class/amhdmitx/amhdmitx0/ ==="
  dump_dir /sys/class/amhdmitx/amhdmitx0

  echo
  echo "=== /sys/class/video/ ==="
  dump_dir /sys/class/video

  echo
  echo "=== /sys/class/vfm/map ==="
  dump_file /sys/class/vfm/map

  echo
  echo "=== /sys/class/display/ ==="
  dump_dir /sys/class/display

  echo
  echo "=== /sys/class/vdec/ ==="
  dump_dir /sys/class/vdec

  echo
  echo "=== /sys/module/amdolby_vision/parameters/ ==="
  dump_dir /sys/module/amdolby_vision/parameters

  echo
  echo "=== kernel journal (tail 80) ==="
  journalctl -k -n 80 --no-pager 2>&1
} > "$OUT" 2>&1

echo "dumped to $OUT ($(stat -c %s "$OUT") bytes)"

if [ -z "$DEFAULT_DIR_USED" ]; then
  ls -1t /storage/.kodi/temp/hdmi-state-*.log 2>/dev/null | tail -n +6 | while read -r f; do
    rm -f "$f"
  done
fi
