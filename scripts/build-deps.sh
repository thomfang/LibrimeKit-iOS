#!/usr/bin/env bash
# Build the 5 small native deps that librime needs, cross-compiled to iOS slices.
#
# Status: STUB — implementation in progress (M1.6).
#
# Deps to build (sourced from librime's own deps/ submodules):
#   - glog
#   - leveldb
#   - marisa-trie
#   - opencc
#   - yaml-cpp
# Note: googletest is a librime test dep — skipped.
#
# Boost is handled separately via deps/boost-iosx (which produces xcframeworks
# directly). build-librime.sh consumes both this script's output and the boost
# xcframeworks.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIBRIME_DIR="$ROOT/deps/librime"
BUILD_DIR="$ROOT/build"
TOOLCHAIN="$ROOT/scripts/iOS-Toolchain.cmake"

SLICES=("OS" "SIMULATOR_ARM64" "SIMULATOR")
DEPS=("glog" "leveldb" "marisa-trie" "opencc" "yaml-cpp")

build_dep_for_slice() {
  local dep="$1"
  local platform="$2"
  local slice="$3"
  local src="$LIBRIME_DIR/deps/$dep"
  local build="$BUILD_DIR/$slice/$dep"
  local prefix="$BUILD_DIR/install/$slice"

  echo "=== building $dep for $slice ==="
  # TODO(M1.6): per-dep CMake flags. Each lib has its own conventions:
  #   glog        -DWITH_GFLAGS=OFF -DBUILD_TESTING=OFF
  #   leveldb     -DLEVELDB_BUILD_TESTS=OFF -DLEVELDB_BUILD_BENCHMARKS=OFF
  #   marisa      no CMake — uses autotools; needs custom shim or wrap
  #   opencc     -DENABLE_GTEST=OFF -DENABLE_DARTS=OFF -DUSE_SYSTEM_*=OFF
  #   yaml-cpp   -DYAML_CPP_BUILD_TESTS=OFF -DYAML_CPP_BUILD_TOOLS=OFF
  #
  # cmake -S "$src" -B "$build" \
  #       -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  #       -DIOS_PLATFORM="$platform" \
  #       -DCMAKE_INSTALL_PREFIX="$prefix" \
  #       -DCMAKE_BUILD_TYPE=Release
  # cmake --build "$build" --target install --config Release
}

main() {
  for platform in "${SLICES[@]}"; do
    case "$platform" in
      OS)              slice="ios-arm64" ;;
      SIMULATOR_ARM64) slice="ios-arm64-simulator" ;;
      SIMULATOR)       slice="ios-x86_64-simulator" ;;
    esac
    for dep in "${DEPS[@]}"; do
      build_dep_for_slice "$dep" "$platform" "$slice"
    done
  done
  echo "==="
  echo "build-deps.sh STUB — no .a produced yet. Implementation pending M1.6."
  echo "==="
  exit 1
}

main "$@"
