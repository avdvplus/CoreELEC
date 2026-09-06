#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

[ -r /etc/kodi-data-ram.conf ] && . /etc/kodi-data-ram.conf
[ -r /storage/.config/kodi-data-ram.conf ] && . /storage/.config/kodi-data-ram.conf

: "${KDR_RAM_RO:=/run/kodi-data-ro}"
: "${KDR_USERDATA:=/storage/.kodi/userdata}"

[ -x /usr/lib/coreelec/kodi-data-ram-sync.sh ] && KDR_FORCE_SYNC=1 /usr/lib/coreelec/kodi-data-ram-sync.sh

TH="$KDR_USERDATA/Thumbnails"
OV="$KDR_RAM_RO/Thumbnails.over"
if mountpoint -q "$TH" 2>/dev/null && [ -d "$OV" ]; then
  if umount "$TH" 2>/dev/null && [ -n "$(ls -A "$OV" 2>/dev/null)" ]; then
    find "$OV" -type c -delete 2>/dev/null
    cp -au "$OV/." "$TH/" 2>/dev/null || true
  fi
fi

exit 0
