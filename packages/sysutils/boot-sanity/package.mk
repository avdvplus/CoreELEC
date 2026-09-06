# SPDX-License-Identifier: GPL-2.0-or-later

PKG_NAME="boot-sanity"
PKG_VERSION=""
PKG_LICENSE="GPL"
PKG_SITE=""
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain"
PKG_SHORTDESC="Log storage and memory anomalies to the kernel ring buffer after boot"
PKG_LONGDESC="Log storage and memory anomalies to the kernel ring buffer after boot. Off unless /storage/.config/boot-sanity.enable exists"
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/lib/coreelec
    cp ${PKG_DIR}/scripts/boot-sanity.sh ${INSTALL}/usr/lib/coreelec/
    chmod 0755 ${INSTALL}/usr/lib/coreelec/boot-sanity.sh

  mkdir -p ${INSTALL}/usr/lib/systemd/system
    cp ${PKG_DIR}/system.d/boot-sanity.service ${INSTALL}/usr/lib/systemd/system/
    cp ${PKG_DIR}/system.d/boot-sanity.timer   ${INSTALL}/usr/lib/systemd/system/

  mkdir -p ${INSTALL}/usr/config
    cp ${PKG_DIR}/config/boot-sanity.enable.sample ${INSTALL}/usr/config/
}

post_install() {
  enable_service boot-sanity.timer
}
