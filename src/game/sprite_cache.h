#pragma once

#include <raylib.h>

#include <cstdint>
#include <string>
#include <vector>

namespace game {

// Owns Texture2Ds for every object kind. Slots are never moved or
// reordered after registration; ObjectDef::sprite_id is a stable index.
//
// Lifecycle: the cache must outlive the GL context (call Unload before
// CloseWindow). EnsureLoaded is called once after the GL context exists
// and the ObjectsRegistry has been parsed; it walks each def, tries the
// sprite_path, and falls back to a procedurally-generated colored square
// when the file is missing or rejected.
class SpriteCache {
 public:
  // Default sprite size for procedural placeholders. Real PNGs may be any
  // size; the renderer scales via DrawTexturePro using kTilePx.
  static constexpr int kSourcePx = 128;

  SpriteCache() = default;
  SpriteCache(const SpriteCache&) = delete;
  SpriteCache& operator=(const SpriteCache&) = delete;

  // Reserve a slot. Returns the slot id (== current size). Texture not
  // loaded yet — slot is filled by EnsureLoaded.
  uint32_t Register(std::string name, std::string path, Color fallback);

  // Load every registered slot. Idempotent.
  void EnsureLoaded();

  // Free GPU textures. Safe to call before CloseWindow; no-op afterwards
  // is a leak so make sure to call this from Game::Shutdown's GL window.
  void Unload();

  const Texture2D& Get(uint32_t id) const { return slots_[id].tex; }
  bool IsLoaded() const { return loaded_; }

 private:
  struct Slot {
    std::string name;
    std::string path;
    Color fallback{255, 0, 255, 255};
    Texture2D tex{};
    bool generated = false;
  };

  // Renders a flat color square with a thin outline so adjacent tiles
  // have a visible seam. Used when a sprite_path is missing or fails.
  static Texture2D MakePlaceholder(Color fill);

  std::vector<Slot> slots_;
  bool loaded_ = false;
};

}  // namespace game
