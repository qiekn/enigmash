#include "game/regions/r1_sokoban.h"

#include <entt/entt.hpp>
#include <vector>

#include "game/components.h"
#include "game/world.h"

namespace game::regions {

namespace {

bool InBounds(const World& w, int x, int y) {
  const auto b = w.GetBounds();
  return x >= b.min_x && x < b.max_x && y >= b.min_y && y < b.max_y;
}

bool HasStopAt(const entt::registry& reg, int x, int y) {
  for (auto [e, c] : reg.view<const Cell, const Stop>().each()) {
    if (c.x == x && c.y == y) return true;
  }
  return false;
}

entt::entity FindPushableAt(const entt::registry& reg, int x, int y) {
  for (auto [e, c] : reg.view<const Cell, const Pushable>().each()) {
    if (c.x == x && c.y == y) return e;
  }
  return entt::null;
}

}  // namespace

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
      if (!InBounds(w, tx, ty) || HasStopAt(reg, tx, ty)) {
        // Blocked before we even consider the chain — abort.
        chain.clear();
        return;
      }
      entt::entity box = FindPushableAt(reg, tx, ty);
      if (box == entt::null) break;
      chain.push_back(box);
      tx += dx;
      ty += dy;
    }
    // (tx, ty) is the cell *past* the last box in the chain (or the
    // player's destination if no boxes). Already known to be in-bounds
    // and not Stop from the loop above.
    //
    // Shift back-to-front so we don't trample positions while iterating.
    for (auto it = chain.rbegin(); it != chain.rend(); ++it) {
      auto& bc = reg.get<Cell>(*it);
      bc.x += dx;
      bc.y += dy;
    }
    c.x += dx;
    c.y += dy;
  }
}

}  // namespace game::regions
