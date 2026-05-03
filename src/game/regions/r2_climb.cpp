#include "game/regions/r2_climb.h"

#include <entt/entt.hpp>
#include <vector>

#include "game/components.h"
#include "game/systems/spatial.h"
#include "game/world.h"

namespace game::regions {

namespace {

// Walks a sokoban chain from `(pc.x + dx, pc.y)` along (dx, 0). On
// success, shifts every box and the player one cell. Returns false
// without mutating state if blocked by Stop or out-of-bounds; the
// caller decides whether to climb instead.
bool TryPushAndStep(World& w, Cell& pc, int dx) {
  auto& reg = w.Registry();
  std::vector<entt::entity> chain;
  int tx = pc.x + dx;
  const int ty = pc.y;
  while (true) {
    if (!systems::InBounds(w, tx, ty) || systems::HasStopAt(reg, tx, ty)) {
      return false;
    }
    entt::entity box = systems::FindPushableAt(reg, tx, ty);
    if (box == entt::null) break;
    chain.push_back(box);
    tx += dx;
  }
  for (auto it = chain.rbegin(); it != chain.rend(); ++it) {
    auto& bc = reg.get<Cell>(*it);
    bc.x += dx;
  }
  pc.x += dx;
  return true;
}

}  // namespace

void Climb(World& w, Direction dir) {
  if (dir != Direction::East && dir != Direction::West) return;
  const int dx = DX(dir);
  auto& reg = w.Registry();

  for (auto [pe, pc] : reg.view<Player, Cell>().each()) {
    if (TryPushAndStep(w, pc, dx)) {
      reg.emplace_or_replace<Facing>(pe, dir);
      return;
    }

    // Push failed — the cell directly ahead of the player is the
    // obstacle. Try to climb onto it. The cell above the obstacle
    // must be empty (in bounds, no Stop, no Pushable, no Player).
    const int bx = pc.x + dx;
    const int by = pc.y;
    if (!systems::InBounds(w, bx, by)) return;
    const bool obstacle =
        systems::HasStopAt(reg, bx, by) ||
        systems::FindPushableAt(reg, bx, by) != entt::null;
    if (!obstacle) return;
    const int cx = bx;
    const int cy = by - 1;
    if (!systems::InBounds(w, cx, cy)) return;
    if (systems::HasStopAt(reg, cx, cy)) return;
    if (systems::FindPushableAt(reg, cx, cy) != entt::null) return;

    pc.x = cx;
    pc.y = cy;
    reg.emplace_or_replace<Facing>(pe, dir);
  }
}

}  // namespace game::regions
