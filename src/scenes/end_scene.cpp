#include "scenes/end_scene.h"

#include <raylib.h>

#include "engine/scene_manager.h"
#include "scenes/main_menu_scene.h"
#include "scenes/placeholder.h"
#include "theme.h"

namespace scenes {

void EndScene::OnUpdate(float /*dt*/) {
  if (IsKeyPressed(KEY_ESCAPE) || IsKeyPressed(KEY_ENTER) ||
      IsKeyPressed(KEY_SPACE)) {
    Manager()->Switch<MainMenuScene>();
  }
}

void EndScene::OnRender(int w, int h) {
  ClearBackground(theme::kBackground);
  scenes::ui::DrawPlaceholderFrame(w, h, "Thanks for playing",
                                   "press esc / enter to return to menu");
}

}  // namespace scenes
