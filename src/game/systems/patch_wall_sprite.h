#pragma once

namespace game {
class World;

namespace systems {

// Spawns a decorative trim entity above each wall that borders r2..r5
// floor cells, mirroring PuzzleScript's late-rule visuals. The original
// wall keeps its base sprite (wallone); the decal stacks on top in the
// renderer thanks to stable_sort + same-layer ordering. For r2 the trim
// is directional (walltwoup/down/left/right) based on which face is
// exposed to r2 floor. Walls don't move and decals never get cleaned up
// individually — they belong to the World's lifetime, replaced when
// ReloadFromJson rebuilds the registry.
void PatchWallSprite(World& w);

}  // namespace systems
}  // namespace game
