# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2018-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="mariadb-connector-c"
PKG_VERSION="3.4.1"
PKG_SHA256="4979916af92aaf7f7b09578897b7dd885d4acd9bfa8a6a0026334dbe98a0d2ab"
PKG_LICENSE="LGPL"
PKG_SITE="https://mariadb.org/"
PKG_URL="https://github.com/mariadb-corporation/mariadb-connector-c/archive/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain zlib openssl"
PKG_LONGDESC="mariadb-connector: library to conntect to mariadb/mysql database server"
PKG_BUILD_FLAGS="-gold"

PKG_CMAKE_OPTS_TARGET="-DWITH_EXTERNAL_ZLIB=ON
                       -DWITH_UNIT_TESTS=OFF
                       -DCLIENT_PLUGIN_DIALOG=STATIC
                       -DCLIENT_PLUGIN_MYSQL_CLEAR_PASSWORD=STATIC
                       -DCLIENT_PLUGIN_MYSQL_OLD_PASSWORD=STATIC
                       -DCLIENT_PLUGIN_REMOTE_IO=OFF
                       -DDEFAULT_SSL_VERIFY_SERVER_CERT=OFF
                      "

post_makeinstall_target() {
  # keep modern authentication plugins
  PLUGINP=${INSTALL}/usr/lib/mariadb/plugin
  LIBP=${INSTALL}/usr/lib/mariadb

  mkdir -p ${INSTALL}/.tmp/plugins ${INSTALL}/.tmp/lib
  mv ${PLUGINP}/{caching_sha2_password,client_ed25519,sha256_password}.so ${INSTALL}/.tmp/plugins

  # Keep the client library for consumers like Kodi.
  if ls ${LIBP}/libmariadb.so* >/dev/null 2>&1; then
    mv ${LIBP}/libmariadb.so* ${INSTALL}/.tmp/lib/
  fi

  # drop all unneeded
  rm -rf ${INSTALL}/usr

  mkdir -p ${PLUGINP}
  mkdir -p ${INSTALL}/usr/lib/mariadb
  mkdir -p ${INSTALL}/usr/lib

  mv ${INSTALL}/.tmp/plugins/* ${PLUGINP}/
  if ls ${INSTALL}/.tmp/lib/* >/dev/null 2>&1; then
    # Put libmariadb into the default runtime search path.
    mv ${INSTALL}/.tmp/lib/* ${INSTALL}/usr/lib/
    ln -sf ../libmariadb.so.3 ${INSTALL}/usr/lib/mariadb/libmariadb.so.3
  fi

  rmdir ${INSTALL}/.tmp/plugins ${INSTALL}/.tmp/lib ${INSTALL}/.tmp
}
