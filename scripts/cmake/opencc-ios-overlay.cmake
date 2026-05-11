# Injected after opencc's `project()` via CMAKE_PROJECT_opencc_INCLUDE.
# Overrides add_subdirectory to skip components not needed for iOS:
#   - data:      dict compilation, requires Python + opencc_dict runtime tool.
#   - src/tools: command-line executables (opencc / opencc_dict / opencc_phrase_extract),
#                CMake 4.x rejects MACOSX_BUNDLE install without BUNDLE DESTINATION.
#   - doc:       Doxygen output, not relevant when BUILD_DOCUMENTATION=OFF.
# The library libopencc.a (built from src/) is unaffected.

function(add_subdirectory dir)
  if(dir MATCHES "^(data|tools|doc|test|benchmark)$")
    message(STATUS "[iOS overlay] skipping add_subdirectory(${dir})")
    return()
  endif()
  _add_subdirectory("${dir}" ${ARGN})
endfunction()
