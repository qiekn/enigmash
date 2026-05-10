#pragma once

#include "game/direction.h"

namespace game {
class World;

namespace regions {

// Region 5: directional conveyor. The player walks normally (sokoban
// single-cell push). After the move resolves, every Player and
// Pushable standing on a Conveyor cell is shoved one tile along that
// conveyor's direction — repeating until everyone is off-conveyor or
// blocked. Net result: the floor "carries" you.
void Slide(World& w, Direction dir);

}  // namespace regions
}  // namespace game
