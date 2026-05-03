#include "game/regions/r4_shoot.h"

#include <entt/entt.hpp>

#include "game/components.h"
#include "game/regions/r1_sokoban.h"
#include "game/systems/spatial.h"
#include "game/world.h"

namespace game::regions {

void Shoot(World& w, Direction dir, bool shoot) {
  // Walking still uses sokoban so the basic feel matches r1.
  Sokoban(w, dir);

  if (!shoot) return;
  auto& reg = w.Registry();
  for (auto [e, c, f] : reg.view<Cell, Player, Facing>().each()) {
    const Direction fdir = f.dir;
    if (fdir == Direction::None) return;
    const int dx = DX(fdir);
    const int dy = DY(fdir);

    int x = c.x + dx;
    int y = c.y + dy;
    while (systems::InBounds(w, x, y) && !systems::HasStopAt(reg, x, y)) {
      entt::entity box = systems::FindPushableAt(reg, x, y);
      if (box != entt::null) {
        const int tx = x + dx;
        const int ty = y + dy;
        if (systems::InBounds(w, tx, ty)
            && !systems::HasStopAt(reg, tx, ty)
            && systems::FindPushableAt(reg, tx, ty) == entt::null) {
          auto& bc = reg.get<Cell>(box);
          bc.x = tx;
          bc.y = ty;
        }
        return;  // one box per shot, hit or miss
      }
      x += dx;
      y += dy;
    }
  }
}

}  // namespace game::regions
