#!/usr/bin/env bash
# Extract per-slice boost headers + .a from boost-iosx output into
# build/install/<slice>/{include,lib}/.
#
# boost-iosx (post-build) layout (built via xcodebuild -create-xcframework -library):
#   deps/boost-iosx/frameworks/
#     Headers/boost/              ← all boost headers, shared across slices
#     boost_regex.xcframework/
#       ios-arm64/libboost_regex.a
#       ios-arm64-simulator/libboost_regex.a       (or ios-arm64_x86_64-simulator if lipo'd)
#     boost_system.xcframework/{...}
#     ...
#
# Output per slice:
#   build/install/<slice>/include/boost/       ← cp from Headers/boost
#   build/install/<slice>/lib/libboost_<n>.a   ← cp from xcframework/<slice>/

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FW_DIR="$ROOT/deps/boost-iosx/frameworks"
BUILD_DIR="$ROOT/build"

# Map our slice naming to whatever directory exists inside the .xcframework.
# boost-iosx may produce `ios-arm64-simulator` (single arch) or
# `ios-arm64_x86_64-simulator` (lipo'd fat slice) depending on what was built.
locate_xc_slice() {
  local xcfw="$1" want="$2"
  if [ -d "$xcfw/$want" ]; then echo "$want"; return; fi
  # Fall back: any slice ending in -simulator if we want a sim arch
  case "$want" in
    ios-arm64-simulator|ios-x86_64-simulator)
      for s in "$xcfw"/ios-*simulator*; do
        [ -d "$s" ] || continue
        echo "$(basename "$s")"
        return
      done
      ;;
  esac
  return 1
}

extract_for_slice() {
  local slice="$1"
  local prefix="$BUILD_DIR/install/$slice"

  if [ ! -d "$FW_DIR" ]; then
    echo "ERROR: $FW_DIR not found — run 'cd deps/boost-iosx && make build' first" >&2
    return 1
  fi
  if [ ! -d "$FW_DIR/Headers/boost" ]; then
    echo "ERROR: $FW_DIR/Headers/boost not found (boost-iosx build incomplete?)" >&2
    return 1
  fi

  mkdir -p "$prefix/include" "$prefix/lib"

  echo "  headers → $prefix/include/boost"
  rm -rf "$prefix/include/boost"
  cp -R "$FW_DIR/Headers/boost" "$prefix/include/boost"

  local count=0
  for xcfw in "$FW_DIR"/boost_*.xcframework; do
    [ -d "$xcfw" ] || continue
    local libname; libname=$(basename "$xcfw" .xcframework)  # boost_regex
    local xcslice; xcslice=$(locate_xc_slice "$xcfw" "$slice") || {
      echo "  WARN: no $slice slice in $(basename "$xcfw")"
      continue
    }
    local bin="$xcfw/$xcslice/lib${libname}.a"
    if [ ! -f "$bin" ]; then
      echo "  WARN: $bin missing — skipping" >&2
      continue
    fi
    cp "$bin" "$prefix/lib/lib${libname}.a"
    count=$((count + 1))
  done
  echo "  → $count boost libs copied"
}

main() {
  local slices=("ios-arm64" "ios-arm64-simulator" "ios-x86_64-simulator")
  if [ $# -ge 1 ]; then slices=("$@"); fi
  for slice in "${slices[@]}"; do
    echo "=== extract boost → $slice ==="
    extract_for_slice "$slice"
  done
  echo "=== done ==="
}

main "$@"
