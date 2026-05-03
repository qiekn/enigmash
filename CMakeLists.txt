cmake_minimum_required(VERSION 3.30)

set(CMAKE_CXX_MODULE_STD OFF)

project(enigmash LANGUAGES C CXX)

# Default to Release for single-config generators when caller didn't specify
# CMAKE_BUILD_TYPE (suppresses raylib's default-build warning too).
if (NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Hardcoded to libc++ (Clang). MSVC users may need to drop this flag.
if (NOT MSVC)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")
endif()

set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build libraries as shared" FORCE)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)

# Submodule sanity checks
if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/deps/raylib/CMakeLists.txt")
  message(FATAL_ERROR
    "raylib submodule is missing. Run: git submodule update --init --recursive")
endif()

if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/deps/imgui/imgui.h")
  message(FATAL_ERROR
    "imgui submodule is missing. Run: git submodule update --init --recursive")
endif()

foreach(_dep IN ITEMS
    "deps/entt/single_include/entt/entt.hpp"
    "deps/json/single_include/nlohmann/json.hpp"
    "deps/magic-enum/include/magic_enum/magic_enum.hpp"
    "deps/raygui/src/raygui.h")
  if (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_dep}")
    message(FATAL_ERROR
      "Submodule header missing: ${_dep}. "
      "Run: git submodule update --init --recursive")
  endif()
endforeach()

add_subdirectory(deps/raylib)

add_library(imgui STATIC
  deps/imgui/imgui.cpp
  deps/imgui/imgui_draw.cpp
  deps/imgui/imgui_tables.cpp
  deps/imgui/imgui_widgets.cpp
  deps/imgui/imgui_demo.cpp
  deps/imgui/backends/imgui_impl_glfw.cpp
  deps/imgui/backends/imgui_impl_opengl3.cpp
)

target_include_directories(imgui PUBLIC deps/imgui deps/imgui/backends)
target_include_directories(imgui PRIVATE deps/raylib/src/external/glfw/include)

add_executable(${PROJECT_NAME}
  src/engine/scene_manager.cpp
  src/engine/text.cpp
  src/game/input.cpp
  src/game/objects_registry.cpp
  src/game/regions/dispatch.cpp
  src/game/regions/r1_sokoban.cpp
  src/game/regions/r2_gravity.cpp
  src/game/regions/r3_chain.cpp
  src/game/regions/r4_shoot.cpp
  src/game/regions/r5_snake.cpp
  src/game/regions/r6_cluster.cpp
  src/game/sprite_cache.cpp
  src/game/systems/render_interp.cpp
  src/game/systems/render_tiles.cpp
  src/game/systems/spatial.cpp
  src/game/undo_ring.cpp
  src/game/world.cpp
  src/game.cpp
  src/game_layer.cpp
  src/imgui_layer.cpp
  src/layer_stack.cpp
  src/main.cpp
  src/scenes/achievements_scene.cpp
  src/scenes/credits_scene.cpp
  src/scenes/end_scene.cpp
  src/scenes/gallery_scene.cpp
  src/scenes/gameplay_scene.cpp
  src/scenes/main_menu_scene.cpp
  src/scenes/pause_menu_scene.cpp
  src/scenes/placeholder.cpp
  src/scenes/settings_scene.cpp
)

# We don't use C++20 modules. Skipping the per-TU module dependency scan
# avoids a flaky Windows ninja path where clang-scan-deps' .ddi.tmp →
# .ddi rename loses a race with Defender / the Search Indexer holding a
# handle on the file. Side benefit: noticeably faster reconfigures.
set_target_properties(${PROJECT_NAME} PROPERTIES CXX_SCAN_FOR_MODULES OFF)

# Hide the Windows console window in release builds.
set_target_properties(${PROJECT_NAME} PROPERTIES WIN32_EXECUTABLE TRUE)

# Embed the multi-size .ico as a Windows resource so Explorer / the
# taskbar / Alt-Tab pickers all show our icon for the .exe itself.
# CMake routes .rc files through windres (Clang/MinGW) or rc.exe (MSVC)
# automatically; nothing else to wire.
if(WIN32)
  target_sources(${PROJECT_NAME} PRIVATE cmake/icon.rc)
endif()

if(UNIX AND NOT APPLE)
  set_target_properties(${PROJECT_NAME} PROPERTIES
    BUILD_RPATH "$ORIGIN"
    INSTALL_RPATH "$ORIGIN"
  )
endif()

target_include_directories(${PROJECT_NAME}
  PRIVATE
    deps/entt/single_include
    deps/json/single_include
    deps/magic-enum/include
    deps/raygui/src
    deps/raylib/src/external/glfw/include
    src
)

target_link_libraries(${PROJECT_NAME}
  PRIVATE
    raylib
    imgui
)

if (APPLE)
  target_link_libraries(${PROJECT_NAME}
    PRIVATE
      "-framework IOKit"
      "-framework Cocoa"
      "-framework OpenGL"
  )
endif()
