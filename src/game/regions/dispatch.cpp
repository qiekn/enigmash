#include "game/regions/dispatch.h"

#include "game/components.h"
#include "game/regions/r1_sokoban.h"
#include "game/regions/r2_climb.h"
#include "game/regions/r2_gravity.h"
#include "game/regions/r3_chain.h"
#include "game/regions/r4_shoot.h"
#include "game/regions/r5_slide.h"
#include "game/regions/r6_cluster.h"
#include "game/world.h"

namespace game::regions {

Region RegionUnderPlayer(const World& w) {
  const auto& reg = w.Registry();
  for (auto [e, c] : reg.view<const Cell, const Player>().each()) {
    for (const auto& info : w.Regions()) {
      if (c.x < info.min_x || c.x >= info.max_x ||
          c.y < info.min_y || c.y >= info.max_y) {
        continue;
      }
      if (!info.cell_kind.empty()) {
        const int width = info.max_x - info.min_x;
        const size_t idx = static_cast<size_t>(c.y - info.min_y) * width + (c.x - info.min_x);
        if (idx < info.cell_kind.size()) {
          uint8_t v = info.cell_kind[idx];
          if (v >= 1 && v <= 6) return static_cast<Region>(v);
        }
      }
      return info.kind;
    }
  }
  return Region::None;
}

void Tick(World& w, Region kind, Direction dir, bool shoot) {
  switch (kind) {
    case Region::R2Climb:
      Climb(w, dir);
      GravityLatePass(w);
      break;
    case Region::R3Chain:
      ChainPush(w, dir);
      break;
    case Region::R4Shoot:
      Shoot(w, dir, shoot);
      break;
    case Region::R5Slide:
      Slide(w, dir);
      break;
    case Region::R6Cluster:
      // r6's PS rules build clusters via spatial adjacency, same idea
      // as r3 — visual differentiation will come from sprite art, not
      // a separate mechanic.
      ChainPush(w, dir);
      break;
    case Region::R1Sokoban:
    default:
      Sokoban(w, dir);
      break;
  }
}

}  // namespace game::regions
