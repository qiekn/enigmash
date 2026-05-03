#pragma once

#include "game/direction.h"

namespace game {
class World;

namespace regions {

// Region 4: shoot. Walking is plain sokoban. Pressing the shoot key
// scans forward in the player's Facing direction; the first Pushable
// in line is nudged one cell in that direction (if its destination is
// clear). Stops and out-of-bounds cells short-circuit the scan.
//
// `dir` is the movement direction for this tick (None to stand still).
// `shoot` requests a kick; when true, the kick uses Facing, not `dir`,
// so you can fire while standing.
void Shoot(World& w, Direction dir, bool shoot);

}  // namespace regions
}  // namespace game
