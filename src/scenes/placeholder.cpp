#include "scenes/placeholder.h"

#include <raylib.h>

#include "engine/text.h"

namespace scenes::ui {

void DrawPlaceholderFrame(int w, int h, const char* title, const char* hint) {
  // Centered title in the top third — leaves the middle empty for the
  // scene's own widgets to land in once the placeholder is fleshed out.
  const Vector2 size = engine::MeasureText(title, 48);
  engine::DrawText(title, Vector2{(w - size.x) * 0.5f, h * 0.18f}, 48, RAYWHITE);

  const char* default_hint = "press esc to return";
  engine::DrawText(hint ? hint : default_hint, Vector2{16.0f, h - 30.0f}, 16, Color{140, 140, 160, 200});
}

}  // namespace scenes::ui
