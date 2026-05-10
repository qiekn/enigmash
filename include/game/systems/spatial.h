#pragma once

#include <entt/entt.hpp>

namespace game {
class World;

namespace systems {

// Bounds-and-cell helpers shared across region rules. Iterating the
// registry every query is O(N) per call — fine for puzzle-sized worlds
// (hundreds of entities), and avoids the bookkeeping of a separate
// spatial index that would have to stay synchronized with Cell mutations.

bool InBounds(const World& w, int x, int y);
bool HasStopAt(const entt::registry& reg, int x, int y);
entt::entity FindPushableAt(const entt::registry& reg, int x, int y);

}  // namespace systems
}  // namespace game
