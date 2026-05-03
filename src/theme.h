#pragma once

#include <raylib.h>

namespace theme {

// -----------------------------------------------------------------------------: palette
//
// Master neutral background (#1a1b1c). Used everywhere we'd otherwise pick
// an arbitrary near-black:
//   - the splash frame painted in Game::Init before heavy loads
//   - every scene's ClearBackground
//   - ImGuiLayer's WindowBg + the backbuffer clear behind dock-empty
//     regions
//
// Picking from one named constant keeps the seams between raylib draws
// and ImGui chrome invisible — a docked panel and the surrounding empty
// dock area read as the same surface.
inline constexpr Color kBackground{0x1a, 0x1b, 0x1c, 0xff};

}  // namespace theme
