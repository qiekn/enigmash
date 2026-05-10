#pragma once

#include "engine/scene.h"

namespace scenes {

// End / "you won" / "game over" screen. A scene rather than an overlay so
// the gameplay state can be torn down cleanly. The host (gameplay scene)
// transitions here on its own win/lose condition; ESC routes back to
// MainMenu.
class EndScene : public engine::Scene {
 public:
  EndScene() : Scene("End") {}
  void OnUpdate(float dt) override;
  void OnRender(int target_w, int target_h) override;
};

}  // namespace scenes
