# SPDX-License-Identifier: GPL-2.0-or-later

PKG_NAME="kodi-fs-maintain"
PKG_VERSION="0"
PKG_LICENSE="GPL"
PKG_SITE=""
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="Post-update filesystem maintenance: vacuums the Kodi SQLite databases and defragments userdata before Kodi starts on the first boot of a new build, then attempts fstrim; keeps flash media healthy on installs without working discard"
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  cp ${PKG_DIR}/scripts/kodi-fs-maintain.sh ${INSTALL}/usr/bin/kodi-fs-maintain
  chmod +x ${INSTALL}/usr/bin/kodi-fs-maintain
}

post_install() {
  enable_service kodi-fs-maintain-boot.service
}
