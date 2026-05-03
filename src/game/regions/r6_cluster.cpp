#include "game/regions/r6_cluster.h"

#include <cstdint>
#include <entt/entt.hpp>
#include <unordered_set>
#include <vector>

#include "game/components.h"
#include "game/systems/spatial.h"
#include "game/world.h"

namespace game::regions {

namespace {

inline uint64_t Key(int x, int y) {
  return (uint64_t)(uint32_t)x | ((uint64_t)(uint32_t)y << 32);
}

// Gather all Linked members sharing the same head as `seed`. If `seed`
// has no Linked component, returns just {seed} so callers can treat
// unlinked pushables uniformly.
std::vector<entt::entity> SameCluster(const entt::registry& reg, entt::entity seed) {
  std::vector<entt::entity> out;
  if (!reg.all_of<Linked>(seed)) {
    out.push_back(seed);
    return out;
  }
  const entt::entity head = reg.get<Linked>(seed).head;
  for (auto [e, l] : reg.view<const Linked>().each()) {
    if (l.head == head) out.push_back(e);
  }
  return out;
}

}  // namespace

void Cluster(World& w, Direction dir) {
  if (dir == Direction::None) return;
  const int dx = DX(dir);
  const int dy = DY(dir);

  auto& reg = w.Registry();
  for (auto [pe, c] : reg.view<Player, Cell>().each()) {
    const int tx = c.x + dx;
    const int ty = c.y + dy;
    if (!systems::InBounds(w, tx, ty) || systems::HasStopAt(reg, tx, ty)) return;

    entt::entity touched = systems::FindPushableAt(reg, tx, ty);
    if (touched == entt::null) {
      c.x += dx;
      c.y += dy;
      reg.emplace_or_replace<Facing>(pe, dir);
      return;
    }

    // Whole cluster must be free to shift. A box's destination is OK
    // if it's empty OR if it's currently another cluster member's
    // source cell (those move out of the way this same tick).
    auto cluster = SameCluster(reg, touched);
    std::unordered_set<uint64_t> source_cells;
    for (auto b : cluster) {
      const auto& bc = reg.get<Cell>(b);
      source_cells.insert(Key(bc.x, bc.y));
    }
    for (auto b : cluster) {
      const auto& bc = reg.get<Cell>(b);
      const int nx = bc.x + dx;
      const int ny = bc.y + dy;
      if (!systems::InBounds(w, nx, ny)) return;
      if (systems::HasStopAt(reg, nx, ny)) return;
      if (source_cells.count(Key(nx, ny))) continue;
      if (systems::FindPushableAt(reg, nx, ny) != entt::null) return;
    }
    for (auto b : cluster) {
      auto& bc = reg.get<Cell>(b);
      bc.x += dx;
      bc.y += dy;
    }
    c.x += dx;
    c.y += dy;
    reg.emplace_or_replace<Facing>(pe, dir);
  }
}

}  // namespace game::regions
