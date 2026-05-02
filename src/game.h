#pragma once

#include <raylib.h>

#include "imgui_layer.h"
#include "layer_stack.h"

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
