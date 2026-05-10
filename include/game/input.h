#pragma once

#include "game/direction.h"

namespace game {

// Maps held-down arrows / WASD / HJKL into discrete ticks. Mirrors the
// PuzzleScript timing config: first press fires immediately, then a 200 ms
// gap before the first auto-repeat, then 100 ms per repeat thereafter.
//
// Diagonals are not supported — if the player holds two perpendicular
// directions, North/South wins over East/West and arrow keys win over
// the letter aliases. Releasing all direction keys resets the throttle.
class InputThrottle {
 public:
  // Read the current frame's input and advance internal timers. Returns
  // a Direction the gameplay layer should consume this frame, or
  // Direction::None when no tick should fire.
  Direction Poll(float dt);

  // Read the raw direction key state without affecting timers. Useful
  // for editor / debug overlays that want to mirror the held key.
  static Direction ReadDir();

 private:
  Direction last_dir_ = Direction::None;
  float held_time_ = 0.0f;
  int repeats_ = 0;
};

}  // namespace game
