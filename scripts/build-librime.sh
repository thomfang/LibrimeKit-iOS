#!/usr/bin/env bash
# Build librime 1.16.1 cross-compiled to iOS slices.
#
# Status: STUB — implementation in progress (M1.7).
#
# Inputs:
#   - $ROOT/build/install/<slice>/{lib,include}  produced by build-deps.sh
#   - $ROOT/deps/boost-iosx/frameworks/*.xcframework  produced by boost-iosx
#
# Output:
#   - $ROOT/build/install/<slice>/lib/librime.a (static)
#   - $ROOT/build/install/<slice>/include/rime_api.h

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIBRIME_DIR="$ROOT/deps/librime"
BUILD_DIR="$ROOT/build"
TOOLCHAIN="$ROOT/scripts/iOS-Toolchain.cmake"

SLICES=("OS" "SIMULATOR_ARM64" "SIMULATOR")

build_librime_for_slice() {
  local platform="$1"
  local slice="$2"
  local build="$BUILD_DIR/$slice/librime"
  local prefix="$BUILD_DIR/install/$slice"

  echo "=== building librime for $slice ==="
  # TODO(M1.7):
  # 1) Boost: extract per-slice headers + .a from boost-iosx xcframeworks
  #    or wrap with imported targets; set Boost_DIR.
  # 2) Glog: prefix has glog from build-deps.sh.
  # 3) librime CMake flags (iOS-friendly):
  #    -DBUILD_SHARED_LIBS=OFF
  #    -DBUILD_STATIC=ON
  #    -DBUILD_TEST=OFF
  #    -DBUILD_SAMPLE=OFF
  #    -DBUILD_DATA=OFF
  #    -DINSTALL_PRIVATE_HEADERS=OFF
  #    -DBUILD_MERGED_PLUGINS=ON
  #    -DENABLE_LOGGING=ON
  #    -DENABLE_THREADING=ON
  #
  # cmake -S "$LIBRIME_DIR" -B "$build" \
  #       -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  #       -DIOS_PLATFORM="$platform" \
  #       -DCMAKE_PREFIX_PATH="$prefix" \
  #       -DCMAKE_INSTALL_PREFIX="$prefix" \
  #       -DBoost_USE_STATIC_LIBS=ON \
  #       <librime iOS flags above>
  # cmake --build "$build" --target install --config Release
}

main() {
  for platform in "${SLICES[@]}"; do
    case "$platform" in
      OS)              slice="ios-arm64" ;;
      SIMULATOR_ARM64) slice="ios-arm64-simulator" ;;
      SIMULATOR)       slice="ios-x86_64-simulator" ;;
    esac
    build_librime_for_slice "$platform" "$slice"
  done
  echo "==="
  echo "build-librime.sh STUB — no librime.a produced yet. Implementation pending M1.7."
  echo "==="
  exit 1
}

main "$@"
