#pragma once

namespace game {
class World;

namespace systems {

// Triggers Toggle entities the player has just stepped onto. A toggle
// flips the Hidden state of every Toggleable entity within Manhattan
// distance ≤ Toggle::radius — same idea as the original's "swap"
// markers cascading outward, just resolved synchronously.
//
// Fire-on-edge: each Player tracks the last toggle it triggered (via
// the LastToggle component), so standing on a toggle for many ticks
// only flips once. Walking off and back on re-fires.
//
// Run after the region tick so the Cell write from movement has
// already landed.
void ToggleSwap(World& w);

}  // namespace systems
}  // namespace game
