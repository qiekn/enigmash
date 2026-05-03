#pragma once

#include <raylib.h>

#include <memory>

#include "engine/scene.h"
#include "game/input.h"
#include "game/undo_ring.h"

namespace game { class World; }

namespace scenes {

// Owns the EnTT World and runs the per-tick / per-frame systems. M6
// scope: throttled input drives a region tick, snapshots are pushed to
// an UndoRing on every successful tick, Z restores the previous state,
// R restores the last checkpoint, stepping on a goal switches to the
// EndScene.
class GameplayScene : public engine::Scene {
 public:
  GameplayScene();
  ~GameplayScene() override;

  void OnEnter() override;
  void OnExit() override;
  void OnUpdate(float dt) override;
  void OnRender(int target_w, int target_h) override;

 private:
  // Captures every Cell into checkpoint_ for restart-by-R. Called once
  // at scene start and whenever the player touches a Checkpoint.
  void SaveCheckpoint();
  void RestoreCheckpoint();

  // True if any Player entity overlaps a Goal entity. Triggers the win
  // transition — scene switches to EndScene next frame boundary.
  bool ReachedGoal() const;

  std::unique_ptr<game::World> world_;
  game::InputThrottle input_;
  game::UndoRing undo_;
  // Single-frame snapshot: a UndoRing is reused at depth 1 so checkpoint
  // and undo share the same Push/Pop machinery.
  game::UndoRing checkpoint_;
  Camera2D camera_{};
};

}  // namespace scenes
