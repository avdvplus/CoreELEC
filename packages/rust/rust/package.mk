# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2017-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="rust"
PKG_VERSION="1.94.1"
PKG_SHA256="4c142a625f12e3cdf716c68ae19f4f60d98ad1482627b08579b15838e95ad514"
PKG_LICENSE="MIT"
PKG_SITE="https://www.rust-lang.org"
PKG_URL="https://static.rust-lang.org/dist/rustc-${PKG_VERSION}-src.tar.gz"
LLVM_CI_DOWNLOAD="${LLVM_CI_DOWNLOAD:-yes}"
if [ "${LLVM_CI_DOWNLOAD}" = "yes" ]; then
  PKG_DEPENDS_HOST="toolchain"
else
  PKG_DEPENDS_HOST="toolchain llvm:host"
fi
PKG_DEPENDS_UNPACK="rustc-snapshot rust-std-snapshot cargo-snapshot"
PKG_LONGDESC="A systems programming language that prevents segfaults, and guarantees thread safety."
PKG_TOOLCHAIN="manual"

pre_configure_host() {
  "$(get_build_dir rustc-snapshot)/install.sh" --prefix="${PKG_BUILD}/rust-snapshot" --disable-ldconfig
  "$(get_build_dir rust-std-snapshot)/install.sh" --prefix="${PKG_BUILD}/rust-snapshot" --disable-ldconfig
  "$(get_build_dir cargo-snapshot)/install.sh" --prefix="${PKG_BUILD}/rust-snapshot" --disable-ldconfig
}

configure_host() {

  mkdir -p ${PKG_BUILD}/targets

  case "${TARGET_ARCH}" in
    "arm")
      # the arm target is special because we specify the subarch. ie armv8a
      cp -a ${PKG_DIR}/targets/arm-libreelec-linux-gnueabihf.json ${PKG_BUILD}/targets/${TARGET_NAME}.json
      ;;
    "aarch64" | "x86_64")
      cp -a ${PKG_DIR}/targets/${TARGET_NAME}.json ${PKG_BUILD}/targets/${TARGET_NAME}.json
      ;;
  esac

  # Save cross-compiler paths before host environment overrides them
  local _TARGET_CC="${TOOLCHAIN}/bin/${TARGET_NAME}-gcc"
  local _TARGET_CXX="${TOOLCHAIN}/bin/${TARGET_NAME}-g++"
  local _HOST_CC="${TOOLCHAIN}/bin/host-gcc"
  local _HOST_CXX="${TOOLCHAIN}/bin/host-g++"

  cat >${PKG_BUILD}/config.toml  <<END
change-id = 148671

[llvm]
download-ci-llvm = $([ "${LLVM_CI_DOWNLOAD}" = "yes" ] && echo "true" || echo "false")

[target.${TARGET_NAME}]
$([ "${LLVM_CI_DOWNLOAD}" != "yes" ] && echo "llvm-config = \"${TOOLCHAIN}/bin/llvm-config\"")
cxx = "${_TARGET_CXX}"
cc = "${_TARGET_CC}"

[target.${RUST_HOST}]
$([ "${LLVM_CI_DOWNLOAD}" != "yes" ] && echo "llvm-config = \"${TOOLCHAIN}/bin/llvm-config\"")
cxx = "${_HOST_CXX}"
cc = "${_HOST_CC}"

[rust]
rpath = true
channel = "stable"
codegen-tests = false
optimize = true
llvm-tools = false

[build]
submodules = false
docs = false
profiler = true
vendor = true

rustc = "${PKG_BUILD}/rust-snapshot/bin/rustc"
cargo = "${PKG_BUILD}/rust-snapshot/bin/cargo"

target = [
  "${TARGET_NAME}",
  "${RUST_HOST}"
]

host = [
  "${RUST_HOST}"
]

build = "${RUST_HOST}"

[install]
prefix = "${TOOLCHAIN}"
bindir = "${TOOLCHAIN}/bin"
libdir = "${TOOLCHAIN}/lib"
datadir = "${TOOLCHAIN}/share"
mandir = "${TOOLCHAIN}/share/man"

END

  CARGO_HOME="${PKG_BUILD}/cargo_home"
  mkdir -p "${CARGO_HOME}"

  cat >${CARGO_HOME}/config.toml <<END
[target.${TARGET_NAME}]
linker = "${_TARGET_CC}"

[target.${RUST_HOST}]
linker = "${_HOST_CC}"
rustflags = ["-C", "link-arg=-Wl,-rpath,${TOOLCHAIN}/lib"]

[build]
target-dir = "${PKG_BUILD}/target"

[term]
progress.when = 'always'
progress.width = 80

END
}

make_host() {
  cd ${PKG_BUILD}

  unset CFLAGS
  unset CXXFLAGS
  unset CPPFLAGS
  unset LDFLAGS

  unset CC
  unset CXX
  unset AR

  export RUST_TARGET_PATH="${PKG_BUILD}/targets/"
  export HOST_CMAKE="${TOOLCHAIN}/bin/cmake"

  python3 src/bootstrap/bootstrap.py -j ${CONCURRENCY_MAKE_LEVEL} build --stage 2 --verbose
}

makeinstall_host() {
  mkdir -p ${TOOLCHAIN}/bin
    cp -a build/${RUST_HOST}/stage2/bin/* ${TOOLCHAIN}/bin

  mkdir -p ${TOOLCHAIN}/lib/rustlib
    cp -a build/${RUST_HOST}/stage2/lib/* ${TOOLCHAIN}/lib

    cp -a ${PKG_BUILD}/targets/*.json ${TOOLCHAIN}/lib/rustlib/
}
