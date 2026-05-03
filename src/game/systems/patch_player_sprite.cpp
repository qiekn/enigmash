#include "game/systems/patch_player_sprite.h"

#include "game/components.h"
#include "game/objects_registry.h"
#include "game/regions/dispatch.h"
#include "game/world.h"

namespace game::systems {

namespace {

const char* PlayerNameForRegion(Region r) {
  switch (r) {
    case Region::R1Sokoban: return "player_one";
    case Region::R2Climb:   return "player_two";
    case Region::R3Chain:   return "player_three";
    case Region::R4Shoot:   return "player_four";
    case Region::R5Snake:   return "player_five";
    case Region::R6Cluster: return "player_six";
    default:                return nullptr;
  }
}

}  // namespace

void PatchPlayerSprite(World& w) {
  const Region kind = regions::RegionUnderPlayer(w);
  const char* name = PlayerNameForRegion(kind);
  if (name == nullptr) return;
  const ObjectDef* def = w.Objects().Find(name);
  if (def == nullptr) return;
  auto& reg = w.Registry();
  for (auto e : reg.view<Player>()) {
    auto* sp = reg.try_get<Sprite>(e);
    if (sp != nullptr) sp->atlas_id = def->sprite_id;
  }
}

}  // namespace game::systems
