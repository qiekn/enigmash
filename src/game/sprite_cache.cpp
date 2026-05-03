#include "game/sprite_cache.h"

#include <raylib.h>

#include <algorithm>
#include <cstdint>
#include <string>
#include <utility>

namespace game {

namespace {

constexpr int kOutlinePx = 4;

// Slightly darken a color (used for the placeholder outline).
Color Darken(Color c, float amt) {
  c.r = (unsigned char)std::max(0, (int)(c.r * (1.0f - amt)));
  c.g = (unsigned char)std::max(0, (int)(c.g * (1.0f - amt)));
  c.b = (unsigned char)std::max(0, (int)(c.b * (1.0f - amt)));
  return c;
}

}  // namespace

Texture2D SpriteCache::MakePlaceholder(Color fill) {
  Image img = GenImageColor(kSourcePx, kSourcePx, fill);
  ImageDrawRectangleLines(&img, Rectangle{0, 0, (float)kSourcePx, (float)kSourcePx},
                          kOutlinePx, Darken(fill, 0.35f));
  Texture2D tex = LoadTextureFromImage(img);
  UnloadImage(img);
  SetTextureFilter(tex, TEXTURE_FILTER_POINT);
  return tex;
}

uint32_t SpriteCache::Register(std::string name, std::string path, Color fallback) {
  Slot s;
  s.name = std::move(name);
  s.path = std::move(path);
  s.fallback = fallback;
  slots_.push_back(std::move(s));
  return static_cast<uint32_t>(slots_.size() - 1);
}

void SpriteCache::EnsureLoaded() {
  if (loaded_) return;
  for (auto& s : slots_) {
    if (!s.path.empty() && FileExists(s.path.c_str())) {
      s.tex = LoadTexture(s.path.c_str());
      if (s.tex.id == 0) {
        TraceLog(LOG_WARNING, "SpriteCache: '%s' load failed, using placeholder", s.path.c_str());
        s.tex = MakePlaceholder(s.fallback);
        s.generated = true;
      } else {
        SetTextureFilter(s.tex, TEXTURE_FILTER_POINT);
      }
    } else {
      s.tex = MakePlaceholder(s.fallback);
      s.generated = true;
    }
  }
  loaded_ = true;
}

void SpriteCache::Unload() {
  if (!loaded_) return;
  for (auto& s : slots_) {
    if (s.tex.id != 0) {
      UnloadTexture(s.tex);
      s.tex = Texture2D{};
    }
  }
  loaded_ = false;
}

}  // namespace game
