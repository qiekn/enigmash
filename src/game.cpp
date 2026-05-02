#include "game.h"

#include <raylib.h>
#include <rlgl.h>

#include <cstdio>
#include <memory>

#include <imgui.h>

#include "engine/text.h"
#include "game_layer.h"

namespace {
constexpr const char* kWindowStateFile = "window.state";

struct WindowState {
  int x;
  int y;
  int w;
  int h;
};

WindowState LoadWindowState(int default_w, int default_h) {
  WindowState s{80, 80, default_w, default_h};
  if (FILE* f = std::fopen(kWindowStateFile, "r")) {
    int x, y, w, h;
    int n = std::fscanf(f, "%d %d %d %d", &x, &y, &w, &h);
    if (n == 4 && w > 0 && h > 0) {
      s.x = x; s.y = y; s.w = w; s.h = h;
    }
    std::fclose(f);
  }
  return s;
}

void SaveWindowState() {
  Vector2 pos = GetWindowPosition();
  if (FILE* f = std::fopen(kWindowStateFile, "w")) {
    std::fprintf(f, "%d %d %d %d\n", (int)pos.x, (int)pos.y,
                 GetScreenWidth(), GetScreenHeight());
    std::fclose(f);
  }
}
}  // namespace

void Game::Run() {
  Init();
  while (!WindowShouldClose()) {
    Tick();
  }
  Shutdown();
}

void Game::Init() {
  SetTraceLogLevel(LOG_WARNING);
  const WindowState state = LoadWindowState(kScreenWidth, kScreenHeight);

  SetConfigFlags(FLAG_WINDOW_RESIZABLE | FLAG_WINDOW_HIGHDPI);
  InitWindow(state.w, state.h, "enigmash");
  SetWindowPosition(state.x, state.y);
  SetTargetFPS(kTargetFps);
  InitAudioDevice();

  // Pre-load Noto atlases so HUD text uses the same face as ImGui. ASCII-
  // only for now — switch to AsciiPlusCJK once we ship localized strings.
  engine::LoadFonts(engine::CodepointSet::AsciiOnly);

  auto imgui_layer = std::make_unique<ImGuiLayer>();
  auto game_layer = std::make_unique<GameLayer>();

  imgui_layer_ = imgui_layer.get();
  game_layer_ = game_layer.get();

  imgui_layer_->BindGamePanelToggles(game_layer->ShowViewportPtr(),
                                     game_layer->ShowHierarchyPtr(),
                                     game_layer->ShowConsolePtr(),
                                     game_layer->ViewportNoTitleBarPtr());

  // Order matters: ImGuiLayer must submit DockSpaceOverViewport before
  // GameLayer's Viewport window so the panel can dock into the central node
  // on the first frame.
  layers_.push_layer(std::move(imgui_layer));
  layers_.push_layer(std::move(game_layer));
}

void Game::Tick() {
  Update();
  Render();
}

void Game::Update() {
  const float dt = GetFrameTime();
  if (IsKeyPressed(KEY_F11)) {
    ToggleBorderless();
  }
  for (auto& layer : layers_) {
    layer->OnUpdate(dt);
  }
}

void Game::ToggleBorderless() {
  if (!borderless_) {
    windowed_pos_ = GetWindowPosition();
    windowed_size_ = {(float)GetScreenWidth(), (float)GetScreenHeight()};

    const int monitor = GetCurrentMonitor();
    const Vector2 mpos = GetMonitorPosition(monitor);
    const int mw = GetMonitorWidth(monitor);
    const int mh = GetMonitorHeight(monitor);

    SetWindowState(FLAG_WINDOW_UNDECORATED);
    SetWindowPosition((int)mpos.x, (int)mpos.y);
    // +1 px so Windows doesn't auto-promote this to exclusive fullscreen.
    SetWindowSize(mw, mh + 1);
    borderless_ = true;
  } else {
    ClearWindowState(FLAG_WINDOW_UNDECORATED);
    SetWindowSize((int)windowed_size_.x, (int)windowed_size_.y);
    SetWindowPosition((int)windowed_pos_.x, (int)windowed_pos_.y);
    borderless_ = false;
  }
}

void Game::Render() {
  // Sync the scene background to the active ImGui theme so the RT inside
  // the Viewport panel matches the surrounding chrome.
  game_layer_->SetBackgroundColor(imgui_layer_->BackgroundColor());

  // When ImGui is hidden the Viewport panel doesn't run — size the RT to
  // the framebuffer so the fullscreen blit below is 1:1 in real pixels.
  const bool imgui_visible = imgui_layer_->IsVisible();
  if (!imgui_visible) {
    game_layer_->EnsureTargetSize(GetRenderWidth(), GetRenderHeight());
  }

  BeginDrawing();
  ClearBackground(imgui_layer_->BackgroundColor());

  for (auto& layer : layers_) {
    layer->OnRender();
  }

  // ImGui hidden: blit the scene RT straight to the backbuffer instead of
  // routing through ImGui::Image. raylib FBOs are y-flipped relative to
  // the backbuffer — negative src height un-flips on the way out.
  if (!imgui_visible && game_layer_->TargetValid()) {
    const RenderTexture2D& rt = game_layer_->Target();
    const Rectangle src{0, 0, (float)rt.texture.width, -(float)rt.texture.height};
    const Rectangle dst{0, 0, (float)GetScreenWidth(), (float)GetScreenHeight()};
    DrawTexturePro(rt.texture, src, dst, Vector2{0, 0}, 0.0f, WHITE);
  }

  rlDrawRenderBatchActive();

  imgui_layer_->Begin();
  if (imgui_visible) {
    for (auto& layer : layers_) {
      layer->OnImGuiRender();
    }
  }
  imgui_layer_->End();

  EndDrawing();
}

void Game::Shutdown() {
  if (borderless_) ToggleBorderless();
  SaveWindowState();
  layers_.clear();        // detach layers before the GL context goes away
  engine::UnloadFonts();  // free font atlases (still need GL context)
  CloseAudioDevice();
  CloseWindow();
}
