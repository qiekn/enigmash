#include "engine/text.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <filesystem>
#include <string>
#include <unordered_map>
#include <vector>

namespace engine {
namespace {

// -----------------------------------------------------------------------------: config

constexpr const char* kRegularPath = "assets/fonts/noto/NotoSans-Regular.ttf";
// CJK glyphs live in a separate Noto family (the Latin Noto Sans doesn't
// contain Han). NotoSansSC-Regular covers Simplified Chinese + Latin in
// one TTF; switch to TC/JP/KR siblings if a locale needs them.
//
// NOTE: this file is the *static* Regular weight, instanced from the
// upstream variable TTF via `fonttools varLib.instancer wght=400`. Do
// NOT swap in the upstream `*-VF.ttf` directly — stb_truetype ignores
// the fvar axes and would render at the file's default instance, which
// is Thin (wght=100) for Noto CJK VF.
constexpr const char* kCjkPath = "assets/fonts/noto/NotoSansSC-Regular.ttf";

// Pre-loaded sizes (in logical UI pt) — covers HUD common range. At
// ui_scale=2.0 these become 32/36/40/48/64 physical px atlases.
constexpr int kPreloadAsciiSizes[] = {16, 18, 20, 24, 32};
// CJK adds ~21k Han glyphs to every atlas — preloading 5 sizes blows VRAM.
// Bake just the most common pt; lazy load handles anything else on demand.
constexpr int kPreloadCjkSizes[] = {18};

// Super-sampling factor for the atlas. We bake the bitmap at N× the
// rendered size so DrawTextEx scales the atlas DOWN at draw time. raylib's
// stb_truetype path has visible baseline rounding artifacts (descenders of
// 'j' / 'g' clip; '1' sits a sub-pixel above the line) at small target
// sizes — a larger bake + downscale dodges both.
//
// 2× for ASCII (cheap, only ~95 glyphs). 1× for CJK because the atlas is
// already huge with ~21k glyphs; doubling it would waste tens of MB of
// VRAM for a benefit that's barely visible at CJK strokes anyway.
constexpr int kSuperSampleAscii = 2;
constexpr int kSuperSampleCjk = 1;

constexpr float kDefaultSpacing = 1.0f;

// -----------------------------------------------------------------------------: cache types

struct FontEntry {
  Font font{};
  int physical_size = 0;  // matches the size DrawTextEx must pass for crisp 1:1
};

std::unordered_map<int, FontEntry> g_cache;
std::vector<int> g_codepoints;
float g_ui_scale = 1.0f;
CodepointSet g_cps = CodepointSet::AsciiOnly;

// -----------------------------------------------------------------------------: helpers

void BuildCodepoints(CodepointSet cps) {
  g_codepoints.clear();
  // ASCII printable range. (Newline / tab handled by DrawTextEx itself.)
  for (int c = 0x20; c <= 0x7E; ++c) g_codepoints.push_back(c);

  if (cps == CodepointSet::AsciiPlusCJK) {
    // CJK Symbols and Punctuation — 、 。 「 」 etc.
    for (int c = 0x3000; c <= 0x303F; ++c) g_codepoints.push_back(c);
    // CJK Unified Ideographs — bulk of common Chinese / Japanese kanji.
    for (int c = 0x4E00; c <= 0x9FFF; ++c) g_codepoints.push_back(c);
    // Halfwidth / Fullwidth Forms.
    for (int c = 0xFF00; c <= 0xFFEF; ++c) g_codepoints.push_back(c);
  }
}

int Physical(int logical_size) {
  return static_cast<int>(std::round(logical_size * g_ui_scale));
}

const char* PathFor(CodepointSet cps) {
  return cps == CodepointSet::AsciiPlusCJK ? kCjkPath : kRegularPath;
}

int SuperSampleFor(CodepointSet cps) {
  return cps == CodepointSet::AsciiPlusCJK ? kSuperSampleCjk : kSuperSampleAscii;
}

float DetectUiScale() {
  // Mirrors ImGuiLayer::GetDpiScale — read raylib's per-axis DPI and take
  // the max, never below 1.0. Keeps raylib text the same visual size as
  // ImGui text on HiDPI displays.
  Vector2 dpi = GetWindowScaleDPI();
  return std::max(1.0f, std::max(dpi.x, dpi.y));
}

FontEntry LoadOne(const char* path, int logical_size) {
  FontEntry entry{};
  entry.physical_size = Physical(logical_size);
  const int bake_size = entry.physical_size * SuperSampleFor(g_cps);
  if (!std::filesystem::exists(path)) {
    std::fprintf(stderr, "engine::Text: font file missing: %s — falling back\n", path);
    entry.font = GetFontDefault();
    return entry;
  }
  entry.font = LoadFontEx(path, bake_size, g_codepoints.data(), static_cast<int>(g_codepoints.size()));
  // The atlas is now higher-res than we render at — bilinear downsample
  // gives clean glyphs. POINT here would alias hard.
  SetTextureFilter(entry.font.texture, TEXTURE_FILTER_BILINEAR);
  return entry;
}

const FontEntry& GetOrLoad(int logical_size) {
  if (auto it = g_cache.find(logical_size); it != g_cache.end()) {
    return it->second;
  }
  FontEntry entry = LoadOne(PathFor(g_cps), logical_size);
  auto [it, _] = g_cache.emplace(logical_size, entry);
  return it->second;
}

}  // namespace

// -----------------------------------------------------------------------------: api

void LoadFonts(CodepointSet cps, float ui_scale) {
  if (!g_cache.empty()) return;  // idempotent
  g_cps = cps;
  g_ui_scale = (ui_scale > 0.0f) ? ui_scale : DetectUiScale();
  BuildCodepoints(cps);
  const char* path = PathFor(cps);
  if (cps == CodepointSet::AsciiPlusCJK) {
    for (int s : kPreloadCjkSizes) g_cache[s] = LoadOne(path, s);
  } else {
    for (int s : kPreloadAsciiSizes) g_cache[s] = LoadOne(path, s);
  }
}

void UnloadFonts() {
  for (auto& [_, entry] : g_cache) {
    // Don't unload raylib's default font — it owns its own lifecycle.
    if (entry.font.texture.id != GetFontDefault().texture.id) {
      UnloadFont(entry.font);
    }
  }
  g_cache.clear();
  g_codepoints.clear();
  g_ui_scale = 1.0f;
  g_cps = CodepointSet::AsciiOnly;
}

const Font& GetFont(int logical_size) { return GetOrLoad(logical_size).font; }

float UiScale() { return g_ui_scale; }

CodepointSet GetCodepointSet() { return g_cps; }

void DrawText(std::string_view text, Vector2 pos, int size, Color color) {
  std::string s(text);
  const FontEntry& e = GetOrLoad(size);
  // fontSize = physical so DrawTextEx hits the atlas 1:1 (crisp). Spacing
  // scales with the same factor so kerning stays proportional on HiDPI.
  DrawTextEx(e.font, s.c_str(), pos, static_cast<float>(e.physical_size),
             kDefaultSpacing * g_ui_scale, color);
}

Vector2 MeasureText(std::string_view text, int size) {
  std::string s(text);
  const FontEntry& e = GetOrLoad(size);
  return MeasureTextEx(e.font, s.c_str(), static_cast<float>(e.physical_size),
                       kDefaultSpacing * g_ui_scale);
}

}  // namespace engine
