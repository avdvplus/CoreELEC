# SPDX-License-Identifier: GPL-2.0-or-later

PKG_NAME="kodi-data-ram"
PKG_VERSION=""
PKG_LICENSE="GPL"
PKG_SITE=""
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain"
PKG_SHORTDESC="Pin Kodi's hot data in a RAM tmpfs to bypass a slow SD card"
PKG_LONGDESC="${PKG_SHORTDESC}"
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/lib/coreelec
    cp ${PKG_DIR}/scripts/kodi-data-ram-up.sh    ${INSTALL}/usr/lib/coreelec/
    cp ${PKG_DIR}/scripts/kodi-data-ram-sync.sh  ${INSTALL}/usr/lib/coreelec/
    cp ${PKG_DIR}/scripts/kodi-data-ram-down.sh  ${INSTALL}/usr/lib/coreelec/
    cp ${PKG_DIR}/scripts/kodi-data-ram-watch.sh ${INSTALL}/usr/lib/coreelec/
    chmod 0755 ${INSTALL}/usr/lib/coreelec/kodi-data-ram-up.sh
    chmod 0755 ${INSTALL}/usr/lib/coreelec/kodi-data-ram-sync.sh
    chmod 0755 ${INSTALL}/usr/lib/coreelec/kodi-data-ram-down.sh
    chmod 0755 ${INSTALL}/usr/lib/coreelec/kodi-data-ram-watch.sh

  mkdir -p ${INSTALL}/usr/lib/systemd/system
    cp ${PKG_DIR}/system.d/kodi-data-ram-setup.service ${INSTALL}/usr/lib/systemd/system/
    cp ${PKG_DIR}/system.d/kodi-data-ram-sync.service  ${INSTALL}/usr/lib/systemd/system/
    cp ${PKG_DIR}/system.d/kodi-data-ram-sync.timer    ${INSTALL}/usr/lib/systemd/system/
    cp ${PKG_DIR}/system.d/kodi-data-ram-watch.service ${INSTALL}/usr/lib/systemd/system/

  mkdir -p ${INSTALL}/etc
    cp ${PKG_DIR}/config/kodi-data-ram.conf ${INSTALL}/etc/

  mkdir -p ${INSTALL}/usr/config
    cp ${PKG_DIR}/config/kodi-data-ram.conf.sample ${INSTALL}/usr/config/
}

post_install() {
  enable_service kodi-data-ram-setup.service
  enable_service kodi-data-ram-sync.timer
  enable_service kodi-data-ram-watch.service
}
