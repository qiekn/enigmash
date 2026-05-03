#pragma once

#include "engine/scene.h"

namespace scenes {

class SettingsScene : public engine::Scene {
 public:
  SettingsScene() : Scene("Settings") {}
  void OnUpdate(float dt) override;
  void OnRender(int target_w, int target_h) override;
};

}  // namespace scenes
