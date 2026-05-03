#include "game/systems/render_interp.h"

#include "game/components.h"
#include "game/world.h"

namespace game::systems {

namespace {
constexpr float kStiffness = 180.0f;
constexpr float kDamping   = 22.0f;
// Cap dt so a long stall (alt-tab) doesn't catapult VisualXY past Cell.
constexpr float kMaxDt = 1.0f / 30.0f;
}  // namespace

void RenderInterp(World& w, float dt) {
  if (dt > kMaxDt) dt = kMaxDt;
  auto& reg = w.Registry();
  auto view = reg.view<const Cell, VisualXY>();
  for (auto [e, c, v] : view.each()) {
    const float tx = (float)(c.x * kTilePx);
    const float ty = (float)(c.y * kTilePx);
    const float dx = tx - v.x;
    const float dy = ty - v.y;
    const float fx = kStiffness * dx - kDamping * v.vx;
    const float fy = kStiffness * dy - kDamping * v.vy;
    v.vx += fx * dt;
    v.vy += fy * dt;
    v.x  += v.vx * dt;
    v.y  += v.vy * dt;
  }
}

}  // namespace game::systems
