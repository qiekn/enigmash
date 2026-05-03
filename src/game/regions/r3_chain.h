#pragma once

#include "game/direction.h"

namespace game {
class World;

namespace regions {

// Region 3: chain-aware push. Pushables that share an edge with one
// another form a connected component (4-neighbor BFS). Pushing any one
// of them shifts the whole component — so a vertical/horizontal stack
// of boxes moves as one. Otherwise behaves like sokoban: the entire
// component must have a clear destination, blocked otherwise.
void ChainPush(World& w, Direction dir);

}  // namespace regions
}  // namespace game
