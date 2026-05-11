#!/usr/bin/env bash
# Pack per-slice static libraries into XCFrameworks under $ROOT/Frameworks/.
#
# Status: STUB — implementation in progress (M1.8).
#
# Strategy:
#   Each lib (librime + glog + leveldb + marisa + opencc + yaml-cpp) -> one .xcframework.
#   Each xcframework contains:
#     - ios-arm64                  (from build/install/ios-arm64/lib)
#     - ios-arm64_x86_64-simulator (lipo'd from ios-arm64-simulator + ios-x86_64-simulator)
#   Headers are taken from the device slice (they're identical across slices).
#
#   Boost xcframeworks come pre-packed from deps/boost-iosx — we just copy them.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
OUTDIR="$ROOT/Frameworks"
BOOST_FW_DIR="$ROOT/deps/boost-iosx/frameworks"

mkdir -p "$OUTDIR"

LIBS=("rime" "glog" "leveldb" "marisa" "opencc" "yaml-cpp")

lipo_simulator() {
  local lib="$1"
  local arm64="$BUILD_DIR/install/ios-arm64-simulator/lib/lib${lib}.a"
  local x86="$BUILD_DIR/install/ios-x86_64-simulator/lib/lib${lib}.a"
  local out="$BUILD_DIR/install/ios-arm64_x86_64-simulator/lib/lib${lib}.a"
  mkdir -p "$(dirname "$out")"
  # TODO(M1.8): lipo -create "$arm64" "$x86" -output "$out"
  echo "  (stub) would lipo: $arm64 + $x86 -> $out"
}

pack_xcframework() {
  local lib="$1"
  # TODO(M1.8):
  # xcodebuild -create-xcframework \
  #   -library $BUILD_DIR/install/ios-arm64/lib/lib${lib}.a \
  #     -headers $BUILD_DIR/install/ios-arm64/include \
  #   -library $BUILD_DIR/install/ios-arm64_x86_64-simulator/lib/lib${lib}.a \
  #     -headers $BUILD_DIR/install/ios-arm64-simulator/include \
  #   -output $OUTDIR/lib${lib}.xcframework
  echo "  (stub) would pack lib${lib}.xcframework"
}

copy_boost_xcframeworks() {
  # TODO(M1.8): cp -R $BOOST_FW_DIR/*.xcframework $OUTDIR/
  echo "  (stub) would copy boost xcframeworks from $BOOST_FW_DIR"
}

main() {
  echo "=== merging simulator slices ==="
  for lib in "${LIBS[@]}"; do lipo_simulator "$lib"; done

  echo "=== packing xcframeworks ==="
  for lib in "${LIBS[@]}"; do pack_xcframework "$lib"; done

  echo "=== copying boost ==="
  copy_boost_xcframeworks

  echo "==="
  echo "pack-xcframework.sh STUB — no .xcframework produced yet. Pending M1.8."
  echo "==="
  exit 1
}

main "$@"
