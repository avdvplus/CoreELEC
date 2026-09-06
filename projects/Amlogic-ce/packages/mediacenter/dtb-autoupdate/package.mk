# SPDX-License-Identifier: GPL-2.0-or-later

PKG_NAME="dtb-autoupdate"
PKG_VERSION="0"
PKG_LICENSE="GPL"
PKG_SITE=""
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="Refreshes /flash/dtb.img from the running build's device_trees by coreelec-dt-id so device-tree fixes reach existing installs; opt-out via ENABLE=no in /storage/.config/dtb-autoupdate.conf"
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  cp ${PKG_DIR}/scripts/dtb-autoupdate.sh ${INSTALL}/usr/bin/dtb-autoupdate
  chmod +x ${INSTALL}/usr/bin/dtb-autoupdate
}

post_install() {
  enable_service dtb-autoupdate.service
}
