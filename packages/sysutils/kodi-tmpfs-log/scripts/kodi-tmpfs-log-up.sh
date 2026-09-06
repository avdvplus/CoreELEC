#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

[ -r /etc/kodi-tmpfs-log.conf ] && . /etc/kodi-tmpfs-log.conf
[ -r /storage/.config/kodi-tmpfs-log.conf ] && . /storage/.config/kodi-tmpfs-log.conf

: "${KODI_TMPFS_LOG_ENABLE:=0}"
: "${KODI_TMPFS_PATH:=/run/kodi-tmp}"
: "${KODI_PERSIST_PATH:=/storage/.kodi/temp.persist}"
: "${KODI_RUNTIME_CONF:=/run/libreelec/kodi.conf}"
: "${KODI_STORAGE_COMMIT_REMOUNT:=0}"
: "${KODI_STORAGE_COMMIT_SEC:=60}"

if [ "$KODI_TMPFS_LOG_ENABLE" != "1" ]; then
  rm -f "$KODI_RUNTIME_CONF"
  for f in kodi.log kodi.old.log; do
    link="/storage/.kodi/temp/$f"
    if [ -L "$link" ]; then
      target=$(readlink "$link")
      case "$target" in "$KODI_TMPFS_PATH"/*) rm -f "$link" ;; esac
    fi
  done
  mountpoint -q "$KODI_TMPFS_PATH" && umount "$KODI_TMPFS_PATH" 2>/dev/null
  exit 0
fi

TOTAL_MB=$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)

if [ -z "$KODI_TMPFS_SIZE_MB" ] || [ "$KODI_TMPFS_SIZE_MB" = "0" ]; then
  SIZE_MB=$((TOTAL_MB / 8))
  [ "$SIZE_MB" -lt 192 ] && SIZE_MB=192
  [ "$SIZE_MB" -gt 512 ] && SIZE_MB=512
else
  SIZE_MB="$KODI_TMPFS_SIZE_MB"
fi

MAX_MB=$((TOTAL_MB / 2))
[ "$SIZE_MB" -gt "$MAX_MB" ] && SIZE_MB=$MAX_MB

mkdir -p "$KODI_TMPFS_PATH"
if ! mountpoint -q "$KODI_TMPFS_PATH"; then
  mount -t tmpfs -o size=${SIZE_MB}M,mode=755,nosuid,nodev tmpfs "$KODI_TMPFS_PATH" || exit 1
fi

mkdir -p "$KODI_PERSIST_PATH"
for f in kodi.log kodi.old.log; do
  if [ -f "$KODI_PERSIST_PATH/$f" ]; then
    cp -a "$KODI_PERSIST_PATH/$f" "$KODI_TMPFS_PATH/$f" 2>/dev/null || true
  fi
done
for f in "$KODI_PERSIST_PATH"/kodi_crashlog_*.log; do
  [ -f "$f" ] || continue
  cp -a "$f" "$KODI_TMPFS_PATH/" 2>/dev/null || true
done

mkdir -p "$(dirname "$KODI_RUNTIME_CONF")"
echo "KODI_TEMP=$KODI_TMPFS_PATH" > "$KODI_RUNTIME_CONF"
[ -n "$KODI_TMPFS_SWAPPINESS" ] && sysctl -qw vm.swappiness="$KODI_TMPFS_SWAPPINESS" 2>/dev/null

mkdir -p /storage/.kodi/temp
for f in kodi.log kodi.old.log; do
  rm -f "/storage/.kodi/temp/$f"
  ln -s "$KODI_TMPFS_PATH/$f" "/storage/.kodi/temp/$f"
done

if [ "$KODI_STORAGE_COMMIT_REMOUNT" = "1" ]; then
  FDEV=$(stat -c %d /flash 2>/dev/null)
  SDEV=$(stat -c %d /storage 2>/dev/null)
  if [ -z "$FDEV" ] || [ "$FDEV" != "$SDEV" ]; then
    mount -o remount,commit="$KODI_STORAGE_COMMIT_SEC" /storage 2>/dev/null || true
  fi
fi

exit 0
