#include "game/systems/toggle_swap.h"

#include <cstdlib>
#include <entt/entt.hpp>
#include <vector>

#include "game/audio.h"
#include "game/components.h"
#include "game/world.h"

namespace game::systems {

void ToggleSwap(World& w) {
  auto& reg = w.Registry();

  for (auto [pe, pc, lt] : reg.view<Cell, Player, LastToggle>().each()) {
    // Find a toggle at the player's current cell. Hidden toggles don't
    // count — they're disabled until something un-hides them.
    entt::entity stepped = entt::null;
    uint8_t radius = 0;
    for (auto [te, tc, t] : reg.view<Cell, Toggle>().each()) {
      if (reg.all_of<Hidden>(te)) continue;
      if (tc.x == pc.x && tc.y == pc.y) {
        stepped = te;
        radius = t.radius;
        break;
      }
    }
    if (stepped == entt::null) {
      lt.ent = entt::null;  // walked off — re-arm for next entry
      continue;
    }
    if (stepped == lt.ent) continue;  // same toggle, already fired
    lt.ent = stepped;

    // Flip Hidden on every Toggleable within radius (Manhattan).
    std::vector<entt::entity> to_show;
    std::vector<entt::entity> to_hide;
    for (auto [e, c] : reg.view<Cell, Toggleable>().each()) {
      const int dx = std::abs(c.x - pc.x);
      const int dy = std::abs(c.y - pc.y);
      if (dx + dy > radius) continue;
      if (reg.all_of<Hidden>(e)) to_show.push_back(e);
      else to_hide.push_back(e);
    }
    for (auto e : to_show) reg.remove<Hidden>(e);
    for (auto e : to_hide) reg.emplace<Hidden>(e);
    if (!to_show.empty() || !to_hide.empty()) audio::Play(audio::Sfx::ToggleSwap);
  }
}

}  // namespace game::systems
