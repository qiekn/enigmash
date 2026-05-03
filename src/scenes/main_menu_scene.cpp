#include "scenes/main_menu_scene.h"

#include <raylib.h>

#include "engine/scene_manager.h"
#include "engine/text.h"
#include "scenes/achievements_scene.h"
#include "scenes/credits_scene.h"
#include "scenes/gallery_scene.h"
#include "scenes/gameplay_scene.h"
#include "scenes/settings_scene.h"
#include "theme.h"

namespace scenes {

MainMenuScene::MainMenuScene() : Scene("MainMenu") {}

void MainMenuScene::OnUpdate(float /*dt*/) {
  const int n = static_cast<int>(Item::Count);

  if (IsKeyPressed(KEY_DOWN) || IsKeyPressed(KEY_J)) {
    selected_ = (selected_ + 1) % n;
  } else if (IsKeyPressed(KEY_UP) || IsKeyPressed(KEY_K)) {
    selected_ = (selected_ - 1 + n) % n;
  } else if (IsKeyPressed(KEY_ENTER) || IsKeyPressed(KEY_SPACE)) {
    Activate(static_cast<Item>(selected_));
  }
  // Note: no ESC handler here — quitting must go through the explicit
  // Quit menu item so accidental ESC presses can't kill a session.
}

void MainMenuScene::Activate(Item it) {
  switch (it) {
    case Item::Play:         Manager()->Switch<GameplayScene>(); break;
    case Item::Settings:     Manager()->Switch<SettingsScene>(); break;
    case Item::Gallery:      Manager()->Switch<GalleryScene>(); break;
    case Item::Achievements: Manager()->Switch<AchievementsScene>(); break;
    case Item::Credits:      Manager()->Switch<CreditsScene>(); break;
    case Item::Quit:         Manager()->RequestQuit(); break;
    case Item::Count:        break;
  }
}

const char* MainMenuScene::Label(Item it) {
  switch (it) {
    case Item::Play:         return "Play";
    case Item::Settings:     return "Settings";
    case Item::Gallery:      return "Gallery";
    case Item::Achievements: return "Achievements";
    case Item::Credits:      return "Credits";
    case Item::Quit:         return "Quit";
    case Item::Count:        return "?";
  }
  return "?";
}

void MainMenuScene::OnRender(int w, int h) {
  ClearBackground(theme::kBackground);

  // Title sits in the upper third of the viewport so menu items have room
  // to breathe in the middle. Measure-then-place so different fonts /
  // resized viewports both stay centered without manually-tuned offsets.
  const char* kTitle = "ENIGMASH";
  const char* kSubtitle = "a JackLance puzzle clone";
  const Vector2 title_size = engine::MeasureText(kTitle, 48);
  const Vector2 sub_size = engine::MeasureText(kSubtitle, 18);
  engine::DrawText(kTitle, Vector2{(w - title_size.x) * 0.5f, h * 0.18f}, 48, RAYWHITE);
  engine::DrawText(kSubtitle,
                   Vector2{(w - sub_size.x) * 0.5f, h * 0.18f + 60.0f}, 18,
                   Color{160, 160, 180, 255});

  // Menu list: centered horizontally, evenly spaced vertically.
  const int n = static_cast<int>(Item::Count);
  constexpr float kItemH = 44.0f;
  const float total_h = kItemH * n;
  const float start_y = (h - total_h) * 0.5f + 20.0f;

  for (int i = 0; i < n; ++i) {
    const bool active = (i == selected_);
    const Color color = active ? Color{255, 220, 120, 255} : Color{200, 200, 220, 255};
    const char* label = Label(static_cast<Item>(i));
    const float y = start_y + i * kItemH;

    // Selected indicator: a chevron in front of the active label so the
    // selection is visible even at distance / on colorblind setups.
    if (active) {
      engine::DrawText(">", Vector2{w * 0.5f - 96.0f, y}, 24, color);
    }
    engine::DrawText(label, Vector2{w * 0.5f - 70.0f, y}, 24, color);
  }

  engine::DrawText("arrows / hjkl to navigate    enter to confirm",
                   Vector2{16, h - 30.0f}, 16, Color{140, 140, 160, 200});
}

}  // namespace scenes
