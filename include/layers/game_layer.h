#pragma once

#include <raylib.h>

#include "engine/layer.h"
#include "engine/scene_manager.h"

// Owns the offscreen RenderTexture2D the game scene draws into and hosts
// a SceneManager that drives the actual logo / menu / gameplay flow.
// Also keeps the placeholder Hierarchy / Console ImGui panels so the
// default dock layout has something in every region.
class GameLayer : public Layer {
 public:
  GameLayer();
  ~GameLayer() override;

  void OnAttach() override;
  void OnDetach() override;
  void OnUpdate(float dt) override;
  void OnRender() override;
  void OnImGuiRender() override;

  bool* ShowViewportPtr() { return &show_viewport_; }
  bool* ShowHierarchyPtr() { return &show_hierarchy_; }
  bool* ShowConsolePtr() { return &show_console_; }
  bool* ViewportNoTitleBarPtr() { return &viewport_no_titlebar_; }

  // Push the active scene background color (typically the ImGui theme's
  // background, sourced by Game::Render). The scene itself usually
  // ClearBackground()s with its own palette, so this is mostly for the
  // surrounding ImGui chrome.
  void SetBackgroundColor(Color c) { background_color_ = c; }

  // Exposed for Game::Render's "ImGui hidden = scene fullscreen" path.
  void EnsureTargetSize(int w, int h) { EnsureTarget(w, h); }
  const RenderTexture2D& Target() const { return target_; }
  bool TargetValid() const { return target_valid_; }

  // Polled by Game::Run to break out of the main loop when a scene
  // (typically the main menu's Quit button) has asked to terminate.
  bool QuitRequested() const { return scenes_.QuitRequested(); }

 private:
  void EnsureTarget(int w, int h);
  void DrawViewportPanel();
  void DrawHierarchyPanel();
  void DrawConsolePanel();

  RenderTexture2D target_{};
  int target_w_ = 0;
  int target_h_ = 0;
  bool target_valid_ = false;

  bool show_viewport_ = true;
  bool show_hierarchy_ = true;
  bool show_console_ = true;
  bool viewport_no_titlebar_ = false;

  Color background_color_{30, 30, 46, 255};

  engine::SceneManager scenes_;
};
