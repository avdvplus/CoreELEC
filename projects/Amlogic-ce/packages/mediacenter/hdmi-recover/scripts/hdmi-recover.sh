#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

LOG_DIR="/storage/.kodi/temp"
LOG="${LOG_DIR}/hdmi-recover.log"
LOG_ROTATED="${LOG_DIR}/hdmi-recover.1.log"
KODI_GUI_XML="/storage/.kodi/userdata/guisettings.xml"
PHY_CYCLE="/usr/bin/hdmi-phy-cycle"
LOG_MAX_BYTES=262144

rotate_log() {
  [ -f "$LOG" ] || return 0
  local size
  size=$(wc -c < "$LOG" 2>/dev/null)
  [ -n "$size" ] && [ "$size" -gt "$LOG_MAX_BYTES" ] 2>/dev/null && mv -f "$LOG" "$LOG_ROTATED"
}

read_kodi_setting() {
  sed -nE "s|.*<setting id=\"$1\"[^>]*>([^<]*)</setting>.*|\1|p" "$KODI_GUI_XML" 2>/dev/null | head -1
}

load_kodi_auth() {
  local port=8080 user="" pass=""
  if [ -r "$KODI_GUI_XML" ]; then
    local p="$(read_kodi_setting services.webserverport)"
    [ -n "$p" ] && port="$p"
    if [ "$(read_kodi_setting services.webserverauthentication)" = "true" ]; then
      user="$(read_kodi_setting services.webserverusername)"
      pass="$(read_kodi_setting services.webserverpassword)"
    fi
  fi
  KODI_RPC="http://localhost:${port}/jsonrpc"
  if [ -n "$user" ] && [ -n "$pass" ]; then
    KODI_AUTH_ARG="-u ${user}:${pass}"
  else
    KODI_AUTH_ARG=""
  fi
}

kodi_notify() {
  curl -s --max-time 2 $KODI_AUTH_ARG -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"GUI.ShowNotification\",\"params\":{\"title\":\"HDMI\",\"message\":\"$1\",\"displaytime\":$2},\"id\":1}" \
    "$KODI_RPC" > /dev/null 2>&1
}

log_event() {
  mkdir -p "$LOG_DIR"
  rotate_log
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG"
}

load_kodi_auth
log_event "manual recovery invoked"

kodi_notify "Recovering HDMI..." 5000
sleep 0.3

"$PHY_CYCLE" || {
  log_event "FATAL: phy-cycle failed"
  exit 1
}

kodi_notify "HDMI recovered" 4000
log_event "manual recovery done"
