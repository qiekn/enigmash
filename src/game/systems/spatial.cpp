#include "game/systems/spatial.h"

#include "game/components.h"
#include "game/world.h"

namespace game::systems {

bool InBounds(const World& w, int x, int y) {
  const auto b = w.GetBounds();
  return x >= b.min_x && x < b.max_x && y >= b.min_y && y < b.max_y;
}

bool HasStopAt(const entt::registry& reg, int x, int y) {
  for (auto [e, c] : reg.view<const Cell, const Stop>().each()) {
    if (reg.all_of<Hidden>(e)) continue;
    if (c.x == x && c.y == y) return true;
  }
  return false;
}

entt::entity FindPushableAt(const entt::registry& reg, int x, int y) {
  for (auto [e, c] : reg.view<const Cell, const Pushable>().each()) {
    if (reg.all_of<Hidden>(e)) continue;
    if (c.x == x && c.y == y) return e;
  }
  return entt::null;
}

}  // namespace game::systems
