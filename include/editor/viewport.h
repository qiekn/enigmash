#pragma once

#include <raylib.h>

namespace editor {

// Process-wide handoff between the layer that draws the gameplay viewport
// (GameLayer::DrawViewportPanel) and the scene that needs to read
// mouse → world coords from inside its OnImGuiRender (GameplayScene). The
// scene runs after the panel within the same ImGui pass, so reading is
// always one-frame-fresh. `hovered` is reset to false when the panel is
// hidden / not drawn.
struct ViewportInfo {
  bool hovered = false;
  Vector2 image_min{0, 0};
  Vector2 image_size{0, 0};
};

ViewportInfo& Viewport();

}  // namespace editor
