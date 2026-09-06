# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2009-2016 Stephan Raue (stephan@openelec.tv)
# Copyright (C) 2016-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="udevil"
# PKG_VERSION="f2b715d1d821e4b69b2fb0864a5a178dd67877f0"
# PKG_SHA256="3351d56c553c518cb2ce7b24892a4b62d630ba4f6ebee2c3994c4be9828f0629"
# PKG_LICENSE="GPL"
# PKG_SITE="https://github.com/alpharde/udevil"
# PKG_URL="https://github.com/alpharde/udevil/archive/${PKG_VERSION}.tar.gz"
PKG_NAME="udevil"
PKG_VERSION="0.4.4"
PKG_SHA256="ce8c51fd4d589cda7be56e75b42188deeb258c66fc911a9b3a70a3945c157739"
PKG_LICENSE="GPL"
PKG_SITE="https://github.com/IgnorantGuru/udevil"
PKG_URL="https://deb.debian.org/debian/pool/main/u/udevil/udevil_${PKG_VERSION}.orig.tar.xz"
PKG_DEPENDS_TARGET="toolchain systemd glib"
PKG_LONGDESC="Mounts and unmounts removable devices and networks without a password."

pre_configure_target() {
  # Fix missing sys/stat.h include in device-info.c
  sed -i '1i#include <sys/stat.h>' ${PKG_BUILD}/src/device-info.c
}

PKG_CONFIGURE_OPTS_TARGET="--disable-systemd \
                           --with-mount-prog=/usr/bin/mount \
                           --with-umount-prog=/usr/bin/umount \
                           --with-losetup-prog=/usr/sbin/losetup \
                           --with-setfacl-prog=/usr/bin/setfacl"

makeinstall_target() {
 : # nothing to install
}

post_makeinstall_target() {
  mkdir -p ${INSTALL}/etc/udevil
    cp ${PKG_DIR}/config/udevil.conf ${INSTALL}/etc/udevil
    ln -sf /storage/.config/udevil.conf ${INSTALL}/etc/udevil/udevil-user-root.conf

  mkdir -p ${INSTALL}/usr/bin
    cp -PR src/udevil ${INSTALL}/usr/bin

  mkdir -p ${INSTALL}/usr/sbin
  echo -e '#!/bin/sh\nexec /usr/bin/mount -t ntfs3 "$@"' > ${INSTALL}/usr/sbin/mount.ntfs
  chmod 755 ${INSTALL}/usr/sbin/mount.ntfs
}

post_install() {
  enable_service udevil-mount@.service
}
