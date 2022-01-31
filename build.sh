#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# USAGE: create_worktree NUM
# Create an isolated working directory and copy the repository into it.
# Intended to mimic Bazel's sandbox working directory.
create_worktree() (
  local NUM="$1"
  local WORK="$SCRIPT_DIR/work$NUM"
  rm -rf "$WORK"
  mkdir "$WORK"
  git archive --format=tar HEAD | tar x -C "$WORK"
  echo "$WORK"
)

# USAGE: cc_build INSTALLDIR
# Build and install the C components.
cc_build() (
  local INSTALL="$1"
  cd myclib
  trap "rm -f add.o libmyclib.so" EXIT
  gcc -c -Wall -Werror -fpic add.c -o add.o
  gcc -shared -o libmyclib.so add.o
  install -d "$INSTALL/myclib"
  install myclib.h libmyclib.so "$INSTALL/myclib"
)

# USAGE: cabal_build INSTALLDIR
# Build and install the Cabal components.
cabal_build() (
  local INSTALL="$1"
  cd mypackage
  local RELINSTALL="$(realpath --relative-to="$PWD" "$INSTALL")"
  trap "runghc Setup.hs clean" EXIT
  ghc-pkg init "$INSTALL/package.conf.d"
  runghc Setup.hs configure \
    --user \
    --enable-deterministic \
    --enable-relocatable \
    --extra-include-dirs="$RELINSTALL/myclib" \
    --extra-lib-dirs="$RELINSTALL/myclib" \
    --prefix="$INSTALL/mypackage" \
    --package-db="$INSTALL/package.conf.d"
  runghc Setup.hs build
  runghc Setup.hs copy
  runghc Setup.hs register --gen-pkg-config="dist/mypackage-0.1.0.0.conf"
  # Patch package-db to be relocatable
  sed -i -e "s#${RELINSTALL}#\${pkgroot}#" "dist/mypackage-0.1.0.0.conf"
  ghc-pkg register --package-db "$INSTALL/package.conf.d" "dist/mypackage-0.1.0.0.conf"
)

# USAGE: script WORKTREENUM
# Create worktree NUM and build and install the C and Cabal components.
script() (
  local NUM="$1"
  cd "$(create_worktree "$NUM")"
  cc_build "$PWD/install"
  cabal_build "$PWD/install"
)

script 1
script 2
