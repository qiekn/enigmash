#include "scenes/gameplay_scene.h"

#include <raylib.h>

#include <memory>

#include "engine/scene_manager.h"
#include "engine/text.h"
#include "game/regions/r1_sokoban.h"
#include "game/systems/render_interp.h"
#include "game/systems/render_tiles.h"
#include "game/world.h"
#include "scenes/pause_menu_scene.h"
#include "theme.h"

namespace scenes {

GameplayScene::GameplayScene() : Scene("Gameplay") {}
GameplayScene::~GameplayScene() = default;

void GameplayScene::OnEnter() {
  world_ = std::make_unique<game::World>();
  if (!world_->LoadObjects("assets/data/objects.json")) {
    TraceLog(LOG_ERROR, "GameplayScene: failed to load objects.json");
    return;
  }
  world_->Sprites().EnsureLoaded();
  if (!world_->LoadWorld("assets/data/world/index.json")) {
    TraceLog(LOG_ERROR, "GameplayScene: failed to load world index");
    return;
  }

  const auto b = world_->GetBounds();
  camera_.zoom = 1.0f;
  camera_.rotation = 0.0f;
  camera_.target = Vector2{
      ((b.min_x + b.max_x) * game::kTilePx) * 0.5f,
      ((b.min_y + b.max_y) * game::kTilePx) * 0.5f,
  };
}

void GameplayScene::OnExit() {
  if (world_) world_->Sprites().Unload();
  world_.reset();
}

void GameplayScene::OnUpdate(float dt) {
  if (IsKeyPressed(KEY_ESCAPE) || IsKeyPressed(KEY_P)) {
    Manager()->Push<PauseMenuScene>();
    return;
  }
  if (!world_) return;

  // One logic tick per non-None Poll. The throttle clamps repeats to
  // keep movement readable; multi-tick-per-frame is intentional only on
  // direction-change to make taps feel snappy.
  if (const auto dir = input_.Poll(dt); dir != game::Direction::None) {
    game::regions::Sokoban(*world_, dir);
  }

  // Spring physics is per render frame, not per tick.
  game::systems::RenderInterp(*world_, dt);
}

void GameplayScene::OnRender(int w, int h) {
  ClearBackground(theme::kBackground);
  if (!world_) return;

  // Center the map in the viewport every frame — handles RT resize cleanly.
  camera_.offset = Vector2{w * 0.5f, h * 0.5f};

  BeginMode2D(camera_);
  game::systems::DrawTiles(*world_);
  EndMode2D();

  engine::DrawText("M3 — sokoban push (arrows / WASD / HJKL)", Vector2{16.0f, 16.0f}, 20, RAYWHITE);
  engine::DrawText("press esc / p to pause", Vector2{16.0f, h - 30.0f}, 16,
                   Color{140, 140, 160, 200});
}

}  // namespace scenes
