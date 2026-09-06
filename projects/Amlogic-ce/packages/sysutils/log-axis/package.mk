# SPDX-License-Identifier: GPL-2.0-or-later

PKG_NAME="log-axis"
PKG_VERSION="1.0"
PKG_LICENSE="GPL"
PKG_SITE=""
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="Sub-axis kernel diagnostic recipe tool — bundles dynamic_debug + module_param + console_loglevel for the 5 named axes (decode/dv/display/audio/sync). Companion to Phase 1.7+2 default-state silencing and Phase 3 KT-pattern bit-gate volume protection."
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  install -m 0755 ${PKG_DIR}/scripts/log-axis ${INSTALL}/usr/bin/log-axis
}
