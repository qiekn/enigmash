#include "game/regions/r5_snake.h"

#include <algorithm>
#include <entt/entt.hpp>
#include <vector>

#include "game/components.h"
#include "game/systems/spatial.h"
#include "game/world.h"

namespace game::regions {

void Snake(World& w, Direction dir) {
  if (dir == Direction::None) return;
  const int dx = DX(dir);
  const int dy = DY(dir);

  auto& reg = w.Registry();

  // Collect snake segments sorted ascending by order. The head's old
  // position becomes segment 1's new position, segment k's old becomes
  // segment k+1's new. We capture the chain BEFORE moving anything so
  // the destination check sees the current state.
  std::vector<entt::entity> segments;
  for (auto [e, s] : reg.view<SnakeSegment>().each()) {
    segments.push_back(e);
  }
  std::sort(segments.begin(), segments.end(), [&](entt::entity a, entt::entity b) {
    return reg.get<SnakeSegment>(a).order < reg.get<SnakeSegment>(b).order;
  });

  for (auto [e, c] : reg.view<Cell, Player>().each()) {
    const int tx = c.x + dx;
    const int ty = c.y + dy;
    if (!systems::InBounds(w, tx, ty)) return;
    if (systems::HasStopAt(reg, tx, ty)) return;
    // Pushables block the head — snake doesn't push in M5.
    if (systems::FindPushableAt(reg, tx, ty) != entt::null) return;

    // Capture old positions, then walk the chain head-first.
    std::vector<std::pair<int, int>> prev;
    prev.reserve(segments.size() + 1);
    prev.emplace_back(c.x, c.y);
    for (auto seg : segments) {
      const auto& sc = reg.get<Cell>(seg);
      prev.emplace_back(sc.x, sc.y);
    }
    c.x = tx;
    c.y = ty;
    for (std::size_t i = 0; i < segments.size(); ++i) {
      auto& sc = reg.get<Cell>(segments[i]);
      sc.x = prev[i].first;
      sc.y = prev[i].second;
    }
    reg.emplace_or_replace<Facing>(e, dir);
  }
}

}  // namespace game::regions
