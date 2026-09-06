#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later

[ -r /etc/kodi-data-ram.conf ] && . /etc/kodi-data-ram.conf
[ -r /storage/.config/kodi-data-ram.conf ] && . /storage/.config/kodi-data-ram.conf

: "${KDR_ENABLE:=0}"
: "${KDR_RAM_RW:=/run/kodi-data-rw}"
: "${KDR_RAM_RO:=/run/kodi-data-ro}"
: "${KDR_PERSIST:=/storage/.kodi-data.persist}"
: "${KDR_KODI:=/storage/.kodi}"
: "${KDR_USERDATA:=/storage/.kodi/userdata}"
: "${KDR_GUISETTINGS:=/storage/.kodi/userdata/guisettings.xml}"
: "${KDR_CONFIG_FILES:=guisettings.xml sources.xml favourites.xml}"
: "${KDR_LOGSIZE_HINT:=/run/kodi-data-ram.logsize}"
: "${KDR_PIN_SKIN:=1}"
: "${KDR_PIN_PKC:=1}"
: "${KDR_PIN_JRE:=auto}"
: "${KDR_PIN_THUMBNAILS:=auto}"
: "${KDR_LOG:=/storage/kodi-data-ram.log}"
: "${KDR_SWAPPINESS:=100}"

log() {
  [ -f "$KDR_LOG" ] && [ "$(wc -c < "$KDR_LOG")" -gt 262144 ] 2>/dev/null && mv -f "$KDR_LOG" "${KDR_LOG}.1" 2>/dev/null
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$KDR_LOG" 2>/dev/null || true
}

