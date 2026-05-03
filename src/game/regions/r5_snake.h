#pragma once

#include "game/direction.h"

namespace game {
class World;

namespace regions {

// Region 5: snake. The player moves like sokoban, but each SnakeSegment
// shifts up the chain so the body trails the head. Order=1 follows the
// head, order=k follows order=k-1. Snake bodies are Stop, so the head
// can't reverse into its own tail unless the move would otherwise free
// the cell (it never does — that's the point).
void Snake(World& w, Direction dir);

}  // namespace regions
}  // namespace game
