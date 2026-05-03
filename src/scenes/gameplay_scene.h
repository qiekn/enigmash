#pragma once

#include <raylib.h>

#include <memory>

#include "engine/scene.h"
#include "game/input.h"

namespace game { class World; }

namespace scenes {

// Owns the EnTT World and runs the per-tick / per-frame systems. M3
// scope: throttled input drives the region 1 sokoban tick; VisualXY is
// spring-interpolated every render frame for fluid motion.
class GameplayScene : public engine::Scene {
 public:
  GameplayScene();
  ~GameplayScene() override;

  void OnEnter() override;
  void OnExit() override;
  void OnUpdate(float dt) override;
  void OnRender(int target_w, int target_h) override;

 private:
  std::unique_ptr<game::World> world_;
  game::InputThrottle input_;
  Camera2D camera_{};
};

}  // namespace scenes
