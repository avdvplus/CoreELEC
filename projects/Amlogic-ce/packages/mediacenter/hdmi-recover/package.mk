# SPDX-License-Identifier: GPL-2.0-or-later

PKG_NAME="hdmi-recover"
PKG_VERSION="0"
PKG_LICENSE="GPL"
PKG_SITE=""
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="HDMI link telemetry (CTS monitor, no wire writes) + manual PHY-cycle recovery tool"
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin
  cp ${PKG_DIR}/scripts/hdmi-phy-cycle.sh ${INSTALL}/usr/bin/hdmi-phy-cycle
  cp ${PKG_DIR}/scripts/hdmi-recover.sh ${INSTALL}/usr/bin/hdmi-recover
  cp ${PKG_DIR}/scripts/hdmi-watchdog.sh ${INSTALL}/usr/bin/hdmi-watchdog
  cp ${PKG_DIR}/scripts/hdmi-state-dump.sh ${INSTALL}/usr/bin/hdmi-state-dump
  chmod +x \
    ${INSTALL}/usr/bin/hdmi-phy-cycle \
    ${INSTALL}/usr/bin/hdmi-recover \
    ${INSTALL}/usr/bin/hdmi-watchdog \
    ${INSTALL}/usr/bin/hdmi-state-dump

  mkdir -p ${INSTALL}/usr/share/kodi/system/keymaps
  cp ${PKG_DIR}/keymaps/hdmi-recover.xml ${INSTALL}/usr/share/kodi/system/keymaps/

  mkdir -p ${INSTALL}/usr/config
  cp ${PKG_DIR}/config/hdmi-watchdog.enable.sample ${INSTALL}/usr/config/
}

post_install() {
  enable_service hdmi-watchdog.service
}
