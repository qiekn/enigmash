#pragma once

namespace game {
class World;

namespace systems {

// Swaps the player's Sprite atlas slot to match the per-region body
// (player_one .. player_six). Called every tick after the region rules
// run; cheap because there's typically a single Player entity. If the
// player is between regions (Region::None), the sprite is left alone
// rather than reverting to the generic placeholder — that flicker
// would be noisier than the stale frame.
void PatchPlayerSprite(World& w);

}  // namespace systems
}  // namespace game
