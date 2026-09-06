# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2016-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="htop"
PKG_VERSION="3.5.3"
PKG_SHA256="edf25ee020a5263ffbef9eef5a8c14392bf74e78b3d5c8bc64d9343dd9a82605"
PKG_LICENSE="GPL"
PKG_SITE="https://htop.dev"
PKG_URL="https://github.com/htop-dev/htop/archive/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain ncurses"
PKG_LONGDESC="An interactive process viewer for Unix."
PKG_TOOLCHAIN="autotools"
PKG_BUILD_FLAGS="-sysroot"

PKG_CONFIGURE_OPTS_TARGET="--enable-unicode \
                           HTOP_NCURSES_CONFIG_SCRIPT=ncursesw6-config"

pre_configure_target() {
  export LDFLAGS="${LDFLAGS} -pthread"
}
