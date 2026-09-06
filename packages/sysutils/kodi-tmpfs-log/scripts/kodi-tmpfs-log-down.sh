#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

/usr/lib/coreelec/kodi-tmpfs-log-sync.sh

[ -r /etc/kodi-tmpfs-log.conf ] && . /etc/kodi-tmpfs-log.conf
[ -r /storage/.config/kodi-tmpfs-log.conf ] && . /storage/.config/kodi-tmpfs-log.conf

: "${KODI_RUNTIME_CONF:=/run/libreelec/kodi.conf}"

rm -f "$KODI_RUNTIME_CONF"

exit 0
