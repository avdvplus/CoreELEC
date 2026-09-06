# SPDX-License-Identifier: GPL-2.0-or-later

PKG_NAME="jre-zulu-fix"
PKG_VERSION="1"
PKG_LICENSE="GPL"
PKG_SITE=""
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain jre-libbluray"
PKG_LONGDESC="Runtime self-heal for the tools.jre.zulu BD-J Java runtime addon packaging layout + permissions + JAR sync"
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/lib/coreelec
  cp ${PKG_DIR}/scripts/jre-zulu-fix.sh ${INSTALL}/usr/lib/coreelec/jre-zulu-fix.sh
  chmod +x ${INSTALL}/usr/lib/coreelec/jre-zulu-fix.sh

  mkdir -p ${INSTALL}/usr/share/coreelec/bdj
  cp $(get_install_dir jre-libbluray)/usr/share/java/*.jar ${INSTALL}/usr/share/coreelec/bdj/

  mkdir -p ${INSTALL}/usr/share/kodi/system/keymaps
  cp ${PKG_DIR}/keymaps/bd-j-exit.xml ${INSTALL}/usr/share/kodi/system/keymaps/
}

post_install() {
  enable_service jre-zulu-fix.service
}
