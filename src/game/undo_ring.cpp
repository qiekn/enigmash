#include "game/undo_ring.h"

#include "game/components.h"

namespace game {

void UndoRing::Push(const entt::registry& reg) {
  Frame& f = ring_[head_];
  f.xs.clear();
  f.ys.clear();
  auto view = reg.view<const Cell>();
  f.xs.reserve(view.size());
  f.ys.reserve(view.size());
  for (auto [e, c] : view.each()) {
    f.xs.emplace_back(e, c.x);
    f.ys.push_back(c.y);
  }
  head_ = (head_ + 1) % kCapacity;
  if (size_ < kCapacity) ++size_;
}

bool UndoRing::Pop(entt::registry& reg) {
  if (size_ == 0) return false;
  head_ = (head_ + kCapacity - 1) % kCapacity;
  --size_;
  const Frame& f = ring_[head_];
  for (std::size_t i = 0; i < f.xs.size(); ++i) {
    const entt::entity e = f.xs[i].first;
    if (!reg.valid(e) || !reg.all_of<Cell>(e)) continue;
    auto& c = reg.get<Cell>(e);
    c.x = f.xs[i].second;
    c.y = f.ys[i];
  }
  return true;
}

void UndoRing::Clear() {
  for (auto& f : ring_) {
    f.xs.clear();
    f.ys.clear();
  }
  head_ = 0;
  size_ = 0;
}

}  // namespace game
