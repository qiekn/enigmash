#pragma once

#include "engine/scene.h"

namespace scenes {

class CreditsScene : public engine::Scene {
 public:
  CreditsScene() : Scene("Credits") {}
  void OnUpdate(float dt) override;
  void OnRender(int target_w, int target_h) override;
};

}  // namespace scenes
