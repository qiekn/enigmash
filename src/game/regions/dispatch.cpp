#include "game/regions/dispatch.h"

#include "game/components.h"
#include "game/regions/r1_sokoban.h"
#include "game/regions/r2_gravity.h"
#include "game/regions/r3_chain.h"
#include "game/regions/r4_shoot.h"
#include "game/regions/r5_snake.h"
#include "game/regions/r6_cluster.h"
#include "game/world.h"

namespace game::regions {

Region RegionUnderPlayer(const World& w) {
  const auto& reg = w.Registry();
  for (auto [e, c] : reg.view<const Cell, const Player>().each()) {
    for (const auto& info : w.Regions()) {
      if (c.x >= info.min_x && c.x < info.max_x &&
          c.y >= info.min_y && c.y < info.max_y) {
        return info.kind;
      }
    }
  }
  return Region::None;
}

void Tick(World& w, Region kind, Direction dir, bool shoot) {
  switch (kind) {
    case Region::R2Gravity:
      Sokoban(w, dir);
      GravityLatePass(w);
      break;
    case Region::R3Chain:
      ChainPush(w, dir);
      break;
    case Region::R4Shoot:
      Shoot(w, dir, shoot);
      break;
    case Region::R5Snake:
      Snake(w, dir);
      break;
    case Region::R6Cluster:
      Cluster(w, dir);
      break;
    case Region::R1Sokoban:
    default:
      Sokoban(w, dir);
      break;
  }
}

}  // namespace game::regions
