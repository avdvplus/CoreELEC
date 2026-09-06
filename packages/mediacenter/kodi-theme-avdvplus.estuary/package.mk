PKG_NAME="kodi-theme-avdvplus.estuary"
PKG_VERSION="e0a564b01014e80b4c9298ece7ec50809cc72faa"
PKG_SHA256="f09e1b8702c831877ce542f94c8ca90ad93c1e0c70a9a1e8c61fc766988dc81c"
PKG_LICENSE="GPL"
PKG_SITE="https://github.com/avdvplus/skin.avdvplus.estuary"
PKG_URL="https://github.com/avdvplus/skin.avdvplus.estuary/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="avdvplus.Estuary: Customised fork of Kodi's Estuary skin with stream-select dialog enrichment from Kodi 22 (xbmc/xbmc PR #25762)."
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/share/kodi/addons/skin.avdvplus.estuary
  cp -PR * ${INSTALL}/usr/share/kodi/addons/skin.avdvplus.estuary/
  rm -rf ${INSTALL}/usr/share/kodi/addons/skin.avdvplus.estuary/scripts
  mkdir -p ${INSTALL}/usr/lib/coreelec
  cp ${PKG_DIR}/scripts/skin-avdvplus-migration ${INSTALL}/usr/lib/coreelec/
  chmod 755 ${INSTALL}/usr/lib/coreelec/skin-avdvplus-migration
}

pre_install() {
  if [ ! -f "${PKG_INSTALL}/usr/share/kodi/addons/skin.avdvplus.estuary/addon.xml" ]; then
    echo "ERROR: ${PKG_NAME} install_pkg is missing or incomplete at ${PKG_INSTALL}" >&2
    echo "       wiping build stamp to force full rebuild on next invocation" >&2
    rm -f "${STAMPS}/${PKG_NAME}/build_target"
    return 1
  fi
}
