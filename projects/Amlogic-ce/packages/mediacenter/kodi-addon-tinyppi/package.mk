# SPDX-License-Identifier: GPL-2.0

PKG_NAME="kodi-addon-tinyppi"
PKG_VERSION="fc325e7ce339f64c68e70cfd13cf0303aeae6c39"
PKG_SHA256="903c3be4bcf44ff92b4c8813768b9eab21877d1e4efeeab986cdaebb532b7473"
PKG_LICENSE="MIT"
PKG_SITE="https://github.com/CE-Repo/script.tinyppi"
PKG_URL="https://github.com/CE-Repo/script.tinyppi/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain kodi-addon-sidedata"
PKG_LONGDESC="TinyPPI: player process information overlay."
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/share/kodi/addons/script.tinyppi
  cp -PR * ${INSTALL}/usr/share/kodi/addons/script.tinyppi/
}
