#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

k() { echo "boot-sanity: $*" > /dev/kmsg 2>/dev/null || true; }

FDEV=$(stat -c %d /flash 2>/dev/null)
SDEV=$(stat -c %d /storage 2>/dev/null)
if [ -n "$FDEV" ] && [ "$FDEV" = "$SDEV" ]; then
  k "flash and storage share one filesystem (dev $FDEV)"
fi

OPTS=$(awk '$2=="/storage"{print $4; exit}' /proc/mounts)
if echo "$OPTS" | grep -qE '(^|,)ro(,|$)'; then
  k "storage is mounted read-only (opts $OPTS)"
fi

PROBE="/storage/.boot-sanity-probe"
if touch "$PROBE" 2>/dev/null; then
  rm -f "$PROBE" 2>/dev/null
else
  k "storage write probe failed"
fi

for m in /run/kodi-data-rw /run/kodi-data-ro /run/kodi-tmp; do
  mountpoint -q "$m" 2>/dev/null || continue
  USE=$(df -P "$m" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')
  if [ -n "$USE" ] && [ "$USE" -ge 80 ] 2>/dev/null; then
    k "$m at ${USE}% of capacity"
  fi
done

AVAIL_MB=$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo)
if [ -n "$AVAIL_MB" ] && [ "$AVAIL_MB" -lt 200 ] 2>/dev/null; then
  k "low memory: ${AVAIL_MB}MB available"
fi

exit 0
