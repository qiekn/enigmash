#pragma once

#include <raylib.h>

#include <memory>

#include "engine/scene.h"
#include "game/input.h"
#include "game/undo_ring.h"
#include "scenes/editor_panels.h"

namespace game { class World; }

namespace scenes {

// Owns the EnTT World and runs the per-tick / per-frame systems. M6/M7
// scope: throttled input drives a region tick, snapshots are pushed to
// an UndoRing on every successful tick, Z restores the previous state,
// R restores the last checkpoint, stepping on a goal switches to the
// EndScene, and the editor panels (Catalog / Painter / Inspector /
// Reload) operate on the same registry.
class GameplayScene : public engine::Scene {
 public:
  GameplayScene();
  ~GameplayScene() override;

  void OnEnter() override;
  void OnExit() override;
  void OnUpdate(float dt) override;
  void OnRender(int target_w, int target_h) override;
  void OnImGuiRender() override;

 private:
  void SaveCheckpoint();
  void RestoreCheckpoint();
  bool ReachedGoal() const;
  void ReloadFromJson();

  std::unique_ptr<game::World> world_;
  game::InputThrottle input_;
  game::UndoRing undo_;
  game::UndoRing checkpoint_;
  Camera2D camera_{};
  editor::State editor_{};
};

}  // namespace scenes
