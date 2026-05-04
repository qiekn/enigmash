#pragma once

#include "game/direction.h"

namespace game {
class World;

namespace regions {

// Region 4: billiards. Pushing a Pushable kicks it sliding in the push
// direction until it hits an obstacle. If the obstacle is another
// Pushable, momentum transfers — the kicked one stops one cell behind
// and the contacted one starts sliding (Newton's cradle). The player
// advances exactly one cell into the freed space.
//
// `dir` is the move direction this tick. The legacy `shoot` parameter
// is now ignored — the slide IS the kick, no separate trigger.
void Shoot(World& w, Direction dir, bool shoot);

}  // namespace regions
}  // namespace game
