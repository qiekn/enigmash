#pragma once

#include "engine/scene.h"

namespace scenes {

class AchievementsScene : public engine::Scene {
 public:
  AchievementsScene() : Scene("Achievements") {}
  void OnUpdate(float dt) override;
  void OnRender(int target_w, int target_h) override;
};

}  // namespace scenes
