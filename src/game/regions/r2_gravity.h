#pragma once

namespace game {
class World;

namespace regions {

// Late-pass gravity. Any Pushable not supported by Stop / another
// Pushable / world boundary directly below it falls one cell south. The
// pass repeats until no entity moved this tick — so a stack settles in
// one Tick boundary regardless of height. Player is *not* affected.
//
// Idempotent and order-independent: processes the lowest entity first
// so taller stacks don't stomp on themselves while iterating.
void GravityLatePass(World& w);

}  // namespace regions
}  // namespace game
