#pragma once

namespace game {
class World;

namespace systems {

// Swaps each generic Pushable's Sprite atlas slot to match the per-region
// Thing visual (thingone .. thingsix). The original PuzzleScript paints
// these onto the bare `o` object via late visual rules, so a box pushed
// across a region boundary should change look — e.g. an r1 crate falls
// into r2 and reads as a rock. Skips Linked entities (r6 cluster members
// keep their distinct sprite, since their identity is the cluster).
void PatchBoxSprite(World& w);

}  // namespace systems
}  // namespace game
