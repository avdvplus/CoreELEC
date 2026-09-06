# SPDX-License-Identifier: GPL-2.0

PKG_NAME="kodi-addon-sidedata"
PKG_VERSION="1.6.0"
PKG_SHA256="e479f2b21f5ab68f715af48581ffbe0480d49d2732d1e572ce8b3c5c5abd0d24"
PKG_LICENSE="GPL-2.0-or-later"
PKG_SITE="https://github.com/matthane/script.module.sidedata"
PKG_URL="https://github.com/matthane/script.module.sidedata/archive/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain libdovi"
PKG_LONGDESC="Parsers for the raw DV/HDR payloads published through Player.Process(video.sidedata)."
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/share/kodi/addons/script.module.sidedata
  cp -PR * ${INSTALL}/usr/share/kodi/addons/script.module.sidedata/
}
