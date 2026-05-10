#pragma once

namespace scenes::ui {

// -----------------------------------------------------------------------------: shared chrome
//
// Most placeholder scenes (Settings / Gallery / Achievements / Credits /
// End) share the same skeleton: title centered, hint at the bottom. This
// helper draws that common chrome so each scene's OnRender stays a few
// lines long.
void DrawPlaceholderFrame(int target_w, int target_h, const char* title, const char* hint = nullptr);

}  // namespace scenes::ui
