#include "game/regions/r3_chain.h"

#include <entt/entt.hpp>
#include <queue>
#include <unordered_map>
#include <vector>

#include "game/components.h"
#include "game/systems/spatial.h"
#include "game/world.h"

namespace game::regions {

namespace {

// 64-bit packed (x, y) — keeps the connectivity hash fast without the
// std::pair / unordered_map<pair<int,int>, ...> hash boilerplate.
inline uint64_t Key(int x, int y) {
  return (uint64_t)(uint32_t)x | ((uint64_t)(uint32_t)y << 32);
}

// BFS from `seed` over 4-connected Pushables, collecting them all. The
// returned set IS the chain that will move together this tick.
std::vector<entt::entity> ChainAround(const entt::registry& reg, entt::entity seed) {
  // Index pushables by cell so the BFS is constant-time per neighbor.
  std::unordered_map<uint64_t, entt::entity> by_cell;
  for (auto [e, c] : reg.view<const Cell, const Pushable>().each()) {
    by_cell[Key(c.x, c.y)] = e;
  }

  std::vector<entt::entity> out;
  std::queue<entt::entity> q;
  std::unordered_map<entt::entity, bool> seen;
  q.push(seed);
  seen[seed] = true;

  while (!q.empty()) {
    auto e = q.front(); q.pop();
    out.push_back(e);
    const auto& c = reg.get<Cell>(e);
    constexpr int kDx[4] = {1, -1, 0, 0};
    constexpr int kDy[4] = {0, 0, 1, -1};
    for (int i = 0; i < 4; ++i) {
      auto it = by_cell.find(Key(c.x + kDx[i], c.y + kDy[i]));
      if (it == by_cell.end()) continue;
      if (seen[it->second]) continue;
      seen[it->second] = true;
      q.push(it->second);
    }
  }
  return out;
}

}  // namespace

void ChainPush(World& w, Direction dir) {
  if (dir == Direction::None) return;
  const int dx = DX(dir);
  const int dy = DY(dir);

  auto& reg = w.Registry();
  for (auto [e, c] : reg.view<Player, Cell>().each()) {
    const int tx = c.x + dx;
    const int ty = c.y + dy;
    if (!systems::InBounds(w, tx, ty) || systems::HasStopAt(reg, tx, ty)) return;

    entt::entity touched = systems::FindPushableAt(reg, tx, ty);
    if (touched == entt::null) {
      c.x += dx;
      c.y += dy;
      reg.emplace_or_replace<Facing>(e, dir);
      return;
    }
    // The whole connected component must have somewhere to go. Build a
    // set of source cells, then verify each box's destination is either
    // empty or part of the same chain (so internal moves are fine).
    auto chain = ChainAround(reg, touched);
    std::unordered_map<uint64_t, bool> chain_cells;
    for (auto b : chain) {
      const auto& bc = reg.get<Cell>(b);
      chain_cells[Key(bc.x, bc.y)] = true;
    }
    for (auto b : chain) {
      const auto& bc = reg.get<Cell>(b);
      const int dx2 = bc.x + dx;
      const int dy2 = bc.y + dy;
      if (!systems::InBounds(w, dx2, dy2)) return;
      if (systems::HasStopAt(reg, dx2, dy2)) return;
      if (chain_cells.count(Key(dx2, dy2))) continue;        // moves into another chain member
      if (systems::FindPushableAt(reg, dx2, dy2) != entt::null) return;  // blocked by an outsider
    }
    for (auto b : chain) {
      auto& bc = reg.get<Cell>(b);
      bc.x += dx;
      bc.y += dy;
    }
    c.x += dx;
    c.y += dy;
    reg.emplace_or_replace<Facing>(e, dir);
  }
}

}  // namespace game::regions
