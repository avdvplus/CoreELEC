#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2023-present Team CoreELEC (https://coreelec.org)

# get coreelec release information
source /etc/os-release

message() {
  >&2 echo "${@}"
}

# Return 1 if given kernel version is lower than current dovi.ko module version
check_dovi_version() {
    version_higher=$(modinfo $1 | awk '/vermagic:/ {split($2, ver, "-"); print ver[1]}' | awk -F '.' \
      -v ker_ver=$2 -v maj_ver=$3 -v min_ver=$4 '{
        if ($1 > ker_ver) { print "Y"; }
        else if ($1 < ker_ver) { print "N"; }
        else {
          if ($2 > maj_ver) { print "Y"; }
          else if ($2 < maj_ver) { print "N"; }
          else {
            if ($3 >= min_ver) { print "Y"; }
            else { print "N"; }
          }
        }
      }')

    if [ "$version_higher" = "Y" ]; then
      return 0
    else
      return 1
    fi
}

insmod_dovi_ne() {
  DOVI_KO=${1}
  if [ -f ${DOVI_KO} ]; then
    message "loading '${DOVI_KO}' module"
    modinfo ${DOVI_KO}
    if check_dovi_version ${DOVI_KO} 5 4 210; then
      insmod ${DOVI_KO} && return 0
    else
      cat > /tmp/dovi.message << 'EOF'
[TITLE]CoreELEC Dolby Vision Media Playback[/TITLE]
[B][COLOR red]Android Dolby Vision kernel module is not compatible[/COLOR][/B]
[COLOR red]No Dolby Vision media playback possible![/COLOR]

Please upgrade Android firmware of your device to minimum Linux kernel version '5.4.210'.
Dolby Vision media will be displayed in HDR instead Dolby Vision until the firmware fulfill the minimum requirements.
EOF
    fi
  fi

  return 1
}

load_dovi_ne() {
  # local dovi.ko
  insmod_dovi_ne /storage/.config/dovi.ko && return
  insmod_dovi_ne /flash/dovi.ko && return
  insmod_dovi_ne /storage/dovi.ko && return

  # Android 12
  if [ -b /dev/oem ]; then
    mountpoint -q /android/oem || mount -o ro /dev/oem /android/oem
    insmod_dovi_ne /android/oem/overlay/dovi.ko && return
  fi

  # Android 11
  # if mounted from tee-loader don't mount/unmount from dovi-loader
  if ! ls /dev/mapper/dynpart-* &>/dev/null; then
    dmsetup create --concise "$(parse-android-dynparts /dev/super)"
    systemctl set-environment dmsetup_remove=yes
  fi

  if [ -b /dev/mapper/dynpart-system_a ]; then
    active_slot="_a"
  elif [ -b /dev/mapper/dynpart-system_b ]; then
    active_slot="_b"
  else
    active_slot=""
  fi

  if [ -b /dev/mapper/dynpart-odm${active_slot} ]; then
    mountpoint -q /android/odm || mount -o ro /dev/mapper/dynpart-odm${active_slot} /android/odm
    insmod_dovi_ne /android/odm/lib/modules/dovi.ko && return
  fi

  cleanup_dovi_ne
}

cleanup_dovi_ne() {
  rmmod dovi 2>/dev/null
  mountpoint -q /android/odm && umount /android/odm
  mountpoint -q /android/oem && umount /android/oem
  # unmount only if mounted from this script
  [ "${dmsetup_remove}" = "yes" ] && \
    ls /dev/mapper/dynpart-* &>/dev/null && dmsetup remove /dev/mapper/dynpart-*
}

load_dovi_ng() {
  mountpoint -q /android/vendor || mount -o ro /dev/vendor /android/vendor

  for DOVI_KO in /storage/.config/dovi.ko \
                 /flash/dovi.ko \
                 /storage/dovi.ko \
                 /android/vendor/lib/modules/dovi.ko \
                 /android/vendor/lib/modules/dovi_vs10.ko \
                ; do
    if [ -f ${DOVI_KO} ]; then
      message "loading old dovi '${DOVI_KO}' module"
      modinfo ${DOVI_KO}
      insmod ${DOVI_KO} && break
    fi
  done

  DOVI5_KO=""
  if [ -s /run/dovi5-path ]; then
    read -r DOVI5_KO < /run/dovi5-path
  fi
  if [ -z "${DOVI5_KO}" ] || [ ! -f "${DOVI5_KO}" ]; then
    DOVI5_KO=""
  fi
  DOVI5_STAMP=/storage/.dovi5/state
  if [ -n "${DOVI5_KO}" ] && [ -f "${DOVI5_KO}" ]; then
    if [ ! -f "${DOVI5_STAMP}" ]; then
      message "refusing dovi5: no prepare stamp; '${DOVI5_KO}' was not produced by dovi5-prepare"
      DOVI5_KO=""
    else
      read -r _dv5s _dv5h DOVI5_WANT < "${DOVI5_STAMP}" 2>/dev/null
      DOVI5_HAVE=$(sha256sum "${DOVI5_KO}" 2>/dev/null | cut -d' ' -f1)
      if [ -z "${DOVI5_WANT}" ] || [ "${DOVI5_HAVE}" != "${DOVI5_WANT}" ]; then
        message "refusing dovi5: '${DOVI5_KO}' does not match the prepare stamp; it may be unpatched"
        DOVI5_KO=""
      fi
    fi
  fi
  DOVI5_REAL=$(readlink -f "${DOVI5_KO}" 2>/dev/null)
  if [ -n "${DOVI5_KO}" ] && [ "${DOVI5_KO}" != "/storage/.dovi5/dovi5.ko" ]; then
    message "refusing dovi5: '${DOVI5_KO}' is not the prepared module path"
    DOVI5_KO=""
  fi
  DOVI5_LINKS=$(stat -c %h "${DOVI5_KO}" 2>/dev/null || echo 0)
  if [ -n "${DOVI5_KO}" ] && [ -f "${DOVI5_KO}" ] && [ "${DOVI5_LINKS}" != "1" ]; then
    message "refusing dovi5: '${DOVI5_KO}' has ${DOVI5_LINKS} links; it may be the same file as your unpatched blob"
    DOVI5_KO=""
  fi
  if [ -n "${DOVI5_KO}" ] && [ -f "${DOVI5_KO}" ] && [ "${DOVI5_REAL}" = "${DOVI5_KO}" ]; then
    modinfo "${DOVI5_KO}"
    if insmod "${DOVI5_KO}"; then
      message "loaded new dovi5 '${DOVI5_KO}' module"
    else
      message "failed to load dovi5 '${DOVI5_KO}'; it may not match this kernel"
    fi
  elif [ -n "${DOVI5_KO}" ] && [ -e "${DOVI5_KO}" ]; then
    message "refusing dovi5: '${DOVI5_KO}' resolves to '${DOVI5_REAL}' outside the prepared module"
  else
    message "no prepared dovi5 module; new Dolby Vision blob not loaded"
  fi

  mountpoint -q /android/vendor && umount /android/vendor
}

cleanup_dovi_ng() {
  rmmod dovi5 2>/dev/null
  rmmod dovi 2>/dev/null
  mountpoint -q /android/vendor && umount /android/vendor
}

message "run dovi '${1}' for ${COREELEC_DEVICE:8:2}"

case "${1}" in
  start)
    modprobe dv_compat_shim 2>/dev/null
    load_dovi_${COREELEC_DEVICE:8:2}
    ;;
  stop)
    cleanup_dovi_${COREELEC_DEVICE:8:2}
    ;;
esac

exit 0
