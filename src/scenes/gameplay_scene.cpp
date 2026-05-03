#include "scenes/gameplay_scene.h"

#include <raylib.h>

#include <memory>

#include "engine/scene_manager.h"
#include "engine/text.h"
#include "game/components.h"
#include "game/regions/dispatch.h"
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

  camera_.zoom = 1.0f;
  camera_.rotation = 0.0f;
  // Initial target = player position (or world center if no player exists).
  Vector2 initial_target{0, 0};
  bool found_player = false;
  for (auto [e, c] : world_->Registry().view<game::Cell, game::Player>().each()) {
    initial_target = Vector2{(float)(c.x * game::kTilePx), (float)(c.y * game::kTilePx)};
    found_player = true;
    break;
  }
  if (!found_player) {
    const auto b = world_->GetBounds();
    initial_target = Vector2{
        ((b.min_x + b.max_x) * game::kTilePx) * 0.5f,
        ((b.min_y + b.max_y) * game::kTilePx) * 0.5f,
    };
  }
  camera_.target = initial_target;
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

  // Debug warps: drop the player at each region's interior. The Cell
  // jump triggers VisualXY's spring to chase, so the camera glides
  // there over a few frames. Useful while regions are bring-up: with
  // M4's index laying r1/r2/r3 side-by-side, this is the way to test
  // each mechanic without authoring portals between them.
  auto warp_to = [&](int x, int y) {
    for (auto [e, c] : world_->Registry().view<game::Cell, game::Player>().each()) {
      c.x = x; c.y = y;
      break;
    }
  };
  if (IsKeyPressed(KEY_F1)) warp_to(2, 2);    // r1 interior
  if (IsKeyPressed(KEY_F2)) warp_to(11, 3);   // r2 interior (origin 9 + 2,3)
  if (IsKeyPressed(KEY_F3)) warp_to(19, 2);   // r3 interior (origin 18 + 1,2)

  if (const auto dir = input_.Poll(dt); dir != game::Direction::None) {
    const game::Region kind = game::regions::RegionUnderPlayer(*world_);
    game::regions::Tick(*world_, kind, dir);
  }

  game::systems::RenderInterp(*world_, dt);

  // Camera follows the player's VisualXY so the spring carries the
  // camera too — falling through walls between regions feels seamless.
  for (auto [e, v] : world_->Registry().view<game::VisualXY, game::Player>().each()) {
    camera_.target = Vector2{v.x, v.y};
    break;
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

  engine::DrawText("M4 — F1/F2/F3 warp to region 1/2/3", Vector2{16.0f, 16.0f}, 20, RAYWHITE);
  engine::DrawText("press esc / p to pause", Vector2{16.0f, h - 30.0f}, 16,
                   Color{140, 140, 160, 200});
}

}  // namespace scenes
