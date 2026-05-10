#pragma once

#include "game/components.h"
#include "game/direction.h"

namespace game {
class World;

namespace regions {

// Find which region the player currently stands in. Returns the first
// RegionInfo whose bbox contains any Player entity's Cell, or
// Region::None if none match (e.g. player is between regions).
Region RegionUnderPlayer(const World& w);

// Find which region governs an arbitrary cell. Used by global late
// passes (gravity, etc.) that need to act on entities sitting in their
// home region regardless of where the player currently stands.
Region RegionAt(const World& w, int x, int y);

// Run the per-tick region rules. Picks the right early-pass push rule
// for the region kind, then any shared late passes (gravity for the
// regions that need it). `shoot` is forwarded to region 4; ignored
// elsewhere. No-op when dir == None and the region has no passive late
// pass that fires every tick.
void Tick(World& w, Region kind, Direction dir, bool shoot = false);

}  // namespace regions
}  // namespace game
