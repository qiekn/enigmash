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

// Run the per-tick region rules. Picks the right early-pass push rule
// for the region kind, then any shared late passes (gravity for the
// regions that need it). No-op when dir == None and the region has no
// passive late pass that fires every tick.
void Tick(World& w, Region kind, Direction dir);

}  // namespace regions
}  // namespace game
