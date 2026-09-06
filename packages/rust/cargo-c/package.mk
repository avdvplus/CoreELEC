# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2023-present Team CoreELEC (https://coreelec.org)

PKG_NAME="cargo-c"
PKG_VERSION="v0.10.22"
PKG_SHA256="a7b00539437932f2a17a72b97d9c2142367a2d70ee20f9f1692a8b13c7255332"
PKG_LICENSE="MIT"
PKG_SITE="https://github.com/lu-zero/cargo-c"
PKG_URL="https://github.com/lu-zero/cargo-c/archive/refs/tags/${PKG_VERSION}.tar.gz"
PKG_DEPENDS_HOST="cargo:host"
PKG_LONGDESC="Use Cargo-c to build and install C-compatible libraries"
PKG_TOOLCHAIN="manual"

make_host() {
  CARGO_RESOLVER_INCOMPATIBLE_RUST_VERSIONS=fallback cargo build --release --manifest-path ${PKG_BUILD}/Cargo.toml
}

makeinstall_host() {
  CARGO_RESOLVER_INCOMPATIBLE_RUST_VERSIONS=fallback cargo install --profile release --path ${PKG_BUILD}
}
