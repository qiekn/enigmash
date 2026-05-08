#include "game/systems/patch_box_sprite.h"

#include "game/components.h"
#include "game/objects_registry.h"
#include "game/regions/dispatch.h"
#include "game/world.h"

namespace game::systems {

namespace {

const char* ThingNameForRegion(Region r) {
  switch (r) {
    case Region::R1Sokoban: return "thingone";
    case Region::R2Climb:   return "thingtwo";
    case Region::R3Chain:   return "thingthree";
    case Region::R4Shoot:   return "thingfour";
    case Region::R5Slide:   return "thingfive";
    case Region::R6Cluster: return "thingsix";
    default:                return nullptr;
  }
}

}  // namespace

void PatchBoxSprite(World& w) {
  // Resolve the 6 sprite ids up front. Cheap (6 hashmap lookups) and
  // avoids per-entity name lookups inside the view loop. Missing entries
  // (e.g. a region whose thing variant isn't in objects.json yet) leave
  // their slot at 0 — entities in that region keep their current sprite.
  uint32_t ids[7] = {};
  bool has[7] = {};
  for (int i = 1; i <= 6; ++i) {
    if (const ObjectDef* def = w.Objects().Find(ThingNameForRegion(static_cast<Region>(i)))) {
      ids[i] = def->sprite_id;
      has[i] = true;
    }
  }
  auto& reg = w.Registry();
  for (auto [e, c, sp] : reg.view<Cell, Sprite, Pushable>().each()) {
    if (reg.all_of<Hidden>(e)) continue;
    if (reg.all_of<Linked>(e)) continue;
    const Region r = regions::RegionAt(w, c.x, c.y);
    const int idx = static_cast<int>(r);
    if (idx < 1 || idx > 6 || !has[idx]) continue;
    sp.atlas_id = ids[idx];
  }
}

}  // namespace game::systems
