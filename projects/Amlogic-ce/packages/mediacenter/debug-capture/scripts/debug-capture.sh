#!/bin/sh
CAPTURE=@CAPTURE_DEFAULT@
DEBUG_SET="/sys/module/hdmitx20/parameters/hdmi_sinkprobe_ms 1
/sys/module/amdolby_vision/parameters/debug_dolby 2"
DEBUG_DYNDBG="file hw_g12a.c +p
file hw_sc2.c +p"
MIRROR="/storage/init-previous.log
/storage/skin-avdvplus-migration.log
/storage/kodi-data-ram.log
/storage/update-bl301.log
/storage/dtb-autoupdate.log
/storage/dtb-autoupdate.1.log
/storage/skin-avdvplus-migration.1.log
/storage/kodi-data-ram.log.1
/storage/dovi5.log
/storage/dovi5.1.log"
CONF=/storage/.config/debug-capture.conf
LOGDIR=/storage/.kodi/temp
LOG=$LOGDIR/kernel.log
MAX=5242880
KEEP=4
DONE_SET=""
DONE_DYN=""
NL='
'

CONF_CAPTURE=""
if [ -f "$CONF" ] && [ -r "$CONF" ]; then
  CONF_CAPTURE=$(sed -n 's/^[[:space:]]*CAPTURE[[:space:]]*=[[:space:]]*"\{0,1\}'"'"'\{0,1\}\([A-Za-z]*\).*/\1/p' "$CONF" 2>/dev/null | tail -1)
fi
if [ -n "$CONF_CAPTURE" ] && [ "$CONF_CAPTURE" != "@CAPTURE_DEFAULT@" ]; then
  echo "debug-capture: this build sets CAPTURE=@CAPTURE_DEFAULT@; ignoring CAPTURE=${CONF_CAPTURE} from ${CONF}" >&2
fi
CAPTURE=@CAPTURE_DEFAULT@
if [ "$CAPTURE" = "yes" ]; then
  echo "debug-capture: capture ON (test build)" >&2
else
  echo "debug-capture: capture OFF (public build)" >&2
fi
[ "$CAPTURE" = "yes" ] || exit 0

rotate() {
  i=$KEEP
  while [ "$i" -gt 1 ]; do
    j=$((i-1))
    [ -f "$LOGDIR/kernel.$j.log" ] && mv -f "$LOGDIR/kernel.$j.log" "$LOGDIR/kernel.$i.log"
    i=$j
  done
  [ -f "$LOG" ] && mv -f "$LOG" "$LOGDIR/kernel.1.log"
  : > "$LOG"
}

apply_debug() {
  OIFS=$IFS
  IFS=$NL
  for line in $DEBUG_SET; do
    IFS=$OIFS
    case "$DONE_SET" in
      *"|$line|"*) ;;
      *)
        set -- $line
        if [ -n "$2" ] && [ -w "$1" ]; then
          p=$1
          shift
          if echo "$*" > "$p" 2>/dev/null; then
            DONE_SET="$DONE_SET|$line|"
          fi
        fi
        ;;
    esac
    IFS=$NL
  done
  for line in $DEBUG_DYNDBG; do
    case "$DONE_DYN" in
      *"|$line|"*) ;;
      *)
        if [ -w /sys/kernel/debug/dynamic_debug/control ] &&
           echo "$line" > /sys/kernel/debug/dynamic_debug/control 2>/dev/null; then
          DONE_DYN="$DONE_DYN|$line|"
        fi
        ;;
    esac
  done
  IFS=$OIFS
}

mirror_logs() {
  OIFS=$IFS
  IFS=$NL
  for src in $MIRROR; do
    IFS=$OIFS
    if [ -f "$src" ] && [ ! -L "$src" ]; then
      b=$(basename "$src")
      dst="$LOGDIR/${b%.log}.mirror.log"
      if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ]; then
        cp -a "$src" "$dst" 2>/dev/null
      fi
    fi
    IFS=$NL
  done
  IFS=$OIFS
}

mkdir -p "$LOGDIR"
rotate
apply_debug
mirror_logs
dmesg -c >> "$LOG"
sync -d "$LOG"

while :; do
  sleep 2
  apply_debug
  mirror_logs
  S1=$(wc -c < "$LOG")
  dmesg -c >> "$LOG"
  S2=$(wc -c < "$LOG")
  if [ "$S2" -ne "$S1" ]; then
    sync -d "$LOG"
    if [ "$S2" -gt "$MAX" ]; then
      rotate
    fi
  fi
done
