# SPDX-License-Identifier: GPL-2.0-or-later

PKG_NAME="dovi5-prepare"
PKG_VERSION="0"
PKG_LICENSE="GPL"
PKG_SITE=""
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain Python3"
PKG_SHORTDESC="Prepare a patched Dolby Vision dovi5.ko from a user-supplied blob"
PKG_LONGDESC="The 5.15 Dolby Vision blob is not shipped. The user puts an unpatched dovi5.ko in any of /storage/.config, /flash or /storage. Each boot this validates it against the running kernel and the dv_compat_shim exports and writes a patched copy to /storage/.dovi5/dovi5.ko, which is the only module the loader will insmod. The user's file is never modified and /flash is never written; opt-out via ENABLE=no in /storage/.config/dovi5.conf"
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/lib/coreelec
    cp ${PKG_DIR}/scripts/dovi5-prepare      ${INSTALL}/usr/lib/coreelec/
    cp ${PKG_DIR}/scripts/dovi5-notify       ${INSTALL}/usr/lib/coreelec/
    cp ${PKG_DIR}/scripts/dv5-patch-dovi.py  ${INSTALL}/usr/lib/coreelec/
    chmod 0755 ${INSTALL}/usr/lib/coreelec/dovi5-prepare
    chmod 0755 ${INSTALL}/usr/lib/coreelec/dovi5-notify
    chmod 0755 ${INSTALL}/usr/lib/coreelec/dv5-patch-dovi.py

  mkdir -p ${INSTALL}/usr/lib/systemd/system
    cp ${PKG_DIR}/system.d/dovi5-prepare.service ${INSTALL}/usr/lib/systemd/system/
    cp ${PKG_DIR}/system.d/dovi5-notify.service  ${INSTALL}/usr/lib/systemd/system/
    cp ${PKG_DIR}/system.d/dovi5-notify.timer    ${INSTALL}/usr/lib/systemd/system/

  mkdir -p ${INSTALL}/etc
    cp ${PKG_DIR}/config/dovi5.conf ${INSTALL}/etc/

  mkdir -p ${INSTALL}/usr/config
    cp ${PKG_DIR}/config/dovi5.conf.sample ${INSTALL}/usr/config/
}

post_install() {
  enable_service dovi5-prepare.service
  enable_service dovi5-notify.timer
}
