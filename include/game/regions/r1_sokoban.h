#pragma once

#include "game/direction.h"

namespace game {
class World;

namespace regions {

// Region 1: classic sokoban. The player walks; pushable boxes shift one
// cell ahead in the same direction so long as the cell at the end of the
// chain is empty. Stops and out-of-bounds block the entire push.
//
// Run once per tick when InputThrottle yields a direction. Mutates Cell
// for the player and any boxes in the chain; VisualXY catches up via
// RenderInterp. No-op when dir == Direction::None.
void Sokoban(World& w, Direction dir);

}  // namespace regions
}  // namespace game
