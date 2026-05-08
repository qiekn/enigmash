#include "game/regions/r4_shoot.h"

#include <entt/entt.hpp>

#include "game/audio.h"
#include "game/components.h"
#include "game/systems/spatial.h"
#include "game/world.h"

namespace game::regions {

namespace {

// Slide a single box as far as it can go in (dx, dy). When the slide
// hits another Pushable, momentum transfers: the kicked box stops one
// cell behind (where it was just before contact) and we recurse into
// the contacted box so it starts sliding too. Walls and OOB just stop
// the slide.
void SlideOne(World& w, entt::registry& reg, entt::entity box, int dx, int dy) {
  auto& bc = reg.get<Cell>(box);
  int x = bc.x;
  int y = bc.y;
  while (true) {
    const int nx = x + dx;
    const int ny = y + dy;
    if (!systems::InBounds(w, nx, ny)) break;
    if (systems::HasStopAt(reg, nx, ny)) break;
    entt::entity next = systems::FindPushableAt(reg, nx, ny);
    if (next != entt::null) {
      bc.x = x;
      bc.y = y;
      SlideOne(w, reg, next, dx, dy);
      return;
    }
    x = nx;
    y = ny;
  }
  bc.x = x;
  bc.y = y;
}

}  // namespace

void Shoot(World& w, Direction dir, bool /*shoot*/) {
  if (dir == Direction::None) return;
  const int dx = DX(dir);
  const int dy = DY(dir);

  auto& reg = w.Registry();
  for (auto [pe, pc] : reg.view<Player, Cell>().each()) {
    const int tx = pc.x + dx;
    const int ty = pc.y + dy;
    if (!systems::InBounds(w, tx, ty) || systems::HasStopAt(reg, tx, ty)) return;

    entt::entity box = systems::FindPushableAt(reg, tx, ty);
    if (box != entt::null) {
      SlideOne(w, reg, box, dx, dy);
      // If the box couldn't move at all (wall right behind it, jammed
      // chain, etc.) the player is blocked too — don't trample it.
      const auto& bc = reg.get<Cell>(box);
      if (bc.x == tx && bc.y == ty) return;
      audio::Play(audio::Sfx::R4Push);
    }
    pc.x = tx;
    pc.y = ty;
    reg.emplace_or_replace<Facing>(pe, dir);
  }
}

}  // namespace game::regions
