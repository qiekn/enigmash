#include "game/regions/r2_gravity.h"

#include <algorithm>
#include <entt/entt.hpp>
#include <vector>

#include "game/components.h"
#include "game/systems/spatial.h"
#include "game/world.h"

namespace game::regions {

namespace {

bool HasPlayerAt(const entt::registry& reg, int x, int y, entt::entity ignore) {
  for (auto [e, c] : reg.view<const Cell, const Player>().each()) {
    if (e == ignore) continue;
    if (reg.all_of<Hidden>(e)) continue;
    if (c.x == x && c.y == y) return true;
  }
  return false;
}

bool CellOccupied(const entt::registry& reg, int x, int y, entt::entity ignore) {
  if (systems::HasStopAt(reg, x, y)) return true;
  if (HasPlayerAt(reg, x, y, ignore)) return true;
  for (auto [e, c] : reg.view<const Cell, const Pushable>().each()) {
    if (e == ignore) continue;
    if (reg.all_of<Hidden>(e)) continue;
    if (c.x == x && c.y == y) return true;
  }
  return false;
}

}  // namespace

void GravityLatePass(World& w) {
  auto& reg = w.Registry();
  // Iterate until stable. Process bottommost entities first so columns
  // resolve cleanly: the bottom one falls into space, freeing the cell
  // above for the next iteration. Both Pushables and Players fall —
  // the player needs gravity for the platformer feel.
  bool changed = true;
  int safety = 64;
  while (changed && safety-- > 0) {
    changed = false;
    std::vector<entt::entity> ents;
    for (auto [e, c] : reg.view<const Cell, const Pushable>().each()) {
      if (reg.all_of<Hidden>(e)) continue;
      ents.push_back(e);
    }
    for (auto e : reg.view<const Player>()) {
      if (reg.all_of<Hidden>(e)) continue;
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
