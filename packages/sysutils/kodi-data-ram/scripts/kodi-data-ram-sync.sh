#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

[ -r /etc/kodi-data-ram.conf ] && . /etc/kodi-data-ram.conf
[ -r /storage/.config/kodi-data-ram.conf ] && . /storage/.config/kodi-data-ram.conf

: "${KDR_RAM_RW:=/run/kodi-data-rw}"
: "${KDR_PERSIST:=/storage/.kodi-data.persist}"
: "${KDR_LOG:=/storage/kodi-data-ram.log}"

mountpoint -q "$KDR_RAM_RW" || exit 0

if [ "${KDR_FORCE_SYNC:-0}" != "1" ] && grep -q "device name" /sys/class/vdec/vdec_status 2>/dev/null; then
  exit 0
fi

KDR_LOCK="/run/kodi-data-ram.sync.lock"
mkdir "$KDR_LOCK" 2>/dev/null || exit 0
trap 'rmdir "$KDR_LOCK" 2>/dev/null' EXIT INT TERM

for d in "$KDR_RAM_RW"/*; do
  [ -d "$d" ] || continue
  [ -n "$(ls -A "$d" 2>/dev/null)" ] || continue
  name=$(basename "$d")
  [ -f "/run/kodi-data-ram.complete-$name" ] || continue
  dst="$KDR_PERSIST/$name"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$d/" "$dst/" 2>/dev/null || true
  else
    cp -au "$d/." "$dst/" 2>/dev/null || true
  fi
done

if [ "${KDR_FORCE_SYNC:-0}" = "1" ]; then
  if grep -q "device name" /sys/class/vdec/vdec_status 2>/dev/null; then st=playing; else st=idle; fi
  [ -f "$KDR_LOG" ] && [ "$(wc -c < "$KDR_LOG")" -gt 262144 ] 2>/dev/null && mv -f "$KDR_LOG" "${KDR_LOG}.1" 2>/dev/null
  echo "$(date '+%Y-%m-%d %H:%M:%S') boundary sync (vdec=$st)" >> "$KDR_LOG" 2>/dev/null || true
fi

exit 0
