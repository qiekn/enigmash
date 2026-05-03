#include "game/regions/r1_sokoban.h"

#include <entt/entt.hpp>
#include <vector>

#include "game/components.h"
#include "game/systems/spatial.h"
#include "game/world.h"

namespace game::regions {

void Sokoban(World& w, Direction dir) {
  if (dir == Direction::None) return;
  const int dx = DX(dir);
  const int dy = DY(dir);

  auto& reg = w.Registry();
  auto players = reg.view<Player, Cell>();
  for (auto [e, c] : players.each()) {
    // Walk forward collecting any pushables in the line. Stop at the
    // first empty cell — that's where the push terminates.
    std::vector<entt::entity> chain;
    int tx = c.x + dx;
    int ty = c.y + dy;
    while (true) {
      if (!systems::InBounds(w, tx, ty) || systems::HasStopAt(reg, tx, ty)) {
        // Blocked before we even consider the chain — abort.
        return;
      }
      entt::entity box = systems::FindPushableAt(reg, tx, ty);
      if (box == entt::null) break;
      chain.push_back(box);
      tx += dx;
      ty += dy;
    }
    // Shift back-to-front so we don't trample positions while iterating.
    for (auto it = chain.rbegin(); it != chain.rend(); ++it) {
      auto& bc = reg.get<Cell>(*it);
      bc.x += dx;
      bc.y += dy;
    }
    c.x += dx;
    c.y += dy;
    reg.emplace_or_replace<Facing>(e, dir);
  }
}

}  // namespace game::regions
