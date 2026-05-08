#include "scenes/gameplay_scene.h"

#include <raylib.h>

#include <cmath>
#include <memory>

#include "engine/scene_manager.h"
#include "engine/text.h"
#include "game/components.h"
#include "game/regions/dispatch.h"
#include "game/systems/patch_box_sprite.h"
#include "game/systems/patch_player_sprite.h"
#include "game/systems/render_interp.h"
#include "game/systems/render_tiles.h"
#include "game/systems/toggle_swap.h"
#include "game/world.h"
#include "scenes/end_scene.h"
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

  // First-frame snapshots: undo starts empty (nothing to undo *to* on
  // the first tick), checkpoint captures the loaded layout so R always
  // has somewhere to fall back to.
  SaveCheckpoint();
  // Pick the right per-region body sprite for the spawn location.
  game::systems::PatchPlayerSprite(*world_);
  game::systems::PatchBoxSprite(*world_);
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
  if (IsKeyPressed(KEY_F1)) warp_to(2, 2);
  if (IsKeyPressed(KEY_F2)) warp_to(11, 3);
  if (IsKeyPressed(KEY_F3)) warp_to(19, 2);
  if (IsKeyPressed(KEY_F4)) warp_to(27, 2);
  if (IsKeyPressed(KEY_F5)) warp_to(42, 4);
  if (IsKeyPressed(KEY_F6)) warp_to(47, 4);

  // Z = undo. Z must be checked *before* the tick so that even if the
  // player holds a direction, undo wins this frame.
  if (IsKeyPressed(KEY_Z)) {
    undo_.Pop(world_->Registry());
  } else if (IsKeyPressed(KEY_R)) {
    RestoreCheckpoint();
  } else {
    const bool shoot = IsKeyPressed(KEY_SPACE);
    const auto dir = input_.Poll(dt);
    if (dir != game::Direction::None || shoot) {
      // Snapshot BEFORE the tick mutates state. This way Pop() restores
      // the pre-tick layout exactly.
      undo_.Push(world_->Registry());
      const game::Region kind = game::regions::RegionUnderPlayer(*world_);
      game::regions::Tick(*world_, kind, dir, shoot);
      game::systems::ToggleSwap(*world_);
      game::systems::PatchPlayerSprite(*world_);
      game::systems::PatchBoxSprite(*world_);

      // Stepping on a Checkpoint resets the restore point. Done after
      // the tick so a "push a box onto a checkpoint, you stand here"
      // resolves correctly.
      auto& reg = world_->Registry();
      bool on_cp = false;
      for (auto [pe, pc] : reg.view<game::Cell, game::Player>().each()) {
        for (auto [ce, cc] : reg.view<game::Cell, game::Checkpoint>().each()) {
          if (pc.x == cc.x && pc.y == cc.y) { on_cp = true; break; }
        }
        if (on_cp) break;
      }
      if (on_cp) SaveCheckpoint();
    }
  }

  if (ReachedGoal()) {
    Manager()->Switch<EndScene>();
    return;
  }

  game::systems::RenderInterp(*world_, dt);

  // Camera follows the player's VisualXY so the spring carries the
  // camera too — falling through walls between regions feels seamless.
  for (auto [e, v] : world_->Registry().view<game::VisualXY, game::Player>().each()) {
    camera_.target = Vector2{v.x, v.y};
    break;
  }
}

void GameplayScene::SaveCheckpoint() {
  if (!world_) return;
  checkpoint_.Clear();
  checkpoint_.Push(world_->Registry());
}

void GameplayScene::RestoreCheckpoint() {
  if (!world_) return;
  // UndoRing::Pop removes the entry, so we re-Save it after restoring.
  // (A peek-style API would be cleaner, but the entire checkpoint flow
  // is small enough that re-pushing isn't worth a new method.)
  checkpoint_.Pop(world_->Registry());
  SaveCheckpoint();
  undo_.Clear();  // post-checkpoint history is no longer reachable
}

bool GameplayScene::ReachedGoal() const {
  if (!world_) return false;
  const auto& reg = world_->Registry();
  for (auto [pe, pc] : reg.view<const game::Cell, const game::Player>().each()) {
    for (auto [ge, gc] : reg.view<const game::Cell, const game::Goal>().each()) {
      if (pc.x == gc.x && pc.y == gc.y) return true;
    }
  }
  return false;
}

void GameplayScene::OnRender(int w, int h) {
  ClearBackground(theme::kBackground);
  if (!world_) return;

  // Snap camera projection to integer pixels so adjacent floor tiles
  // stay flush. Without this, the spring's fractional camera target
  // pushes neighbouring tiles to slightly different sub-pixel rows and
  // raylib's POINT-filter rasterisation leaves visible black seams.
  // The spring keeps full float precision in VisualXY / camera_.target;
  // rounding happens only at the projection layer.
  Camera2D snapped = camera_;
  snapped.offset = Vector2{std::round(w * 0.5f), std::round(h * 0.5f)};
  snapped.target = Vector2{std::round(camera_.target.x), std::round(camera_.target.y)};
  camera_.offset = snapped.offset;

  BeginMode2D(snapped);
  game::systems::DrawTiles(*world_);
  EndMode2D();

  engine::DrawText("M7 — editor: Catalog / Painter / Inspector + Reload",
                   Vector2{16.0f, 16.0f}, 20, RAYWHITE);
  engine::DrawText("press esc / p to pause", Vector2{16.0f, h - 30.0f}, 16,
                   Color{140, 140, 160, 200});
}

void GameplayScene::OnImGuiRender() {
  if (!world_) return;
  bool reload = false;
  editor::DrawMenu(editor_, *world_, reload);
  editor::DrawCatalog(editor_, *world_);
  editor::DrawPainter(editor_, *world_);
  editor::DrawInspector(editor_, *world_);
  if (reload) ReloadFromJson();
}

void GameplayScene::ReloadFromJson() {
  // Drop GPU textures + registry, then rebuild from JSON. Undo /
  // checkpoint history are wiped: any state captured against the old
  // entity ids would be invalid against the new registry.
  if (world_) world_->Sprites().Unload();
  world_ = std::make_unique<game::World>();
  if (!world_->LoadObjects("assets/data/objects.json")) return;
  world_->Sprites().EnsureLoaded();
  if (!world_->LoadWorld("assets/data/world/index.json")) return;
  undo_.Clear();
  SaveCheckpoint();
}

}  // namespace scenes