if [ "$KDR_ENABLE" != "1" ]; then
  restore_dir() {
    tgt="$1"; name="$2"
    if mountpoint -q "$tgt" 2>/dev/null; then
      umount "$tgt" 2>/dev/null || return 0
    fi
    if [ -L "$tgt" ]; then
      target=$(readlink "$tgt")
      case "$target" in "$KDR_RAM_RW"/*) rm -f "$tgt" ;; *) return 0 ;; esac
    fi
    if [ ! -e "$tgt" ] || { [ -d "$tgt" ] && [ -z "$(ls -A "$tgt" 2>/dev/null)" ]; }; then
      [ -d "$KDR_PERSIST/$name" ] || return 0
      mkdir -p "$tgt"
      cp -a "$KDR_PERSIST/$name/." "$tgt/" 2>/dev/null \
        && log "disabled: restored $tgt from persist"
    fi
  }
  restore_dir "$KDR_USERDATA/Database" "Database"
  restore_dir "$KDR_USERDATA/addon_data" "addon_data"
  restore_dir "/storage/.cache/bluray" "bluray.cache"
  for a in "$KDR_KODI"/addons/*; do
    n=$(basename "$a")
    if [ -d "$KDR_PERSIST/$n" ] || [ -L "$a" ]; then
      restore_dir "$a" "$n"
    fi
  done
  for cf in $KDR_CONFIG_FILES; do
    link="$KDR_USERDATA/$cf"
    [ -L "$link" ] || continue
    target=$(readlink "$link")
    case "$target" in "$KDR_RAM_RW"/*) ;; *) continue ;; esac
    rm -f "$link"
    [ -f "$KDR_PERSIST/config/$cf" ] && cp -a "$KDR_PERSIST/config/$cf" "$link" 2>/dev/null \
      && log "disabled: restored $cf from persist"
  done
  exit 0
fi

if [ -L "$KDR_GUISETTINGS" ] && [ ! -e "$KDR_GUISETTINGS" ] && [ -f "$KDR_PERSIST/config/guisettings.xml" ]; then
  rm -f "$KDR_GUISETTINGS" && cp -a "$KDR_PERSIST/config/guisettings.xml" "$KDR_GUISETTINGS" 2>/dev/null \
    && log "healed dangling guisettings from persist"
fi

if [ -x /usr/lib/coreelec/skin-avdvplus-migration ] && [ -f "$KDR_GUISETTINGS" ]; then
  /usr/lib/coreelec/skin-avdvplus-migration 2>/dev/null || true
fi

ACTIVE_SKIN=""
if [ -f "$KDR_GUISETTINGS" ]; then
  ACTIVE_SKIN=$(sed -n 's:.*<setting id="lookandfeel.skin"[^>]*>\([^<]*\)</setting>.*:\1:p' "$KDR_GUISETTINGS" | head -1)
fi
[ -n "$ACTIVE_SKIN" ] || ACTIVE_SKIN="skin.avdvplus.estuary"

TOTAL_MB=$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)
if [ -n "$KDR_BUDGET_MB" ] && [ "$KDR_BUDGET_MB" != "0" ]; then
  BUDGET_MB="$KDR_BUDGET_MB"
else
  BUDGET_MB=$((TOTAL_MB / 6))
  [ "$BUDGET_MB" -gt 700 ] && BUDGET_MB=700
fi
USED_MB=0

dir_mb() { du -sm "$1" 2>/dev/null | cut -f1; }
add_used() { v=${1:-0}; case "$v" in (*[!0-9]*|"") v=0;; esac; USED_MB=$((USED_MB + v)); }
fits() { w=${1:-0}; case "$w" in (*[!0-9]*|"") w=0;; esac; [ $((USED_MB + w)) -le "$BUDGET_MB" ]; }

[ -n "$KDR_SWAPPINESS" ] && sysctl -qw vm.swappiness="$KDR_SWAPPINESS" 2>/dev/null
mkdir -p "$KDR_RAM_RW" "$KDR_RAM_RO" "$KDR_PERSIST"
mountpoint -q "$KDR_RAM_RW" || mount -t tmpfs -o mode=755,nosuid,nodev,size="${BUDGET_MB}m" tmpfs "$KDR_RAM_RW" || exit 1
mountpoint -q "$KDR_RAM_RO" || mount -t tmpfs -o mode=755,nosuid,nodev,size="${BUDGET_MB}m" tmpfs "$KDR_RAM_RO" || exit 1

pin_rw() {
  live="$1"; name="$2"
  persist="$KDR_PERSIST/$name"; ram="$KDR_RAM_RW/$name"
  if [ ! -d "$(dirname "$live")" ]; then
    log "rw pin $name: $(dirname "$live") absent, skipped (clean install -- pins next boot)"
    return 0
  fi
  mountpoint -q "$live" && return 0
  mkdir -p "$persist" "$ram"
  if [ -L "$live" ]; then
    rm -f "$live"
  elif [ -d "$live" ] && [ -n "$(ls -A "$live" 2>/dev/null)" ]; then
    if [ -z "$(ls -A "$persist" 2>/dev/null)" ]; then
      if ! cp -a "$live/." "$persist/" 2>/dev/null || [ -z "$(ls -A "$persist" 2>/dev/null)" ]; then
        log "rw pin $name: persist copy failed, leaving on SD"
        return 0
      fi
    else
      rm -rf "$KDR_PERSIST/.stale-$name" 2>/dev/null
      mv "$persist" "$KDR_PERSIST/.stale-$name" 2>/dev/null
      mkdir -p "$persist"
      if ! cp -a "$live/." "$persist/" 2>/dev/null || [ -z "$(ls -A "$persist" 2>/dev/null)" ]; then
        rm -rf "$persist" 2>/dev/null
        mv "$KDR_PERSIST/.stale-$name" "$persist" 2>/dev/null
        log "rw pin $name: refresh from storage failed, leaving on SD"
        return 0
      fi
      rm -rf "$KDR_PERSIST/.stale-$name" 2>/dev/null
      log "rw pin $name: storage copy is authoritative, persist refreshed"
    fi
    rm -rf "$live"
  elif [ -e "$live" ] && [ ! -d "$live" ]; then
    log "rw pin $name: $live is an unexpected non-dir, leaving as-is"
    return 0
  fi
  mkdir -p "$live"
  if ! cp -a "$persist/." "$ram/" 2>/dev/null; then
    rm -rf "$ram"
    mkdir -p "$ram"
    cp -a "$persist/." "$live/" 2>/dev/null || true
    log "rw pin $name: ram copy failed, running from storage"
    return 0
  fi
  if mount --bind "$ram" "$live" 2>/dev/null; then
    sz=$(dir_mb "$ram"); add_used "$sz"
    touch "/run/kodi-data-ram.complete-$name" 2>/dev/null || true
    log "rw pin $name (${sz:-0}MB) bind-mounted"
  else
    cp -a "$persist/." "$live/" 2>/dev/null || true
    log "rw pin $name: bind failed, running from storage"
  fi
}

pin_rw_file() {
  live="$1"; fname=$(basename "$live")
  persist="$KDR_PERSIST/config/$fname"
  mkdir -p "$KDR_PERSIST/config"
  if [ -L "$live" ]; then
    target=$(readlink "$live")
    case "$target" in
      "$KDR_RAM_RW"/*) rm -f "$live" ;;
      *) return 0 ;;
    esac
  fi
  if [ -f "$live" ]; then
    cmp -s "$live" "$persist" 2>/dev/null || cp -a "$live" "$persist" 2>/dev/null \
      || log "config $fname: persist backup failed"
  elif [ -f "$persist" ]; then
    cp -a "$persist" "$live" 2>/dev/null && log "config $fname healed from persist"
  fi
}

pin_ro() {
  live="$1"; name="$2"
  [ -e "$live" ] || { log "ro pin $name skipped (missing)"; return 0; }
  mountpoint -q "$live" && return 0
  sz=$(dir_mb "$live")
  if ! fits "$sz"; then
    log "ro pin $name skipped (${sz:-0}MB over budget used=${USED_MB}/${BUDGET_MB})"
    return 0
  fi
  ram="$KDR_RAM_RO/$name"; mkdir -p "$ram"
  if cp -a "$live/." "$ram/" 2>/dev/null && mount --bind "$ram" "$live" 2>/dev/null; then
    add_used "$sz"
    log "ro pin $name (${sz:-0}MB) bind-mounted"
  else
    log "ro pin $name failed (copy or bind)"
  fi
}

pin_rw_addon() {
  live="$1"; name="$2"
  [ -e "$live" ] || [ -L "$live" ] || { log "rw-addon pin $name skipped (missing)"; return 0; }
  if [ -L "$live" ] && [ ! -e "$live" ]; then
    sz=$(dir_mb "$KDR_PERSIST/$name")
  elif [ -d "$live" ] && [ -z "$(ls -A "$live" 2>/dev/null)" ] && [ -d "$KDR_PERSIST/$name" ]; then
    sz=$(dir_mb "$KDR_PERSIST/$name")
  else
    sz=$(dir_mb "$live")
  fi
  if ! fits "$sz"; then
    log "rw-addon pin $name skipped (${sz:-0}MB over budget used=${USED_MB}/${BUDGET_MB})"
    ensure_on_disk "$live" "$name"
    return 0
  fi
  pin_rw "$live" "$name"
}

ensure_on_disk() {
  live="$1"; name="$2"
  persist="$KDR_PERSIST/$name"
  mountpoint -q "$live" 2>/dev/null && return 0
  if [ -L "$live" ] && [ ! -e "$live" ]; then
    case "$(readlink "$live")" in "$KDR_RAM_RW"/*) rm -f "$live" ;; esac
  fi
  [ -d "$persist" ] && [ -n "$(ls -A "$persist" 2>/dev/null)" ] || return 0
  if [ ! -e "$live" ] || { [ -d "$live" ] && [ -z "$(ls -A "$live" 2>/dev/null)" ]; }; then
    mkdir -p "$live"
    cp -a "$persist/." "$live/" 2>/dev/null \
      && log "$name restored to storage from persist"
  fi
}

pin_rw_gated() {
  live="$1"; name="$2"
  if [ -d "$live" ] && [ -n "$(ls -A "$live" 2>/dev/null)" ] && ! mountpoint -q "$live"; then
    sz=$(dir_mb "$live")
  elif [ -d "$KDR_PERSIST/$name" ]; then
    sz=$(dir_mb "$KDR_PERSIST/$name")
  else
    sz=0
  fi
  if ! fits "$sz"; then
    log "rw pin $name skipped (${sz:-0}MB over budget used=${USED_MB}/${BUDGET_MB})"
    ensure_on_disk "$live" "$name"
    return 0
  fi
  pin_rw "$live" "$name"
}

pin_rw_gated "$KDR_USERDATA/Database" "Database"
pin_rw_gated "$KDR_USERDATA/addon_data" "addon_data"

for cf in $KDR_CONFIG_FILES; do
  pin_rw_file "$KDR_USERDATA/$cf"
done

if [ "$KDR_PIN_SKIN" = "1" ]; then
  if [ -d "/usr/share/kodi/addons/$ACTIVE_SKIN" ]; then
    pin_ro "/usr/share/kodi/addons/$ACTIVE_SKIN" "skin"
  elif [ -d "$KDR_KODI/addons/$ACTIVE_SKIN" ]; then
    if [ -d "$KDR_PERSIST/skin" ] && [ ! -d "$KDR_PERSIST/$ACTIVE_SKIN" ]; then
      mv "$KDR_PERSIST/skin" "$KDR_PERSIST/$ACTIVE_SKIN" 2>/dev/null || true
    fi
    pin_rw_addon "$KDR_KODI/addons/$ACTIVE_SKIN" "$ACTIVE_SKIN"
  fi
fi

if [ "$KDR_PIN_PKC" = "1" ]; then
  for a in plugin.video.plexkodiconnect plugin.video.plexkodiconnect.movies plugin.video.plexkodiconnect.tvshows; do
    pin_rw_addon "$KDR_KODI/addons/$a" "$a"
  done
fi

if [ "$KDR_PIN_JRE" = "1" ] || { [ "$KDR_PIN_JRE" = "auto" ] && [ "$TOTAL_MB" -ge 1500 ]; }; then
  pin_ro "$KDR_KODI/addons/tools.jre.zulu" "tools.jre.zulu"
  pin_rw_gated "/storage/.cache/bluray" "bluray.cache"
fi

if [ "$KDR_PIN_THUMBNAILS" = "1" ] || { [ "$KDR_PIN_THUMBNAILS" = "auto" ] && [ "$TOTAL_MB" -ge 3000 ]; }; then
  th="$KDR_USERDATA/Thumbnails"
  if [ -d "$th" ] && ! mountpoint -q "$th"; then
    mkdir -p "$KDR_RAM_RO/Thumbnails.over" "$KDR_RAM_RO/Thumbnails.work"
    mount -t overlay overlay -o lowerdir="$th",upperdir="$KDR_RAM_RO/Thumbnails.over",workdir="$KDR_RAM_RO/Thumbnails.work" "$th" 2>/dev/null \
      && log "thumbnails overlay mounted" || log "thumbnails overlay failed"
  fi
fi

REMAIN_MB=$((BUDGET_MB - USED_MB))
LOG_MB=$((TOTAL_MB / 8))
[ "$LOG_MB" -gt 512 ] && LOG_MB=512
[ "$LOG_MB" -lt 96 ] && LOG_MB=96
echo "$LOG_MB" > "$KDR_LOGSIZE_HINT" 2>/dev/null || true
log "budget=${BUDGET_MB}MB used=${USED_MB}MB remain=${REMAIN_MB}MB skin=${ACTIVE_SKIN}"

exit 0
