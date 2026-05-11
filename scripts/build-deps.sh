#!/usr/bin/env bash
# Build the 5 small native deps that librime needs, cross-compiled to iOS slices.
#
# Status: M1.6 — all 5 deps implemented as pure CMake.
#
# Deps to build (sourced from librime's own deps/ submodules):
#   - glog
#   - leveldb
#   - yaml-cpp
#   - opencc
#   - marisa-trie   (新版已含 CMakeLists.txt, 无需 autotools wrap)
#
# Boost is handled separately via deps/boost-iosx (which produces xcframeworks
# directly). build-librime.sh consumes both this script's output and the boost
# xcframeworks.
#
# Usage:
#   ./scripts/build-deps.sh                  # all deps × all slices
#   ./scripts/build-deps.sh glog             # one dep, all slices
#   ./scripts/build-deps.sh glog ios-arm64   # one dep, one slice

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIBRIME_DIR="$ROOT/deps/librime"
BUILD_DIR="$ROOT/build"
TOOLCHAIN="$ROOT/scripts/iOS-Toolchain.cmake"

ALL_SLICES=("ios-arm64" "ios-arm64-simulator" "ios-x86_64-simulator")
ALL_DEPS=("glog" "leveldb" "yaml-cpp" "opencc" "marisa-trie")

# slice 名 -> IOS_PLATFORM 值（喂给 toolchain）
slice_to_platform() {
  case "$1" in
    ios-arm64)              echo "OS" ;;
    ios-arm64-simulator)    echo "SIMULATOR_ARM64" ;;
    ios-x86_64-simulator)   echo "SIMULATOR" ;;
    *) echo "ERR_UNKNOWN_SLICE_$1"; return 1 ;;
  esac
}

# 公共 cmake 入口，子函数只负责传 -D 给特定 dep
run_cmake() {
  local src="$1" build="$2" prefix="$3" platform="$4"; shift 4
  cmake -S "$src" -B "$build" -G "Unix Makefiles" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DIOS_PLATFORM="$platform" \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="$prefix" \
    "$@"
  cmake --build "$build" --target install --parallel
}

build_glog() {
  local slice="$1" platform; platform=$(slice_to_platform "$slice")
  local src="$LIBRIME_DIR/deps/glog"
  local build="$BUILD_DIR/$slice/glog"
  local prefix="$BUILD_DIR/install/$slice"

  echo "=== glog → $slice ==="
  rm -rf "$build"
  # glog 0.7.1: iOS 下关掉 gflags / gtest / pkg-config / unwind / fuzzing。
  # CheckCXXSourceRuns 在 CMAKE_CROSSCOMPILING=TRUE 下自动跳过执行（仅编译）。
  run_cmake "$src" "$build" "$prefix" "$platform" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTING=OFF \
    -DWITH_GFLAGS=OFF \
    -DWITH_GTEST=OFF \
    -DWITH_PKGCONFIG=OFF \
    -DWITH_UNWIND=none \
    -DPRINT_UNSYMBOLIZED_STACK_TRACES=OFF
}

build_leveldb() {
  local slice="$1" platform; platform=$(slice_to_platform "$slice")
  local src="$LIBRIME_DIR/deps/leveldb"
  local build="$BUILD_DIR/$slice/leveldb"
  local prefix="$BUILD_DIR/install/$slice"

  echo "=== leveldb → $slice ==="
  rm -rf "$build"
  # check_library_exists 在 iOS cross-compile 下会误探测 host brew 的 libcrc32c / libsnappy。
  # 强制 cache 变量为 0，让 leveldb 走自带的 util/crc32c.cc 实现，关掉 snappy。
  run_cmake "$src" "$build" "$prefix" "$platform" \
    -DBUILD_SHARED_LIBS=OFF \
    -DLEVELDB_BUILD_TESTS=OFF \
    -DLEVELDB_BUILD_BENCHMARKS=OFF \
    -DLEVELDB_INSTALL=ON \
    -DHAVE_CRC32C:BOOL=OFF \
    -DHAVE_SNAPPY:BOOL=OFF \
    -DHAVE_TCMALLOC:BOOL=OFF
}

build_yaml_cpp() {
  local slice="$1" platform; platform=$(slice_to_platform "$slice")
  local src="$LIBRIME_DIR/deps/yaml-cpp"
  local build="$BUILD_DIR/$slice/yaml-cpp"
  local prefix="$BUILD_DIR/install/$slice"

  echo "=== yaml-cpp → $slice ==="
  rm -rf "$build"
  run_cmake "$src" "$build" "$prefix" "$platform" \
    -DBUILD_SHARED_LIBS=OFF \
    -DYAML_BUILD_SHARED_LIBS=OFF \
    -DYAML_CPP_BUILD_CONTRIB=ON \
    -DYAML_CPP_BUILD_TOOLS=OFF \
    -DYAML_CPP_BUILD_TESTS=OFF \
    -DYAML_CPP_INSTALL=ON
}

build_opencc() {
  local slice="$1" platform; platform=$(slice_to_platform "$slice")
  local src="$LIBRIME_DIR/deps/opencc"
  local build="$BUILD_DIR/$slice/opencc"
  local prefix="$BUILD_DIR/install/$slice"

  echo "=== opencc → $slice ==="
  rm -rf "$build"
  # opencc 顶层无条件 add tools/data/doc/test，iOS 用不上。
  # 通过 CMAKE_PROJECT_opencc_INCLUDE 注入 overlay 跳过这些子目录。
  run_cmake "$src" "$build" "$prefix" "$platform" \
    -DCMAKE_PROJECT_opencc_INCLUDE="$ROOT/scripts/cmake/opencc-ios-overlay.cmake" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_DOCUMENTATION=OFF \
    -DENABLE_GTEST=OFF \
    -DENABLE_BENCHMARK=OFF \
    -DENABLE_DARTS=OFF \
    -DBUILD_PYTHON=OFF \
    -DUSE_SYSTEM_MARISA=OFF
}

build_marisa_trie() {
  local slice="$1" platform; platform=$(slice_to_platform "$slice")
  local src="$LIBRIME_DIR/deps/marisa-trie"
  local build="$BUILD_DIR/$slice/marisa-trie"
  local prefix="$BUILD_DIR/install/$slice"

  echo "=== marisa-trie → $slice ==="
  rm -rf "$build"
  run_cmake "$src" "$build" "$prefix" "$platform" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTING=OFF \
    -DENABLE_TOOLS=OFF \
    -DENABLE_NATIVE_CODE=OFF
}

build_dep_for_slice() {
  local dep="$1" slice="$2"
  case "$dep" in
    glog)        build_glog "$slice" ;;
    leveldb)     build_leveldb "$slice" ;;
    yaml-cpp)    build_yaml_cpp "$slice" ;;
    opencc)      build_opencc "$slice" ;;
    marisa-trie) build_marisa_trie "$slice" ;;
    *) echo "Unknown dep: $dep"; return 1 ;;
  esac
}

main() {
  local deps=("${ALL_DEPS[@]}")
  local slices=("${ALL_SLICES[@]}")
  if [ $# -ge 1 ]; then deps=("$1"); fi
  if [ $# -ge 2 ]; then slices=("$2"); fi

  for slice in "${slices[@]}"; do
    for dep in "${deps[@]}"; do
      build_dep_for_slice "$dep" "$slice"
    done
  done

  echo "=== done ==="
}

main "$@"
