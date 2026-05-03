#pragma once

#include "game/direction.h"

namespace game {
class World;

namespace regions {

// Region 6: linked clusters. Pushables tagged Linked{head} all move
// together when any one is shoved. Group membership is by Linked::head:
// every member with the same head is one cluster. Like r3_chain but
// connectivity is *declared* (in object catalog) rather than *spatial*,
// so non-adjacent boxes can still be one rigid body.
void Cluster(World& w, Direction dir);

}  // namespace regions
}  // namespace game
