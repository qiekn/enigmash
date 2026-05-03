#include "game/regions/r2_gravity.h"

#include <algorithm>
#include <entt/entt.hpp>
#include <vector>

#include "game/components.h"
#include "game/systems/spatial.h"
#include "game/world.h"

namespace game::regions {

namespace {

bool HasPlayerAt(const entt::registry& reg, int x, int y) {
  for (auto [e, c] : reg.view<const Cell, const Player>().each()) {
    if (c.x == x && c.y == y) return true;
  }
  return false;
}

bool CellOccupied(const entt::registry& reg, int x, int y, entt::entity ignore) {
  if (systems::HasStopAt(reg, x, y)) return true;
  if (HasPlayerAt(reg, x, y)) return true;
  // Any other Pushable counts as a support.
  for (auto [e, c] : reg.view<const Cell, const Pushable>().each()) {
    if (e == ignore) continue;
    if (c.x == x && c.y == y) return true;
  }
  return false;
}

}  // namespace

void GravityLatePass(World& w) {
  auto& reg = w.Registry();
  // Iterate until stable. Process bottommost entities first so a column
  // of falling boxes resolves cleanly: the bottom one falls into space,
  // freeing the cell so the one above can fall on the next pass.
  bool changed = true;
  int safety = 64;  // upper bound on column height in any reasonable region
  while (changed && safety-- > 0) {
    changed = false;
    std::vector<entt::entity> ents;
    for (auto [e, c] : reg.view<const Cell, const Pushable>().each()) {
      ents.push_back(e);
    }
    std::sort(ents.begin(), ents.end(), [&](entt::entity a, entt::entity b) {
      return reg.get<Cell>(a).y > reg.get<Cell>(b).y;  // largest y first
    });
    for (auto e : ents) {
      auto& c = reg.get<Cell>(e);
      const int below_y = c.y + 1;
      if (!systems::InBounds(w, c.x, below_y)) continue;
      if (CellOccupied(reg, c.x, below_y, e)) continue;
      c.y = below_y;
      changed = true;
    }
  }
}

}  // namespace game::regions
