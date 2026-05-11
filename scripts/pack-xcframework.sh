#!/usr/bin/env bash
# Pack per-slice static libraries into XCFrameworks under $ROOT/Frameworks/.
#
# Status: M1.8 implementation.
#
# Each lib (rime + glog + leveldb + marisa + opencc + yaml-cpp) -> one .xcframework:
#   ios-arm64                  ← cp from build/install/ios-arm64/lib/
#   ios-arm64_x86_64-simulator ← lipo'd from ios-arm64-simulator + ios-x86_64-simulator
# Headers come from the device slice (identical across slices).
#
# Boost xcframeworks come pre-packed from deps/boost-iosx — just copy them.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
OUTDIR="$ROOT/Frameworks"
BOOST_FW_DIR="$ROOT/deps/boost-iosx/frameworks"

mkdir -p "$OUTDIR"

# librime install names its archive "librime.a" (project name = rime), so the
# tuple is (xcframework_name, library_basename, header_dir_relative_to_install).
# rime headers live at the include/ root; the rest are in include/<libname>/.
LIBS=(
  "librime:librime:rime"
  "libglog:libglog:glog"
  "libleveldb:libleveldb:leveldb"
  "libmarisa:libmarisa:marisa"
  "libopencc:libopencc:opencc"
  "libyaml-cpp:libyaml-cpp:yaml-cpp"
)

lipo_simulator_slice() {
  local libfile="$1"  # e.g. librime.a
  local arm64="$BUILD_DIR/install/ios-arm64-simulator/lib/$libfile"
  local x86="$BUILD_DIR/install/ios-x86_64-simulator/lib/$libfile"
  local outdir="$BUILD_DIR/install/ios-arm64_x86_64-simulator/lib"
  local out="$outdir/$libfile"

  if [ ! -f "$arm64" ] || [ ! -f "$x86" ]; then
    echo "  WARN: missing slice for $libfile (arm64=$([ -f "$arm64" ] && echo y || echo n) x86=$([ -f "$x86" ] && echo y || echo n))" >&2
    return 1
  fi
  mkdir -p "$outdir"
  lipo -create "$arm64" "$x86" -output "$out"
  echo "  lipo → $out"
}

# Some librime install dirs may not have a per-lib header subdir (e.g. opencc
# headers are at include/opencc/, but rime headers are at include/ root with
# rime_api.h + rime/). We dispatch per-lib.
collect_headers() {
  local libname="$1" header_dirname="$2" stage="$3"
  local src="$BUILD_DIR/install/ios-arm64/include"
  mkdir -p "$stage"

  case "$libname" in
    librime)
      # Top-level rime_api*.h + rime_levers_api.h, no per-lib subdir
      cp "$src"/rime_api.h "$src"/rime_api_deprecated.h \
         "$src"/rime_api_stdbool.h "$src"/rime_levers_api.h \
         "$stage/" 2>/dev/null || true
      ;;
    *)
      # Standard: include/<header_dirname>/
      if [ -d "$src/$header_dirname" ]; then
        cp -R "$src/$header_dirname" "$stage/"
      else
        echo "  WARN: no header dir at $src/$header_dirname" >&2
      fi
      ;;
  esac
}

pack_one() {
  local entry="$1"
  local fw_name="${entry%%:*}"           # librime
  local rest="${entry#*:}"
  local lib_base="${rest%%:*}"           # librime
  local header_dir="${rest#*:}"          # rime

  local libfile="${lib_base}.a"
  local device_lib="$BUILD_DIR/install/ios-arm64/lib/$libfile"
  local sim_lib="$BUILD_DIR/install/ios-arm64_x86_64-simulator/lib/$libfile"

  if [ ! -f "$device_lib" ]; then
    echo "  WARN: missing $device_lib — skipping $fw_name" >&2
    return 1
  fi
  if [ ! -f "$sim_lib" ]; then
    echo "  WARN: missing $sim_lib — skipping $fw_name" >&2
    return 1
  fi

  local header_stage; header_stage=$(mktemp -d)
  trap "rm -rf '$header_stage'" RETURN
  collect_headers "$lib_base" "$header_dir" "$header_stage"

  local out="$OUTDIR/${fw_name}.xcframework"
  rm -rf "$out"

  xcodebuild -create-xcframework \
    -library "$device_lib" -headers "$header_stage" \
    -library "$sim_lib"    -headers "$header_stage" \
    -output "$out" > /dev/null

  echo "  → $out"
}

copy_boost_xcframeworks() {
  if [ ! -d "$BOOST_FW_DIR" ]; then
    echo "  WARN: $BOOST_FW_DIR missing — skipping boost copy" >&2
    return
  fi
  local count=0
  for x in "$BOOST_FW_DIR"/boost_*.xcframework; do
    [ -d "$x" ] || continue
    rm -rf "$OUTDIR/$(basename "$x")"
    cp -R "$x" "$OUTDIR/"
    count=$((count + 1))
  done
  echo "  → $count boost xcframeworks copied"
}

main() {
  echo "=== merging simulator slices (arm64 + x86_64 → fat) ==="
  for entry in "${LIBS[@]}"; do
    local lib_base="${entry#*:}"; lib_base="${lib_base%%:*}"
    lipo_simulator_slice "${lib_base}.a" || true
  done

  echo "=== packing xcframeworks ==="
  for entry in "${LIBS[@]}"; do pack_one "$entry"; done

  echo "=== copying boost xcframeworks ==="
  copy_boost_xcframeworks

  echo "=== done → $OUTDIR ==="
  ls -d "$OUTDIR"/*.xcframework 2>/dev/null | sed 's|.*/|  |'
}

main "$@"
