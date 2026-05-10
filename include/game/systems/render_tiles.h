#pragma once

#include <raylib.h>

namespace game {

class World;

namespace systems {

// Walks Cell + Sprite + ZOrder, sorts by ZOrder ascending, draws each
// tile to a Camera2D. Caller is responsible for BeginMode2D / EndMode2D.
void DrawTiles(const World& w);

}  // namespace systems
}  // namespace game
