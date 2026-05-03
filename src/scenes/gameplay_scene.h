#pragma once

#include "engine/scene.h"

namespace scenes {

// Actual gameplay. Currently a placeholder grid scene; the real puzzle
// loop lives here once the rule engine is wired in. ESC pushes the
// PauseMenuScene as an overlay, freezing the scene visually but keeping
// it rendered behind the dimmed panel.
class GameplayScene : public engine::Scene {
 public:
  GameplayScene();

  void OnUpdate(float dt) override;
  void OnRender(int target_w, int target_h) override;

 private:
  float time_ = 0.0f;
};

}  // namespace scenes
