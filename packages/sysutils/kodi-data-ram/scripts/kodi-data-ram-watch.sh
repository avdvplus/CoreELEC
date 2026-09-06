#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

[ -r /etc/kodi-data-ram.conf ] && . /etc/kodi-data-ram.conf
[ -r /storage/.config/kodi-data-ram.conf ] && . /storage/.config/kodi-data-ram.conf

: "${KDR_ENABLE:=0}"
: "${KDR_WATCH:=1}"
: "${KDR_RAM_RW:=/run/kodi-data-rw}"
: "${KDR_WATCH_INTERVAL:=4}"
: "${KDR_STOP_SETTLE:=3}"
: "${KDR_VDEC_STATUS:=/sys/class/vdec/vdec_status}"

[ "$KDR_ENABLE" = "1" ] || exit 0
[ "$KDR_WATCH" = "1" ] || exit 0

prev=0
while :; do
  sleep "$KDR_WATCH_INTERVAL"
  mountpoint -q "$KDR_RAM_RW" || continue
  if grep -q "device name" "$KDR_VDEC_STATUS" 2>/dev/null; then cur=1; else cur=0; fi
  [ "$cur" = "$prev" ] && continue
  prev="$cur"
  if [ "$cur" = "0" ]; then
    [ "$KDR_STOP_SETTLE" -gt 0 ] 2>/dev/null && sleep "$KDR_STOP_SETTLE"
    if grep -q "device name" "$KDR_VDEC_STATUS" 2>/dev/null; then prev=1; continue; fi
  fi
  KDR_FORCE_SYNC=1 /usr/lib/coreelec/kodi-data-ram-sync.sh
done
