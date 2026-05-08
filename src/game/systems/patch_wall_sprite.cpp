#include "game/systems/patch_wall_sprite.h"

#include <cstddef>
#include <cstdint>

#include "game/components.h"
#include "game/objects_registry.h"
#include "game/world.h"

namespace game::systems {

namespace {

// Raw region marker at world (x, y). Walls have value 0 since the decoder's
// BFS doesn't propagate through them; walkable floors have 1..6. We need
// the raw value (not RegionAt) because RegionAt falls back to the region's
// overall kind for cell_kind==0 cells, which would mis-classify every
// wall as r1 and erase the boundary signal.
uint8_t RawCellKind(const World& w, int x, int y) {
  for (const auto& info : w.Regions()) {
    if (x < info.min_x || x >= info.max_x ||
        y < info.min_y || y >= info.max_y) {
      continue;
    }
    if (info.cell_kind.empty()) return static_cast<uint8_t>(info.kind);
    const int width = info.max_x - info.min_x;
    const std::size_t idx =
        static_cast<std::size_t>(y - info.min_y) * width + (x - info.min_x);
    if (idx >= info.cell_kind.size()) return 0;
    return info.cell_kind[idx];
  }
  return 0;
}

// Pick the wall variant name. `region` is the "owner" of this boundary
// (the highest-numbered styled neighbour); the open_* flags indicate
// which sides face that region's floor — used only by r2 to pick its
// directional trim. Returns nullptr to leave the existing sprite intact
// (e.g. r1-only walls, r6 which has no styled variant).
const char* WallNameFor(uint8_t region,
                        bool open_n, bool open_s, bool open_w, bool open_e) {
  switch (region) {
    case 2:
      // Priority follows the original PS rule order: walltwodown is the
      // base for left/right derivations, so a wall whose south face is
      // exposed anchors there. Up wins next, then horizontal trims.
      if (open_s) return "walltwodown";
      if (open_n) return "walltwoup";
      if (open_w) return "walltwoleft";
      if (open_e) return "walltworight";
      return "walltwo";
    case 3: return "wallthree";
    case 4: return "wallfour";
    case 5: return "wallfive";
    default: return nullptr;
  }
}

}  // namespace

void PatchWallSprite(World& w) {
  auto& reg = w.Registry();
  for (auto [e, c, sp] : reg.view<Cell, Sprite, Stop>().each()) {
    if (reg.all_of<Hidden>(e)) continue;
    // Toggleable secret walls own a deliberate sprite (e.g. wallfive for
    // a hidden r5 segment). Don't second-guess the level author.
    if (reg.all_of<Toggleable>(e)) continue;

    // Highest-numbered styled neighbour wins. r1 (=1) is the default skin
    // and r6 has no styled variant, so both leave the wall alone.
    uint8_t best = 0;
    auto observe = [&](int dx, int dy) {
      const uint8_t r = RawCellKind(w, c.x + dx, c.y + dy);
      if (r >= 2 && r <= 5 && r > best) best = r;
    };
    observe(0, -1);
    observe(0, 1);
    observe(-1, 0);
    observe(1, 0);
    if (best == 0) continue;

    const bool open_n = RawCellKind(w, c.x, c.y - 1) == best;
    const bool open_s = RawCellKind(w, c.x, c.y + 1) == best;
    const bool open_w = RawCellKind(w, c.x - 1, c.y) == best;
    const bool open_e = RawCellKind(w, c.x + 1, c.y) == best;
    const char* name = WallNameFor(best, open_n, open_s, open_w, open_e);
    if (name == nullptr) continue;
    if (const ObjectDef* def = w.Objects().Find(name)) {
      sp.atlas_id = def->sprite_id;
    }
  }
}

}  // namespace game::systems
