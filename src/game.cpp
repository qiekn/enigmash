#include "game.h"

#include <raylib.h>
#include <rlgl.h>

#include <algorithm>
#include <cstdio>
#include <memory>

#include <imgui.h>

#include "engine/text.h"
#include "game/audio.h"
#include "layers/game_layer.h"
#include "theme.h"

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
  while (!WindowShouldClose() && !game_layer_->QuitRequested()) {
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

  // Window / taskbar / Alt-Tab icon. Set BEFORE the splash so the first
  // OS-level frame already has the right icon — the .ico baked into the
  // .exe by cmake/icon.rc covers Explorer; this one covers runtime.
  //
  // raylib's SetWindowIcon → glfwSetWindowIcon requires R8G8B8A8 pixels;
  // anything else (palette PNG, RGB-only, grayscale) is silently dropped
  // with a LOG_WARNING you won't see in the WIN32_EXECUTABLE build. Force
  // the format unconditionally so we don't have to remember the rule.
  if (Image icon = LoadImage("assets/textures/icon.png"); icon.data != nullptr) {
    ImageFormat(&icon, PIXELFORMAT_UNCOMPRESSED_R8G8B8A8);
    SetWindowIcon(icon);
    UnloadImage(icon);
  }

  // raylib defaults ESC to "close window" (it sets the GLFW
  // should-close flag). Disable that — scenes use ESC for "go back" /
  // "pause"; Game::Run only exits when SceneManager::RequestQuit fires
  // (driven by the menu's Quit item).
  SetExitKey(KEY_NULL);

  // Paint the logo immediately. The OS shows whatever's on the backbuffer
  // after the first SwapBuffers, so doing this BEFORE the slow loads
  // below means the user sees pixels straight away instead of the
  // ~1-2 s of black-window-feels-frozen during font + ImGui init.
  ShowSplashFrame();

  InitAudioDevice();
  game::audio::Init();

  // Pre-load Noto atlases so HUD text uses the same face as ImGui. Switch
  // to AsciiOnly to skip the ~21k Han glyphs if no localized strings ship.
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
  game::audio::Shutdown();
  CloseAudioDevice();
  CloseWindow();
}

void Game::ShowSplashFrame() {
  // TODO: for debugging. I don't want to waste 2s every time debug enigmash game
  // remember to remove this.
  // <2026-05-09 17:25, @qiekn>
  return;

  // Paints the logo using only raylib core APIs (no engine::text, no
  // ImGui — those aren't initialised yet). Texture load is fast (<10ms);
  // the surrounding BeginDrawing/EndDrawing pair triggers the actual GL
  // SwapBuffers so the OS has pixels to composite while Init() blocks
  // on the font / ImGui setup that follows.
  Texture2D logo = LoadTexture("assets/textures/jl.png");
  const bool valid = (logo.id != 0 && logo.width > 0 && logo.height > 0);
  if (valid) SetTextureFilter(logo, TEXTURE_FILTER_BILINEAR);

  auto draw_one_frame = [&]() {
    BeginDrawing();
    ClearBackground(theme::kBackground);
    if (valid) {
      const int sw = GetScreenWidth();
      const int sh = GetScreenHeight();
      constexpr float kMargin = 0.7f;
      const float scale = std::min(sw * kMargin / logo.width, sh * kMargin / logo.height);
      const float dw = logo.width * scale;
      const float dh = logo.height * scale;
      const float dx = (sw - dw) * 0.5f;
      const float dy = (sh - dh) * 0.5f;
      DrawTexturePro(logo,
                     Rectangle{0, 0, (float)logo.width, (float)logo.height},
                     Rectangle{dx, dy, dw, dh},
                     Vector2{0, 0}, 0.0f, WHITE);
    }
    EndDrawing();
  };

  // Hold the splash for a minimum duration so the user actually reads the
  // logo. Re-draw every frame so window drag / expose events keep the
  // image visible (a single SwapBuffers leaves the backbuffer stale on
  // some compositors).
  constexpr double kMinHoldSec = 1.5;
  const double start = GetTime();
  do {
    if (WindowShouldClose()) break;
    draw_one_frame();
  } while (GetTime() - start < kMinHoldSec);

  if (valid) UnloadTexture(logo);
}
