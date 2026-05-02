#pragma once

#include <raylib.h>

#include <string_view>

namespace engine {

// -----------------------------------------------------------------------------: codepoint coverage
//
// raylib's LoadFontEx rasterises an atlas eagerly. Wider codepoint sets =
// bigger atlas + slower load, so MVP defaults to ASCII only and opts into
// CJK explicitly when the game starts pulling localized strings.
enum class CodepointSet {
  AsciiOnly,     // U+0020 .. U+007E
  AsciiPlusCJK,  // ASCII + U+3000..303F (CJK punct)
                 //       + U+4E00..9FFF (Unified Ideographs)
                 //       + U+FF00..FFEF (Fullwidth/Halfwidth)
};

// -----------------------------------------------------------------------------: lifecycle
//
// Initialise the global font cache. Idempotent — second call is a no-op.
// Pre-loads NotoSans Regular at a few common sizes so the first frame
// doesn't pause to rasterise. Lazy load handles anything else.
//
// `ui_scale` is the DPI-driven multiplier applied when rasterising the atlas:
// every requested logical size N is baked at `round(N * ui_scale)` physical
// pixels. Pass <= 0 (the default) to auto-detect from raylib's
// `GetWindowScaleDPI()` — that matches what ImGui does, so raylib text at
// logical size 18 renders the same visual height as ImGui at size 18.
//
// Must be called AFTER InitWindow (raylib needs a GL context to upload the
// font atlas texture).
void LoadFonts(CodepointSet cps = CodepointSet::AsciiOnly, float ui_scale = -1.0f);

// Free every cached Font. Must be called BEFORE CloseWindow (raylib needs
// the GL context to free the GPU textures).
void UnloadFonts();

// -----------------------------------------------------------------------------: lookups
//
// Look up (or lazy-load) the cached Noto Sans atlas for a given logical
// size. Useful when you want to call raylib's DrawTextEx directly.
const Font& GetFont(int logical_size);

// DPI multiplier picked at LoadFonts() time. Layers that need to keep
// raylib draws visually consistent with ImGui (e.g. drawing into the same
// RT) read this for things like spacing.
float UiScale();

// -----------------------------------------------------------------------------: drawing
//
// All Draw* / Measure below take *logical* sizes (UI points). They wrap
// DrawTextEx / MeasureTextEx and auto-pick the appropriately-rasterised
// atlas. Spacing is fixed at 1 logical pt scaled by UiScale().
void DrawText(std::string_view text, Vector2 pos, int size, Color color);

Vector2 MeasureText(std::string_view text, int size);

}  // namespace engine
