# SPDX-License-Identifier: GPL-2.0-or-later

PKG_NAME="debug-capture"
PKG_VERSION="0"
PKG_LICENSE="GPL"
PKG_SITE=""
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="Debug capture service: persists the kernel ring to /storage/.kodi/temp/kernel.log and arms configurable debug settings from /storage/.config/debug-capture.conf. Off unless the build sets DEBUG_CAPTURE=yes; the build value always overrides the on-device conf"
PKG_TOOLCHAIN="manual"

case "${DEBUG_CAPTURE:-no}" in
  yes|no) ;;
  *) die "debug-capture: DEBUG_CAPTURE must be 'yes' or 'no', got '${DEBUG_CAPTURE}'" ;;
esac

PKG_STAMP="DEBUG_CAPTURE=${DEBUG_CAPTURE:-no}"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  sed -e "s|@CAPTURE_DEFAULT@|${DEBUG_CAPTURE:-no}|g" \
    ${PKG_DIR}/scripts/debug-capture.sh > ${INSTALL}/usr/bin/debug-capture
  grep -q '@CAPTURE_DEFAULT@' ${INSTALL}/usr/bin/debug-capture &&
    die "debug-capture: @CAPTURE_DEFAULT@ was not substituted"
  chmod +x ${INSTALL}/usr/bin/debug-capture
}

post_install() {
  enable_service debug-capture.service
}
