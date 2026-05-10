#pragma once

#include <array>
#include <cstddef>
#include <entt/entt.hpp>
#include <vector>

namespace game {

struct Cell;

// Fixed-capacity circular history of registry Cell snapshots. Region
// rules only mutate Cell on the entities they spawned at world load —
// no entity is created or destroyed mid-game — so a Cell-only snapshot
// is enough to round-trip a tick perfectly.
//
// Capacity is fixed at 256: that's the budget the plan called for, and
// at ~16 bytes per entry per entity (entity_id + Cell) a 1 000-entity
// world spends ~4 MB on the entire history — fine for desktop.
class UndoRing {
 public:
  static constexpr std::size_t kCapacity = 256;

  // Snap the current Cell state of every entity in `reg` into the next
  // ring slot. Wraps around once full, dropping the oldest entry.
  void Push(const entt::registry& reg);

  // Restore the latest pushed snapshot into `reg` and remove it. No-op
  // (returns false) when the ring is empty.
  bool Pop(entt::registry& reg);

  // Reset to empty. Use when transitioning between worlds.
  void Clear();

  std::size_t Size() const { return size_; }
  bool Empty() const { return size_ == 0; }

 private:
  struct Frame {
    std::vector<std::pair<entt::entity, int>> xs;  // entity -> Cell.x
    std::vector<int> ys;                            // parallel; Cell.y
  };

  std::array<Frame, kCapacity> ring_;
  std::size_t head_ = 0;   // next write
  std::size_t size_ = 0;
};

}  // namespace game
