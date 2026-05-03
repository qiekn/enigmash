#pragma once

#include <cstdint>
#include <entt/entt.hpp>

#include "game/direction.h"

namespace game {

// -----------------------------------------------------------------------------: spatial
//
// `Cell` is the logical (integer) position — the source of truth for
// gameplay rules. `VisualXY` is the renderer's lerp target; spring physics
// chase Cell every frame so movement looks fluid even though the rules
// snap on each tick.
//
// Naming follows Balatro's T / VT split (Transform / Visual Transform).
struct Cell {
  int x;
  int y;
};

struct VisualXY {
  float x;
  float y;
  float vx;
  float vy;
};

struct Move {
  Direction dir;
};

struct ZOrder {
  int8_t layer;
};

// Index into the SpriteCache. Resolved via cache->Get(atlas_id).
struct Sprite {
  uint32_t atlas_id;
};

// -----------------------------------------------------------------------------: behavior tags

struct Player {};
struct Pushable {};

// Player's last successful move direction. Used by region 4 (shoot) to
// pick a facing for the projectile, and by future render passes for
// directional sprites. Defaults to South for a freshly-spawned player.
struct Facing {
  Direction dir;
};

// Tail body for region 5. order==1 follows the head, order==2 follows
// order 1, etc. Snake segments are also Stop so the head can't walk
// through its own tail.
struct SnakeSegment {
  uint8_t order;
};

// "Stop" instead of "Wall" — the term covers any obstacle that blocks
// movement, matching Baba Is You's vocabulary. Less ambiguous than Wall
// once we add doors / one-way panels / clusters.
struct Stop {};
struct StopDir {
  Direction blocks;
};

struct Toggle {
  uint8_t radius;
};

// Entities with this tag are eligible to be flipped between visible and
// hidden by the ToggleSwap system. Pair with Stop / Pushable to make
// the entity matter mechanically; render_tiles ignores Hidden ones.
struct Toggleable {};

// Visibility flag — when present, entity is treated as if it doesn't
// exist by render and by the spatial helpers (HasStopAt skips it,
// FindPushableAt skips it). Toggleable swaps add/remove this tag.
struct Hidden {};

// Player-side memo: the last Toggle entity that fired for this player.
// Prevents the toggle from firing every tick while the player stands
// on it — only on entry / re-entry. Defaults to entt::null on spawn.
struct LastToggle {
  entt::entity ent = entt::null;
};

struct Checkpoint {};
struct Goal {};

enum class Region : uint8_t {
  None = 0,
  R1Sokoban,
  R2Climb,
  R3Chain,
  R4Shoot,
  R5Snake,
  R6Cluster,
};

struct Background {
  Region region;
};

struct Linked {
  entt::entity head;
};

// Late-pass tag set by region 3 once the supports-resolution sweep
// finishes; cleared at tick start.
struct Supported {};

}  // namespace game
