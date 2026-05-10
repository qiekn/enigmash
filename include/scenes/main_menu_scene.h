#pragma once

#include "engine/scene.h"

namespace scenes {

// Top-level menu shown after the logo. Vertical list of items navigated
// via arrow keys / hjkl and confirmed with Enter / Space.
class MainMenuScene : public engine::Scene {
 public:
  MainMenuScene();

  void OnUpdate(float dt) override;
  void OnRender(int target_w, int target_h) override;

 private:
  enum class Item { Play, Settings, Gallery, Achievements, Credits, Quit, Count };

  void Activate(Item it);
  static const char* Label(Item it);

  int selected_ = 0;
};

}  // namespace scenes
