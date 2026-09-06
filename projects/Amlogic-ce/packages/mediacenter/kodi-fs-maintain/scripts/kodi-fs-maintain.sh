#!/bin/sh

LOG=/storage/kodi-fs-maintain.log
STAMP=/storage/.kodi-fs-maintain.stamp
DBDIR=/storage/.kodi/userdata/Database
ADDONDATA=/storage/.kodi/userdata/addon_data
DEFRAG_PATHS="/storage/.kodi/userdata"
MODE="${1:-boot}"
[ -r /storage/.config/kodi-fs-maintain.conf ] && . /storage/.config/kodi-fs-maintain.conf
KDR_PERSIST=/storage/.kodi-data.persist
[ -r /etc/kodi-data-ram.conf ] && . /etc/kodi-data-ram.conf
[ -r /storage/.config/kodi-data-ram.conf ] && . /storage/.config/kodi-data-ram.conf
[ -d "$KDR_PERSIST" ] && DEFRAG_PATHS="$DEFRAG_PATHS $KDR_PERSIST"

[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 262144 ] && mv -f "$LOG" "$LOG.1"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

build_id() { sed -n 's/^BUILD_ID=//p' /etc/os-release | tr -d '"'; }

storage_is_ext4() { grep -q " /storage ext4 " /proc/mounts; }

speed_probe() {
  command -v python3 >/dev/null || { echo "write-speed probe unavailable (no python3)"; return; }
  python3 -c '
import os, time
p = "/storage/.kfm-probe"
buf = os.urandom(1048576)
t0 = time.time()
f = open(p, "wb")
for i in range(8):
    f.write(buf)
f.flush()
os.fsync(f.fileno())
f.close()
dt = time.time() - t0
os.unlink(p)
print("write-speed %.1f KB/s (8 MB fsync)" % (8192.0 / dt))'
}

score() {
  command -v filefrag >/dev/null && filefrag "$DBDIR"/*.db >> "$LOG" 2>&1
  if command -v e4defrag >/dev/null && storage_is_ext4; then
    for p in $DEFRAG_PATHS; do
      e4defrag -c "$p" 2>/dev/null | grep -aE "Fragmentation score|Average size" >> "$LOG"
    done
  fi
  log "$(speed_probe)"
}

vacuum_db() {
  db=$1
  [ -f "$db" ] || return 0
  n=${db#/storage/.kodi/userdata/}
  ic=$(sqlite3 "$db" "PRAGMA integrity_check;" 2>&1 | head -1)
  if [ "$ic" = "ok" ]; then
    sqlite3 "$db" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1
    if sqlite3 "$db" "VACUUM;" 2>>"$LOG"; then log "vacuum ok: $n"; else log "vacuum FAILED: $n"; fi
  else
    log "integrity NOT ok, vacuum skipped: $n: $ic"
  fi
}

full_pass() {
  log "=== maintenance start (build $(build_id), mode $MODE)"
  score
  was=$(systemctl is-active kodi 2>/dev/null)
  if [ "$was" = "active" ]; then
    systemctl stop kodi
    sleep 2
  fi
  if command -v sqlite3 >/dev/null; then
    for db in "$DBDIR"/*.db; do
      vacuum_db "$db"
    done
    find "$ADDONDATA" -type f -name '*.db' -print0 2>/dev/null | while IFS= read -r -d '' db; do
      vacuum_db "$db"
    done
  else
    log "sqlite3 unavailable, vacuum skipped"
  fi
  if command -v e4defrag >/dev/null && storage_is_ext4; then
    for p in $DEFRAG_PATHS; do
      e4defrag "$p" 2>&1 | grep -aE "Success|Failure" >> "$LOG"
    done
  else
    log "e4defrag unavailable or /storage not ext4, defrag skipped"
  fi
  if ! fstrim -v /storage >> "$LOG" 2>&1; then
    log "fstrim: discard not supported on this device"
  fi
  sync
  [ "$was" = "active" ] && systemctl start kodi
  echo "$(build_id) $(date +%s)" > "$STAMP"
  score
  log "=== maintenance done"
}

case "$MODE" in
  check)
    log "--- check (build $(build_id))"
    score
    tail -n 15 "$LOG"
    ;;
  boot)
    cur=$(build_id)
    if [ -r "$STAMP" ]; then
      read old_id old_ts < "$STAMP"
      [ "$old_id" = "$cur" ] && exit 0
      log "trigger: build changed $old_id -> $cur"
    else
      log "trigger: first boot run"
    fi
    full_pass
    ;;
  run)
    if grep -q "device name" /sys/class/vdec/vdec_status 2>/dev/null; then
      log "skipped: playback active"
      exit 0
    fi
    log "trigger: manual"
    full_pass
    ;;
esac
