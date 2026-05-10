#pragma once

namespace game {
class World;

namespace regions {

// Late-pass gravity. Any Pushable or Player sitting on a region-2 cell
// (per the world's region map) falls one cell south unless supported by
// Stop / another Pushable / world boundary directly below. The pass
// repeats until no entity moved this tick so stacks settle in a single
// Tick boundary. Boxes on r1/r3/.../r6 cells are unaffected — that's
// what lets "push box across the r1→r2 boundary" trigger a fall in the
// original game.
//
// Idempotent and order-independent: processes the lowest entity first
// so taller stacks don't stomp on themselves while iterating.
void GravityLatePass(World& w);

}  // namespace regions
}  // namespace game
