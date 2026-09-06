#!/bin/sh
ENABLE=yes
[ -r /storage/.config/dtb-autoupdate.conf ] && . /storage/.config/dtb-autoupdate.conf
[ "$ENABLE" = "yes" ] || exit 0
[ -f /proc/device-tree/coreelec-dt-id ] || exit 0
[ -f /flash/dtb.img ] || exit 0

DT_ID=$(tr -d '\0' < /proc/device-tree/coreelec-dt-id)
[ -f /usr/bin/convert_dtname ] && . /usr/bin/convert_dtname ${DT_ID}
NEW="/usr/share/bootloader/device_trees/${DT_ID}.dtb"
[ -f "${NEW}" ] || exit 0

new_sum=$(md5sum "${NEW}" | cut -d" " -f1)
cur_sum=$(md5sum /flash/dtb.img | cut -d" " -f1)
[ "${new_sum}" = "${cur_sum}" ] && exit 0

LOG=/storage/dtb-autoupdate.log
LOG_ROTATED=/storage/dtb-autoupdate.1.log
LOG_MAX_BYTES=262144

rotate_log() {
  if [ -f "$LOG" ]; then
    size=$(wc -c < "$LOG" 2>/dev/null) || size=""
    if [ -n "$size" ] && [ "$size" -gt "$LOG_MAX_BYTES" ] 2>/dev/null; then
      mv -f "$LOG" "$LOG_ROTATED" 2>/dev/null || true
    fi
  fi
  return 0
}

rotate_log
TS=$(date '+%Y-%m-%d %H:%M:%S')
BK="/storage/dtb.img.backup-$(date +%Y%m%d%H%M%S)"
cp /flash/dtb.img "${BK}" || exit 1
mount -o remount,rw /flash || exit 1
if cp "${NEW}" /flash/dtb.img; then
  sync
  echo "${TS} replaced dtb.img with ${DT_ID}.dtb (old ${cur_sum} new ${new_sum} backup ${BK})" >> ${LOG}
else
  cp "${BK}" /flash/dtb.img
  sync
  echo "${TS} FAILED replacing dtb.img with ${DT_ID}.dtb, backup restored" >> ${LOG}
fi
mount -o remount,ro /flash

for f in $(ls -t /storage/dtb.img.backup-* 2>/dev/null | tail -n +4); do
  rm -f "${f}"
done
