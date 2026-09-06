# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2018-present Team CoreELEC (https://coreelec.org)

PKG_NAME="CoreELEC-settings"
PKG_VERSION="533453227da6930d7f192788c602a6a14553defa"
PKG_SHA256="30556fbfc3083ca9004e985b1ea95ce1fd83576f7ff306adbfbb269b9d4ca947"
PKG_LICENSE="GPL"
PKG_SITE="https://coreelec.org"
PKG_URL="https://github.com/avdvplus/service.coreelec.settings/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain Python3 connman dbussy"
PKG_LONGDESC="CoreELEC-settings: is a settings dialog for CoreELEC"

PKG_MAKE_OPTS_TARGET="DISTRONAME=${DISTRONAME} ADDON_VERSION=${ADDON_VERSION} ROOT_PASSWORD=${ROOT_PASSWORD}"

if [ "${DISPLAYSERVER}" = "x11" ]; then
  PKG_DEPENDS_TARGET="${PKG_DEPENDS_TARGET} setxkbmap"
else
  PKG_DEPENDS_TARGET="${PKG_DEPENDS_TARGET} bkeymaps"
fi

post_makeinstall_target() {
  mkdir -p ${INSTALL}/usr/lib/coreelec
    cp ${PKG_DIR}/scripts/* ${INSTALL}/usr/lib/coreelec

  ADDON_INSTALL_DIR=${INSTALL}/usr/share/kodi/addons/service.coreelec.settings

  ${TOOLCHAIN}/bin/python -Wi -t -B ${TOOLCHAIN}/lib/${PKG_PYTHON_VERSION}/compileall.py ${ADDON_INSTALL_DIR}/resources/lib/ -f
  rm -rf $(find ${ADDON_INSTALL_DIR}/resources/lib/ -name "*.py")

  ${TOOLCHAIN}/bin/python -Wi -t -B ${TOOLCHAIN}/lib/${PKG_PYTHON_VERSION}/compileall.py ${ADDON_INSTALL_DIR}/oe.py -f
  rm -rf ${ADDON_INSTALL_DIR}/oe.py
}

post_install() {
  enable_service backup-restore.service
  enable_service factory-reset.service
}
