#pragma once

#include <raylib.h>

#include "engine/layer_stack.h"
#include "layers/imgui_layer.h"

class GameLayer;

// Owns the raylib window and the layer stack that drives the per-frame loop.
// main() just constructs Game and calls Run(); everything else lives in
// layers (ImGuiLayer for the dock space + chrome, GameLayer for the scene).
struct Game {
  void Run();

 private:
  void Init();
  void Tick();
  void Update();
  void Render();
  void Shutdown();

  // Paint the logo to the backbuffer once, before any heavy load runs.
  // Without this the window stays black for the 1-2 s it takes to bake
  // the CJK font atlas + initialise ImGui — long enough to feel like
  // the .exe hung.
  void ShowSplashFrame();

  void ToggleBorderless();

 private:
  static constexpr int kScreenWidth = 1280;
  static constexpr int kScreenHeight = 720;
  static constexpr int kTargetFps = 144;

  LayerStack layers_;
  ImGuiLayer* imgui_layer_ = nullptr;  // non-owning; layers_ owns the unique_ptr.
  GameLayer* game_layer_ = nullptr;    // non-owning; layers_ owns the unique_ptr.

  bool borderless_ = false;
  Vector2 windowed_pos_{};
  Vector2 windowed_size_{};
};
