#include "scenes/gameplay_scene.h"

#include <raylib.h>

#include <memory>

#include "engine/scene_manager.h"
#include "engine/text.h"
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
  BuildTestMap();

  camera_.zoom = 1.0f;
  camera_.rotation = 0.0f;
  camera_.target = Vector2{
      (map_w_ * game::kTilePx) * 0.5f,
      (map_h_ * game::kTilePx) * 0.5f,
  };
  // offset is set per-frame in OnRender once we know the viewport.
}

void GameplayScene::OnExit() {
  if (world_) world_->Sprites().Unload();
  world_.reset();
}

void GameplayScene::BuildTestMap() {
  // 5x5 test map. Layout:
  //   . . . . .
  //   . W W W .
  //   . W P W .
  //   . W B W .
  //   . . G C
  // (P = player, B = box, W = wall, G = goal, C = checkpoint, . = floor)
  const char* layout[5] = {
      ".....",
      ".WWW.",
      ".WPW.",
      ".WBW.",
      "..GC.",
  };
  map_w_ = 5;
  map_h_ = 5;
  for (int y = 0; y < map_h_; ++y) {
    for (int x = 0; x < map_w_; ++x) {
      // Always lay floor under everything for visual continuity.
      world_->Spawn("floor", x, y);
      switch (layout[y][x]) {
        case 'W': world_->Spawn("wall", x, y); break;
        case 'P': world_->Spawn("player", x, y); break;
        case 'B': world_->Spawn("box", x, y); break;
        case 'G': world_->Spawn("goal", x, y); break;
        case 'C': world_->Spawn("checkpoint", x, y); break;
        default: break;
      }
    }
  }
}

void GameplayScene::OnUpdate(float /*dt*/) {
  if (IsKeyPressed(KEY_ESCAPE) || IsKeyPressed(KEY_P)) {
    Manager()->Push<PauseMenuScene>();
  }
}

void GameplayScene::OnRender(int w, int h) {
  ClearBackground(theme::kBackground);
  if (!world_) return;

  // Center the map in the viewport every frame — handles RT resize cleanly.
  camera_.offset = Vector2{w * 0.5f, h * 0.5f};

  BeginMode2D(camera_);
  game::systems::DrawTiles(*world_);
  EndMode2D();

  engine::DrawText("M1 — hardcoded 5x5 test map", Vector2{16.0f, 16.0f}, 20, RAYWHITE);
  engine::DrawText("press esc / p to pause", Vector2{16.0f, h - 30.0f}, 16,
                   Color{140, 140, 160, 200});
}

}  // namespace scenes
