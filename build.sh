#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

cc_build() (
  local INSTALL="$1"
  cd myclib
  trap "rm -f add.o libmyclib.so" EXIT
  gcc -c -Wall -Werror -fpic add.c -o add.o
  gcc -shared -o libmyclib.so add.o
  install -d "$INSTALL/myclib"
  install myclib.h libmyclib.so "$INSTALL/myclib"
)

cabal_build() (
  local INSTALL="$1"
  cd mypackage
  trap "runghc Setup.hs clean" EXIT
  install -d "$INSTALL/package.conf.d"
  runghc Setup.hs configure \
    --user \
    --enable-deterministic \
    --enable-relocatable \
    --extra-include-dirs="$(realpath --relative-to="$PWD" "$INSTALL/myclib")" \
    --extra-lib-dirs="$(realpath --relative-to="$PWD" "$INSTALL/myclib")" \
    --prefix="$INSTALL/mypackage" \
    --package-db="$INSTALL/package.conf.d"
  runghc Setup.hs build
  runghc Setup.hs install
  # Patch package-db to be relocatable
  sed -i -e "s#$INSTALL#\${pkgroot}#" "$INSTALL"/package.conf.d/*.conf
  ghc-pkg recache --package-db="$INSTALL/package.conf.d"
)

rm -rf "$SCRIPT_DIR"/install*

cc_build  "$SCRIPT_DIR/install1"
cabal_build "$SCRIPT_DIR/install1"

cc_build  "$SCRIPT_DIR/install2"
cabal_build "$SCRIPT_DIR/install2"
