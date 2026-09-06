# SPDX-License-Identifier: GPL-2.0-or-later

PKG_NAME="kodi-tmpfs-log"
PKG_VERSION=""
PKG_LICENSE="GPL"
PKG_SITE=""
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain"
PKG_SHORTDESC="Kodi temp/log on a RAM tmpfs to avoid SD-write playback stutter"
PKG_LONGDESC="${PKG_SHORTDESC}"
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/lib/coreelec
    cp ${PKG_DIR}/scripts/kodi-tmpfs-log-up.sh   ${INSTALL}/usr/lib/coreelec/
    cp ${PKG_DIR}/scripts/kodi-tmpfs-log-sync.sh ${INSTALL}/usr/lib/coreelec/
    cp ${PKG_DIR}/scripts/kodi-tmpfs-log-down.sh ${INSTALL}/usr/lib/coreelec/
    chmod 0755 ${INSTALL}/usr/lib/coreelec/kodi-tmpfs-log-up.sh
    chmod 0755 ${INSTALL}/usr/lib/coreelec/kodi-tmpfs-log-sync.sh
    chmod 0755 ${INSTALL}/usr/lib/coreelec/kodi-tmpfs-log-down.sh

  mkdir -p ${INSTALL}/usr/lib/systemd/system
    cp ${PKG_DIR}/system.d/kodi-tmpfs-log-setup.service ${INSTALL}/usr/lib/systemd/system/
    cp ${PKG_DIR}/system.d/kodi-tmpfs-log-sync.service  ${INSTALL}/usr/lib/systemd/system/
    cp ${PKG_DIR}/system.d/kodi-tmpfs-log-sync.timer    ${INSTALL}/usr/lib/systemd/system/

  mkdir -p ${INSTALL}/usr/lib/systemd/system/kodi.service.d
    cp ${PKG_DIR}/system.d/kodi.service.d/10-kodi-tmpfs-log.conf ${INSTALL}/usr/lib/systemd/system/kodi.service.d/

  mkdir -p ${INSTALL}/etc
    cp ${PKG_DIR}/config/kodi-tmpfs-log.conf ${INSTALL}/etc/

  mkdir -p ${INSTALL}/usr/config
    cp ${PKG_DIR}/config/kodi-tmpfs-log.conf.sample ${INSTALL}/usr/config/
}

post_install() {
  enable_service kodi-tmpfs-log-setup.service
  enable_service kodi-tmpfs-log-sync.timer
}
