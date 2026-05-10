#pragma once

#include "game/direction.h"

namespace game {
class World;

namespace regions {

// Region 2: side-scroller with climbing. Horizontal input first tries
// a sokoban-style push (single cell along the chain). If the push
// fails — i.e. the chain hits a Stop or the world boundary — the
// player tries to climb up onto the immediate obstacle: target cell
// `(player.x + dx, player.y - 1)` must be in bounds and unobstructed.
//
// Vertical input is ignored; up/down movement happens only via climb
// and the late-pass gravity (which also pulls the player down).
void Climb(World& w, Direction dir);

}  // namespace regions
}  // namespace game
