#pragma once

#include <raylib.h>

#include <memory>

#include "engine/scene.h"

namespace game { class World; }

namespace scenes {

// Owns the EnTT World and runs the per-tick / per-frame systems. M1
// scope: load objects.json, spawn a hard-coded 5x5 test map, render via
// Camera2D centered on the map. Logic ticks come later.
class GameplayScene : public engine::Scene {
 public:
  GameplayScene();
  ~GameplayScene() override;

  void OnEnter() override;
  void OnExit() override;
  void OnUpdate(float dt) override;
  void OnRender(int target_w, int target_h) override;

 private:
  void BuildTestMap();

  std::unique_ptr<game::World> world_;
  Camera2D camera_{};
  int map_w_ = 0;
  int map_h_ = 0;
};

}  // namespace scenes
