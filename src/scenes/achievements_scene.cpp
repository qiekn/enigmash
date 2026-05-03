#include "scenes/achievements_scene.h"

#include <raylib.h>

#include "engine/scene_manager.h"
#include "scenes/main_menu_scene.h"
#include "scenes/placeholder.h"
#include "theme.h"

namespace scenes {

void AchievementsScene::OnUpdate(float /*dt*/) {
  if (IsKeyPressed(KEY_ESCAPE) || IsKeyPressed(KEY_ENTER)) {
    Manager()->Switch<MainMenuScene>();
  }
}

void AchievementsScene::OnRender(int w, int h) {
  ClearBackground(theme::kBackground);
  scenes::ui::DrawPlaceholderFrame(w, h, "Achievements");
}

}  // namespace scenes
