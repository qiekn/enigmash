#pragma once

namespace game {
class World;

namespace systems {

// Smoothly interpolates VisualXY toward (Cell.x*kTilePx, Cell.y*kTilePx)
// using a critically-tuned spring (stiffness 180, damping 22). Run once
// per RENDER frame, not per logic tick — the spring is what makes ticky
// movement feel continuous.
void RenderInterp(World& w, float dt);

}  // namespace systems
}  // namespace game
