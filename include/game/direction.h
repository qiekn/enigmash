#pragma once

#include <cstdint>

namespace game {

// 4-way orthogonal direction. None is the canonical "no move this tick"
// value; systems treat it as a no-op rather than a sentinel error.
enum class Direction : uint8_t {
  None = 0,
  North,
  South,
  East,
  West,
};

constexpr int DX(Direction d) {
  return d == Direction::East ? 1 : d == Direction::West ? -1 : 0;
}

constexpr int DY(Direction d) {
  return d == Direction::South ? 1 : d == Direction::North ? -1 : 0;
}

}  // namespace game
