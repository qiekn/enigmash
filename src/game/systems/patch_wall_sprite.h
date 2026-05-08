#pragma once

namespace game {
class World;

namespace systems {

// Re-skins each wall (Stop) entity based on the regions of its 4-neighbour
// floors so the seam between two regions reads visually. Mirrors the
// PuzzleScript late-rules block that paints walltwo / wallthree / etc.
// onto plain `wall` cells: a wall touching r2 floor becomes `walltwo`,
// touching r3 becomes `wallthree`, and so on. For r2 specifically, picks
// a directional variant (walltwoup/down/left/right) when only one face
// of the wall is exposed to r2 floor — matches the original's edge trim.
//
// Walls don't move, so this only needs to run on world load (or after
// hot-reload / Hidden-toggle changes the topology).
void PatchWallSprite(World& w);

}  // namespace systems
}  // namespace game
