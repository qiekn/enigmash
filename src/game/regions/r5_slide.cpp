#include "game/regions/r5_slide.h"

#include <entt/entt.hpp>
#include <vector>

#include "game/components.h"
#include "game/regions/r1_sokoban.h"
#include "game/systems/spatial.h"
#include "game/world.h"

namespace game::regions {

namespace {

// Returns the conveyor direction at (x, y), or Direction::None if no
// (visible) Conveyor sits there.
Direction ConveyorAt(const entt::registry& reg, int x, int y) {
  for (auto [e, c, cv] : reg.view<const Cell, const Conveyor>().each()) {
    if (reg.all_of<Hidden>(e)) continue;
    if (c.x == x && c.y == y) return cv.dir;
  }
  return Direction::None;
}

bool HasOtherPlayerAt(const entt::registry& reg, int x, int y, entt::entity ignore) {
  for (auto [e, c] : reg.view<const Cell, const Player>().each()) {
    if (e == ignore) continue;
    if (reg.all_of<Hidden>(e)) continue;
    if (c.x == x && c.y == y) return true;
  }
  return false;
}

// Try to shift a single entity one cell in (dx, dy). Returns true on
// success. Pushables / Stops / other players block.
bool ShiftOne(World& w, entt::registry& reg, entt::entity e, int dx, int dy) {
  auto& c = reg.get<Cell>(e);
  const int nx = c.x + dx;
  const int ny = c.y + dy;
  if (!systems::InBounds(w, nx, ny)) return false;
  if (systems::HasStopAt(reg, nx, ny)) return false;
  if (systems::FindPushableAt(reg, nx, ny) != entt::null) return false;
  if (HasOtherPlayerAt(reg, nx, ny, e)) return false;
  c.x = nx;
  c.y = ny;
  return true;
}

}  // namespace

void Slide(World& w, Direction dir) {
  // Player input still resolves as a normal sokoban push.
  Sokoban(w, dir);

  auto& reg = w.Registry();

  // Late pass: shove every entity standing on a conveyor in that
  // conveyor's direction. Iterate until stable so a row of conveyors
  // can carry an entity multiple cells.
  bool changed = true;
  int safety = 64;
  while (changed && safety-- > 0) {
    changed = false;

    std::vector<entt::entity> ents;
    for (auto e : reg.view<Player>()) {
      if (reg.all_of<Hidden>(e)) continue;
      ents.push_back(e);
    }
    for (auto e : reg.view<Pushable>()) {
      if (reg.all_of<Hidden>(e)) continue;
      ents.push_back(e);
    }

    for (auto e : ents) {
      auto* c = reg.try_get<Cell>(e);
      if (c == nullptr) continue;
      const Direction cv = ConveyorAt(reg, c->x, c->y);
      if (cv == Direction::None) continue;
      const int dx = DX(cv);
      const int dy = DY(cv);
      if (ShiftOne(w, reg, e, dx, dy)) changed = true;
    }
  }
}

}  // namespace game::regions
