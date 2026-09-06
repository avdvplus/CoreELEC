#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

HDMI_SYSFS="/sys/class/amhdmitx/amhdmitx0"
HDMI_PKT="/sys/kernel/debug/amhdmitx/hdmi_pkt"
VIDEO_SYSFS="/sys/class/video"
LOG_DIR="/storage/.kodi/temp"
LOG="${LOG_DIR}/hdmi-watchdog.log"
LOG_ROTATED="${LOG_DIR}/hdmi-watchdog.1.log"

POLL_SLOW=2
POLL_FAST=1
BASELINE_WAIT=5
BASELINE_SAMPLES=10
CONFIRM_SAMPLES=3
LOG_MAX_BYTES=262144

rotate_log() {
  [ -f "$LOG" ] || return 0
  local size
  size=$(wc -c < "$LOG" 2>/dev/null)
  [ -n "$size" ] && [ "$size" -gt "$LOG_MAX_BYTES" ] 2>/dev/null && mv -f "$LOG" "$LOG_ROTATED"
}

log_event() {
  mkdir -p "$LOG_DIR"
  rotate_log
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG"
}

strip_spaces() {
  STRIPPED="$1"
  while :; do
    case "$STRIPPED" in
      *" "*) STRIPPED="${STRIPPED%% *}${STRIPPED#* }" ;;
      *) break ;;
    esac
  done
}

get_cts() {
  local k v rest
  CTS=""
  while read -r k v rest; do
    if [ "$k" = "CTS:" ]; then
      CTS="$v"
      break
    fi
  done 2>/dev/null < "$HDMI_PKT"
}

get_mode() {
  local m="" f="" a=""
  IFS= read -r m 2>/dev/null < "$HDMI_SYSFS/disp_mode"
  IFS= read -r f 2>/dev/null < "$HDMI_SYSFS/frac_rate_policy"
  IFS= read -r a 2>/dev/null < "$HDMI_SYSFS/attr"
  strip_spaces "$m"; m="$STRIPPED"
  strip_spaces "$f"; f="$STRIPPED"
  strip_spaces "$a"; a="$STRIPPED"
  MODE="${m}/${f:-0}/${a}"
}

get_hdr() {
  HDR=""
  IFS= read -r HDR 2>/dev/null < "$HDMI_SYSFS/hdmi_hdr_status"
  strip_spaces "$HDR"; HDR="$STRIPPED"
}

video_active() {
  local fw="" line="" fps=""
  IFS= read -r fw 2>/dev/null < "$VIDEO_SYSFS/frame_width"
  IFS= read -r line 2>/dev/null < "$VIDEO_SYSFS/fps_info"
  case "$line" in
    *:*) fps="${line#*:}"; fps="${fps%% *}" ;;
  esac
  [ -n "$fw" ] && [ "$fw" -gt 0 ] 2>/dev/null && [ -n "$fps" ] && [ "$fps" != "0x0" ]
}

median_of() {
  printf '%s' "$1" | sort -n | awk -v n="$2" 'NR==int(n/2)+1 {print; exit}'
}

capture_baseline() {
  local vals="" v
  local i=0
  while [ "$i" -lt "$BASELINE_SAMPLES" ]; do
    get_cts
    v="$CTS"
    if [ -n "$v" ] && [ "$v" -gt 0 ] 2>/dev/null; then
      vals="$vals$v
"
      i=$((i + 1))
    fi
    sleep 0.3
  done
  median_of "$vals" "$BASELINE_SAMPLES"
}

deviated() {
  local cts="$1" base="$2"
  [ -z "$cts" ] || [ -z "$base" ] || [ "$base" -le 0 ] 2>/dev/null && return 1
  if [ "$((2 * cts))" -gt "$((3 * base))" ]; then return 0; fi
  if [ "$((2 * cts))" -lt "$base" ]; then return 0; fi
  return 1
}

[ -r "$HDMI_PKT" ] || {
  log_event "FATAL: $HDMI_PKT missing; exiting"
  exit 1
}

log_event "cts monitor started (poll=${POLL_SLOW}s confirm=${CONFIRM_SAMPLES}, telemetry only)"

current_mode=""
current_hdr=""
baseline=""
mode_stable_since=0
shift_count=0
shift_vals=""

while :; do
  get_mode
  get_hdr
  new_mode="$MODE"
  new_hdr="$HDR"

  if [ "$new_mode" != "$current_mode" ] || [ "$new_hdr" != "$current_hdr" ]; then
    current_mode="$new_mode"
    current_hdr="$new_hdr"
    baseline=""
    mode_stable_since=$(date +%s)
    shift_count=0
    shift_vals=""
    log_event "mode change: ${new_mode} / ${new_hdr}"
    sleep $POLL_SLOW
    continue
  fi

  now=$(date +%s)
  stable_for=$((now - mode_stable_since))

  if [ -z "$baseline" ]; then
    if [ "$stable_for" -lt "$BASELINE_WAIT" ]; then
      sleep $POLL_SLOW
      continue
    fi
    if ! video_active; then
      sleep $POLL_SLOW
      continue
    fi
    baseline="$(capture_baseline)"
    if [ -z "$baseline" ] || [ "$baseline" -le 0 ] 2>/dev/null; then
      log_event "baseline capture failed; retrying"
      baseline=""
      sleep $POLL_SLOW
      continue
    fi
    log_event "baseline: mode=${current_mode} hdr=${current_hdr} cts=${baseline}"
    continue
  fi

  if ! video_active; then
    shift_count=0
    shift_vals=""
    sleep $POLL_SLOW
    continue
  fi

  get_cts
  cts="$CTS"
  [ -z "$cts" ] && { sleep $POLL_SLOW; continue; }

  if deviated "$cts" "$baseline"; then
    shift_count=$((shift_count + 1))
    shift_vals="$shift_vals$cts
"
    log_event "cts shift candidate (${shift_count}/${CONFIRM_SAMPLES}) cts=${cts} baseline=${baseline}"

    if [ "$shift_count" -ge "$CONFIRM_SAMPLES" ]; then
      new_baseline="$(median_of "$shift_vals" "$CONFIRM_SAMPLES")"
      log_event "cts rebaselined: ${baseline} -> ${new_baseline} mode=${current_mode} hdr=${current_hdr}"
      baseline="$new_baseline"
      shift_count=0
      shift_vals=""
      sleep $POLL_SLOW
      continue
    fi

    sleep $POLL_FAST
    continue
  fi

  shift_count=0
  shift_vals=""
  sleep $POLL_SLOW
done
