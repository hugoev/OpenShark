#!/bin/zsh
# Phase 0 bootstrap: install Qt 6, cmake, then configure and build OpenShark.
set -e

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR}/.."
BUILD_DIR="${PROJECT_DIR}/build"

echo "==> Checking Homebrew dependencies..."
brew install --quiet qt cmake 2>&1 | grep -v "^==> Pouring\|^Already\|^Linking\|^Warning"

QT_PREFIX="$(brew --prefix qt)"
CMAKE_BIN="$(brew --prefix cmake)/bin/cmake"

echo "==> Qt prefix: $QT_PREFIX"
echo "==> CMake:     $CMAKE_BIN"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "==> Configuring..."
"$CMAKE_BIN" .. \
    -DCMAKE_PREFIX_PATH="$QT_PREFIX" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0

echo "==> Building..."
"$CMAKE_BIN" --build . --parallel "$(sysctl -n hw.logicalcpu)"

echo ""
echo "Build complete.  Run:"
echo "  open ${BUILD_DIR}/openshark.app"
echo ""
echo "If you get 'operation not permitted' on capture, install ChmodBPF:"
echo "  sudo chmod 644 /dev/bpf*"
