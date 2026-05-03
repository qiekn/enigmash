#include "game/input.h"

#include <raylib.h>

namespace game {

namespace {
constexpr float kFirstRepeatDelay = 0.20f;  // PS-classic "200 ms initial repeat"
constexpr float kRepeatDelay      = 0.10f;  // then 100 ms per repeat
}  // namespace

Direction InputThrottle::ReadDir() {
  // Letter aliases are ignored when an ImGui input field is focused —
  // ImGui swallows the key event before raylib sees IsKeyDown becoming
  // true, which is exactly the behavior we want for the editor.
  if (IsKeyDown(KEY_UP)    || IsKeyDown(KEY_W) || IsKeyDown(KEY_K)) return Direction::North;
  if (IsKeyDown(KEY_DOWN)  || IsKeyDown(KEY_S) || IsKeyDown(KEY_J)) return Direction::South;
  if (IsKeyDown(KEY_LEFT)  || IsKeyDown(KEY_A) || IsKeyDown(KEY_H)) return Direction::West;
  if (IsKeyDown(KEY_RIGHT) || IsKeyDown(KEY_D) || IsKeyDown(KEY_L)) return Direction::East;
  return Direction::None;
}

Direction InputThrottle::Poll(float dt) {
  const Direction d = ReadDir();

  if (d == Direction::None) {
    last_dir_ = Direction::None;
    held_time_ = 0.0f;
    repeats_ = 0;
    return Direction::None;
  }

  if (d != last_dir_) {
    last_dir_ = d;
    held_time_ = 0.0f;
    repeats_ = 0;
    return d;  // immediate fire on direction change / first press
  }

  held_time_ += dt;
  const float threshold = (repeats_ == 0) ? kFirstRepeatDelay : kRepeatDelay;
  if (held_time_ >= threshold) {
    held_time_ = 0.0f;
    ++repeats_;
    return d;
  }
  return Direction::None;
}

}  // namespace game
