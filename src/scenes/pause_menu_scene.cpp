#include "scenes/pause_menu_scene.h"

#include <raylib.h>

#include "engine/scene_manager.h"
#include "engine/text.h"
#include "scenes/main_menu_scene.h"
#include "scenes/settings_scene.h"

namespace scenes {

PauseMenuScene::PauseMenuScene() : Scene("PauseMenu") {}

void PauseMenuScene::OnUpdate(float /*dt*/) {
  const int n = static_cast<int>(Item::Count);

  if (IsKeyPressed(KEY_DOWN) || IsKeyPressed(KEY_J) || IsKeyPressed(KEY_S)) {
    selected_ = (selected_ + 1) % n;
  } else if (IsKeyPressed(KEY_UP) || IsKeyPressed(KEY_K) || IsKeyPressed(KEY_W)) {
    selected_ = (selected_ - 1 + n) % n;
  } else if (IsKeyPressed(KEY_ENTER) || IsKeyPressed(KEY_SPACE)) {
    Activate(static_cast<Item>(selected_));
  } else if (IsKeyPressed(KEY_ESCAPE) || IsKeyPressed(KEY_P)) {
    // ESC inside pause = resume. Same as picking the first item.
    Manager()->Pop();
  }
}

void PauseMenuScene::Activate(Item it) {
  switch (it) {
    case Item::Resume:     Manager()->Pop(); break;
    case Item::Settings:   Manager()->Push<SettingsScene>(); break;
    case Item::QuitToMenu: Manager()->Switch<MainMenuScene>(); break;
    case Item::Count:      break;
  }
}

const char* PauseMenuScene::Label(Item it) {
  switch (it) {
    case Item::Resume:     return "Resume";
    case Item::Settings:   return "Settings";
    case Item::QuitToMenu: return "Quit to Menu";
    case Item::Count:      return "?";
  }
  return "?";
}

void PauseMenuScene::OnRender(int w, int h) {
  // Dim the gameplay underneath. Drawn over the existing framebuffer
  // contents — IsOverlay() makes SceneManager skip the ClearBackground
  // step, so the gameplay scene's pixels are still there.
  DrawRectangle(0, 0, w, h, Color{0, 0, 0, 160});

  engine::DrawText("PAUSED", Vector2{w * 0.5f - 70.0f, h * 0.25f}, 48, RAYWHITE);

  const int n = static_cast<int>(Item::Count);
  constexpr float kItemH = 44.0f;
  const float total_h = kItemH * n;
  const float start_y = (h - total_h) * 0.5f + 30.0f;

  for (int i = 0; i < n; ++i) {
    const bool active = (i == selected_);
    const Color color = active ? Color{255, 220, 120, 255} : Color{220, 220, 240, 255};
    const char* label = Label(static_cast<Item>(i));
    const float y = start_y + i * kItemH;

    if (active) {
      engine::DrawText(">", Vector2{w * 0.5f - 110.0f, y}, 24, color);
    }
    engine::DrawText(label, Vector2{w * 0.5f - 80.0f, y}, 24, color);
  }

  engine::DrawText("esc / p to resume    enter to confirm",
                   Vector2{16.0f, h - 30.0f}, 16, Color{180, 180, 200, 200});
}

}  // namespace scenes
