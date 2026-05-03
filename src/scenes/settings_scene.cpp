#include "scenes/settings_scene.h"

#include <raylib.h>

#include "engine/scene_manager.h"
#include "scenes/main_menu_scene.h"
#include "scenes/placeholder.h"
#include "theme.h"

namespace scenes {

void SettingsScene::OnUpdate(float /*dt*/) {
  // ESC routes back to whoever opened us. From MainMenu it's a Switch;
  // from PauseMenu (which Pushes us) it's a Pop. We pick by stack depth:
  // depth==1 means we're the only scene → no caller below → Switch.
  if (IsKeyPressed(KEY_ESCAPE) || IsKeyPressed(KEY_ENTER)) {
    if (Manager()->Depth() > 1) {
      Manager()->Pop();
    } else {
      Manager()->Switch<MainMenuScene>();
    }
  }
}

void SettingsScene::OnRender(int w, int h) {
  ClearBackground(theme::kBackground);
  scenes::ui::DrawPlaceholderFrame(w, h, "Settings");
}

}  // namespace scenes
