#include "scenes/gameplay_scene.h"

#include <raylib.h>

#include "engine/scene_manager.h"
#include "engine/text.h"
#include "scenes/pause_menu_scene.h"
#include "theme.h"

namespace scenes {

GameplayScene::GameplayScene() : Scene("Gameplay") {}

void GameplayScene::OnUpdate(float dt) {
  time_ += dt;
  if (IsKeyPressed(KEY_ESCAPE) || IsKeyPressed(KEY_P)) {
    Manager()->Push<PauseMenuScene>();
  }
}

void GameplayScene::OnRender(int w, int h) {
  ClearBackground(theme::kBackground);

  // Reference grid so resizes are visible while we don't have real
  // gameplay rendering yet.
  const Color kGridColor{255, 255, 255, 32};
  for (int x = 0; x < w; x += 32) DrawLine(x, 0, x, h, kGridColor);
  for (int y = 0; y < h; y += 32) DrawLine(0, y, w, y, kGridColor);

  engine::DrawText("Gameplay (placeholder)", Vector2{16.0f, 16.0f}, 24, RAYWHITE);
  engine::DrawText("应无所住，而生其心。", Vector2{16.0f, 48.0f}, 24,
                   Color{220, 220, 240, 255});
  engine::DrawText(TextFormat("time = %.1fs    viewport = %dx%d", time_, w, h),
                   Vector2{16.0f, 84.0f}, 18, Color{180, 180, 200, 255});

  engine::DrawText("press esc / p to pause", Vector2{16.0f, h - 30.0f}, 16,
                   Color{140, 140, 160, 200});
}

}  // namespace scenes
