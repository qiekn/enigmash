#pragma once

#include "engine/scene.h"

namespace scenes {

// Overlay shown while gameplay is paused. Renders a translucent dim over
// the underlying gameplay scene plus a small menu (Resume / Settings /
// Quit to Menu). Pop returns to gameplay; a hard switch goes to MainMenu.
class PauseMenuScene : public engine::Scene {
 public:
  PauseMenuScene();

  bool IsOverlay() const override { return true; }

  void OnUpdate(float dt) override;
  void OnRender(int target_w, int target_h) override;

 private:
  enum class Item { Resume, Settings, QuitToMenu, Count };

  void Activate(Item it);
  static const char* Label(Item it);

  int selected_ = 0;
};

}  // namespace scenes
