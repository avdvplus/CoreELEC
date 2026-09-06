#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

[ -r /etc/kodi-tmpfs-log.conf ] && . /etc/kodi-tmpfs-log.conf
[ -r /storage/.config/kodi-tmpfs-log.conf ] && . /storage/.config/kodi-tmpfs-log.conf

: "${KODI_TMPFS_LOG_ENABLE:=0}"
: "${KODI_TMPFS_PATH:=/run/kodi-tmp}"
: "${KODI_PERSIST_PATH:=/storage/.kodi/temp.persist}"
: "${KODI_LOG_TRUNCATE_PERCENT:=90}"
: "${KODI_LOG_KEEP_PERCENT:=20}"

[ "$KODI_TMPFS_LOG_ENABLE" = "1" ] || exit 0
mountpoint -q "$KODI_TMPFS_PATH" || exit 0

mkdir -p "$KODI_PERSIST_PATH"

for f in kodi.log kodi.old.log; do
  src="$KODI_TMPFS_PATH/$f"
  dst="$KODI_PERSIST_PATH/$f"
  [ -f "$src" ] || continue
  ssize=$(wc -c < "$src" 2>/dev/null)
  dsize=0
  [ -f "$dst" ] && dsize=$(wc -c < "$dst" 2>/dev/null)
  [ -n "$ssize" ] || continue
  if [ "${dsize:-0}" -gt 0 ]; then
    IFS= read -r shead < "$src" 2>/dev/null
    IFS= read -r dhead < "$dst" 2>/dev/null
    if [ -n "$shead" ] && [ "$shead" = "$dhead" ]; then
      if [ "$ssize" -eq "$dsize" ]; then
        continue
      fi
      if [ "$ssize" -gt "$dsize" ]; then
        tail -c +$((dsize + 1)) "$src" >> "$dst" 2>/dev/null || rm -f "$dst"
        continue
      fi
    fi
  fi
  if cp -a "$src" "$dst.new" 2>/dev/null; then
    mv "$dst.new" "$dst"
  else
    rm -f "$dst.new"
  fi
done

for f in "$KODI_TMPFS_PATH"/kodi_crashlog_*.log; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  [ -f "$KODI_PERSIST_PATH/$base" ] && continue
  cp -a "$f" "$KODI_PERSIST_PATH/" 2>/dev/null || true
done

rm -f "$KODI_TMPFS_PATH"/.kodi.log.preserve.*

LIVE_LOG="$KODI_TMPFS_PATH/kodi.log"
if [ -f "$LIVE_LOG" ] && [ "$KODI_LOG_TRUNCATE_PERCENT" -gt 0 ] 2>/dev/null; then
  DF_LINE=$(df -P -k "$KODI_TMPFS_PATH" 2>/dev/null | tail -1)
  CAP_KB=$(echo "$DF_LINE" | awk '{print $2}')
  USED_KB=$(echo "$DF_LINE" | awk '{print $3}')
  if [ -n "$CAP_KB" ] && [ -n "$USED_KB" ] && [ "$CAP_KB" -gt 0 ] 2>/dev/null; then
    USED_PCT=$((USED_KB * 100 / CAP_KB))
    if [ "$USED_PCT" -ge "$KODI_LOG_TRUNCATE_PERCENT" ]; then
      KEEP_BYTES=$((CAP_KB * 1024 * KODI_LOG_KEEP_PERCENT / 100))
      PRES="$KODI_TMPFS_PATH/.kodi.log.preserve.$$"
      if tail -c "$KEEP_BYTES" "$LIVE_LOG" > "$PRES" 2>/dev/null; then
        : > "$LIVE_LOG"
        cat "$PRES" >> "$LIVE_LOG" 2>/dev/null
        logger -t kodi-tmpfs-log \
          "kodi.log truncated: tmpfs ${USED_PCT}% > ${KODI_LOG_TRUNCATE_PERCENT}% threshold; preserved last ${KODI_LOG_KEEP_PERCENT}% of cap"
      fi
      rm -f "$PRES"
    fi
  fi
fi

exit 0
