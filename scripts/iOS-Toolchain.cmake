# CMake toolchain file for cross-compiling to iOS / iOS simulator.
#
# Usage:
#   cmake -S . -B build/<slice> \
#         -DCMAKE_TOOLCHAIN_FILE=$LIBRIMEKIT_ROOT/scripts/iOS-Toolchain.cmake \
#         -DIOS_PLATFORM=OS|SIMULATOR|SIMULATOR_ARM64 \
#         -DCMAKE_INSTALL_PREFIX=build/install/<slice>
#
# Notes:
# - Min deployment target iOS 13.0 matches Scripting.app's current floor.
# - Bitcode is dead (Xcode 14+); we don't enable it.
# - Static-only: try_compile uses STATIC_LIBRARY since the simulator linker
#   refuses to produce executables without a host on bare CMake.

cmake_minimum_required(VERSION 3.18)

set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_VERSION 13.0)
set(CMAKE_OSX_DEPLOYMENT_TARGET 13.0 CACHE STRING "iOS deployment target")

if(NOT DEFINED IOS_PLATFORM)
  set(IOS_PLATFORM "OS")
endif()

if(IOS_PLATFORM STREQUAL "OS")
  set(_IOS_SYSROOT "iphoneos")
  set(_IOS_ARCH    "arm64")
  set(_IOS_SLICE_NAME "ios-arm64")
elseif(IOS_PLATFORM STREQUAL "SIMULATOR")
  set(_IOS_SYSROOT "iphonesimulator")
  set(_IOS_ARCH    "x86_64")
  set(_IOS_SLICE_NAME "ios-x86_64-simulator")
elseif(IOS_PLATFORM STREQUAL "SIMULATOR_ARM64")
  set(_IOS_SYSROOT "iphonesimulator")
  set(_IOS_ARCH    "arm64")
  set(_IOS_SLICE_NAME "ios-arm64-simulator")
else()
  message(FATAL_ERROR "IOS_PLATFORM must be OS, SIMULATOR, or SIMULATOR_ARM64")
endif()

# CACHE FORCE 是必须的：CMake 4.x 对 toolchain 里普通 set() 的 CMAKE_OSX_ARCHITECTURES
# 不会传到子项目，导致某些 dep 退回 host arch（M1 上变成 arm64，污染 x86_64 slice）。
set(CMAKE_OSX_SYSROOT       "${_IOS_SYSROOT}" CACHE STRING "iOS sysroot" FORCE)
set(CMAKE_OSX_ARCHITECTURES "${_IOS_ARCH}"    CACHE STRING "iOS arch"    FORCE)

message(STATUS "iOS toolchain: ${IOS_PLATFORM} (${_IOS_SLICE_NAME})")

# Static-only world for distribution as xcframework.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

# try_compile produces a static library, not an executable — required when
# cross-compiling to simulator without an executable host context.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# Use libc++ explicitly; some dep CMake scripts otherwise default to libstdc++.
set(_IOS_CXX_FLAGS "-stdlib=libc++")
set(CMAKE_C_FLAGS_INIT   "")
set(CMAKE_CXX_FLAGS_INIT "${_IOS_CXX_FLAGS}")

# Don't search host system for libraries — only the iOS SDK.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
