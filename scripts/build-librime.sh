#!/usr/bin/env bash
# Build librime 1.16.1 cross-compiled to iOS slices.
#
# Status: M1.7 — implemented for the 3 iOS slices.
#
# Inputs:
#   - $ROOT/build/install/<slice>/{lib,include}  produced by build-deps.sh
#       glog, leveldb, marisa, opencc, yaml-cpp
#   - $ROOT/build/install/<slice>/{lib/libboost_*.a, include/boost/}
#       extracted from $ROOT/deps/boost-iosx/frameworks/ by extract-boost.sh
#
# Output:
#   - $ROOT/build/install/<slice>/lib/librime.a
#   - $ROOT/build/install/<slice>/include/rime_api.h, rime/*.h

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIBRIME_DIR="$ROOT/deps/librime"
BUILD_DIR="$ROOT/build"
TOOLCHAIN="$ROOT/scripts/iOS-Toolchain.cmake"

ALL_SLICES=("ios-arm64" "ios-arm64-simulator" "ios-x86_64-simulator")

# librime-lua plugin: clone master 到 plugins/lua/，跑 action-install.sh 把 stock Lua 5.4
# 源码（thirdparty 分支 mirror）拉到 plugins/lua/thirdparty/。librime CMake `add_subdirectory(plugins)`
# 会自动发现，加上 BUILD_MERGED_PLUGINS=ON（已设）→ rime-lua-objs 合并进 librime.a。
ensure_lua_plugin() {
  local plugin_dir="$LIBRIME_DIR/plugins/lua"
  if [ ! -d "$plugin_dir/.git" ]; then
    echo "=== cloning librime-lua master → $plugin_dir ==="
    rm -rf "$plugin_dir"
    git clone --depth 1 https://github.com/hchunhui/librime-lua.git "$plugin_dir"
  fi
  if [ ! -f "$plugin_dir/thirdparty/lua5.4/lua.h" ]; then
    echo "=== running plugins/lua/action-install.sh (downloads stock Lua source) ==="
    (cd "$plugin_dir" && bash action-install.sh)
  fi
  # iOS SDK 把 system() 标 unavailable，stock Lua 5.4 loslib.c 编不过。luaconf.h 提供
  # LUA_USE_IOS 宏走 iOS 退化路径（system 返回 -1，os.execute(nil) 返回 false）。
  # 在 plugin CMakeLists.txt 追加一行，确保 LUA_SRC + rime-lua-objs 都拿到这个 define。
  local marker="# LibrimeKit-iOS: LUA_USE_IOS"
  if ! grep -qF "$marker" "$plugin_dir/CMakeLists.txt"; then
    cat >> "$plugin_dir/CMakeLists.txt" <<EOF

$marker
target_compile_definitions(rime-lua-objs PRIVATE LUA_USE_IOS)
EOF
  fi
  # librime 静态库下 rime_declare_module_dependencies() 硬编码只 require core/dict/gears/levers，
  # lua plugin 的 __attribute__((constructor)) 在静态库里没人 reference 会被 linker dead-strip。
  # 把 require_module_lua() 加进 dependency 链，强制 lua module 被 link 进 librime.a。
  local rime_api="$LIBRIME_DIR/src/rime_api.cc"
  local api_marker="// LibrimeKit-iOS: force-link lua"
  if [ -f "$rime_api" ] && ! grep -qF "$api_marker" "$rime_api"; then
    # 匹配函数体内的 `  rime_require_module_levers();`（行首 2 空格、无 extern），
    # 在它后面追加 lua call。注意必须用锚定模式区别于 file-scope `extern void ...();`。
    awk -v marker="$api_marker" '
      /^  rime_require_module_levers\(\);[[:space:]]*$/ {
        print
        print "  " marker
        print "  extern void rime_require_module_lua();"
        print "  rime_require_module_lua();"
        next
      }
      { print }
    ' "$rime_api" > "$rime_api.tmp" && mv "$rime_api.tmp" "$rime_api"
  fi
}

slice_to_platform() {
  case "$1" in
    ios-arm64)              echo "OS" ;;
    ios-arm64-simulator)    echo "SIMULATOR_ARM64" ;;
    ios-x86_64-simulator)   echo "SIMULATOR" ;;
    *) echo "ERR_UNKNOWN_SLICE_$1"; return 1 ;;
  esac
}

build_librime_for_slice() {
  local slice="$1" platform; platform=$(slice_to_platform "$slice")
  local build="$BUILD_DIR/$slice/librime"
  local prefix="$BUILD_DIR/install/$slice"

  # 前置：deps 必须先编好
  for lib in glog leveldb marisa opencc yaml-cpp; do
    if [ ! -f "$prefix/lib/lib${lib}.a" ]; then
      echo "ERROR: missing $prefix/lib/lib${lib}.a — run scripts/build-deps.sh first" >&2
      return 1
    fi
  done
  if [ ! -f "$prefix/lib/libboost_regex.a" ]; then
    echo "ERROR: missing $prefix/lib/libboost_regex.a — run scripts/extract-boost.sh first" >&2
    return 1
  fi

  echo "=== librime → $slice ==="
  rm -rf "$build"
  # librime 自带 Find*.cmake 走 find_path/find_library，会搜 CMAKE_PREFIX_PATH 下的
  # include/ 和 lib/。CMAKE_FIND_ROOT_PATH 也要加上以满足 toolchain 的 ROOT_PATH_MODE=ONLY。
  # Boost 用手工 set 跳过系统 FindBoost（boost-iosx 不装 BoostConfig.cmake）。
  cmake -S "$LIBRIME_DIR" -B "$build" -G "Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DIOS_PLATFORM="$platform" \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCMAKE_PREFIX_PATH="$prefix" \
    -DCMAKE_FIND_ROOT_PATH="$prefix;$(xcrun --sdk "$([ "$slice" = "ios-arm64" ] && echo iphoneos || echo iphonesimulator)" --show-sdk-path)" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_STATIC=ON \
    -DBUILD_TEST=OFF \
    -DBUILD_SAMPLE=OFF \
    -DBUILD_DATA=OFF \
    -DBUILD_SEPARATE_LIBS=OFF \
    -DBUILD_MERGED_PLUGINS=ON \
    -DINSTALL_PRIVATE_HEADERS=OFF \
    -DENABLE_EXTERNAL_PLUGINS=OFF \
    -DENABLE_LOGGING=ON \
    -DENABLE_THREADING=ON \
    -DENABLE_TIMESTAMP=OFF \
    -DBoost_NO_BOOST_CMAKE=ON \
    -DBoost_INCLUDE_DIR="$prefix/include" \
    -DBoost_LIBRARY_DIR="$prefix/lib" \
    -DBoost_USE_STATIC_LIBS=ON \
    -DBoost_FOUND=TRUE \
    -DBoost_INCLUDE_DIRS="$prefix/include" \
    -DBoost_LIBRARIES="$prefix/lib/libboost_regex.a;$prefix/lib/libboost_system.a;$prefix/lib/libboost_filesystem.a;$prefix/lib/libboost_thread.a"
  cmake --build "$build" --target install --parallel
}

main() {
  ensure_lua_plugin
  local slices=("${ALL_SLICES[@]}")
  if [ $# -ge 1 ]; then slices=("$1"); fi
  for slice in "${slices[@]}"; do
    build_librime_for_slice "$slice"
  done
  echo "=== done ==="
}

main "$@"
