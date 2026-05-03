#include "scenes/gallery_scene.h"

#include <raylib.h>

#include "engine/scene_manager.h"
#include "scenes/main_menu_scene.h"
#include "scenes/placeholder.h"
#include "theme.h"

namespace scenes {

void GalleryScene::OnUpdate(float /*dt*/) {
  if (IsKeyPressed(KEY_ESCAPE) || IsKeyPressed(KEY_ENTER)) {
    Manager()->Switch<MainMenuScene>();
  }
}

void GalleryScene::OnRender(int w, int h) {
  ClearBackground(theme::kBackground);
  scenes::ui::DrawPlaceholderFrame(w, h, "Gallery");
}

}  // namespace scenes
