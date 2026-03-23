# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2018-present Team CoreELEC (https://coreelec.org)

PKG_NAME="CoreELEC-settings"
PKG_VERSION="800ab3ea2d1cddf31d16f66d13dcaeb5f17720e5"
PKG_SHA256="a033a6ddec4ce56019a6bc886e4a66eb595ebc0d35ac8c6c1f6bace82ef31b51"
PKG_LICENSE="GPL"
PKG_SITE="https://coreelec.org"
PKG_URL="https://github.com/avdvplus/service.coreelec.settings/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain Python3 connman pygobject dbus-python"
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
