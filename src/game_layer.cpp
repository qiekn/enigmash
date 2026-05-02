#include "game_layer.h"

#include <imgui.h>
#include <imgui_internal.h>

#include "engine/text.h"

GameLayer::GameLayer() : Layer("GameLayer") {}

GameLayer::~GameLayer() = default;

void GameLayer::OnAttach() {
  // Allocate something non-zero so the first frame has a valid texture even
  // before the Viewport panel reports its real size.
  EnsureTarget(1280, 720);
}

void GameLayer::OnDetach() {
  if (target_valid_) {
    UnloadRenderTexture(target_);
    target_valid_ = false;
  }
}

void GameLayer::OnUpdate(float dt) { time_ += dt; }

void GameLayer::OnRender() {
  if (!target_valid_) return;
  DrawScene();
}

void GameLayer::OnImGuiRender() {
  if (show_viewport_) DrawViewportPanel();
  if (show_hierarchy_) DrawHierarchyPanel();
  if (show_console_) DrawConsolePanel();
}

void GameLayer::EnsureTarget(int w, int h) {
  if (w < 1 || h < 1) return;
  if (target_valid_ && target_w_ == w && target_h_ == h) return;
  if (target_valid_) UnloadRenderTexture(target_);
  target_ = LoadRenderTexture(w, h);
  // POINT filter avoids the BILINEAR half-pixel smear on non-integer scaling.
  SetTextureFilter(target_.texture, TEXTURE_FILTER_POINT);
  target_w_ = w;
  target_h_ = h;
  target_valid_ = true;
}

void GameLayer::DrawScene() {
  BeginTextureMode(target_);
  ClearBackground(background_color_);

  // Reference grid so resizes are visible.
  const Color kGridColor{255, 255, 255, 32};
  for (int x = 0; x < target_w_; x += 32) {
    DrawLine(x, 0, x, target_h_, kGridColor);
  }
  for (int y = 0; y < target_h_; y += 32) {
    DrawLine(0, y, target_w_, y, kGridColor);
  }

  // Placeholder scene content — replace with real game logic.
  engine::DrawText("enigmash — raylib + ImGui scaffold", Vector2{16, 16}, 24, RAYWHITE);
  engine::DrawText("应无所住，而生其心。", Vector2{16, 48}, 24, Color{220, 220, 240, 255});
  engine::DrawText(TextFormat("time = %.1fs    viewport = %dx%d", time_, target_w_, target_h_),
                   Vector2{16, 84}, 18, Color{180, 180, 200, 255});

  EndTextureMode();
}

void GameLayer::DrawViewportPanel() {
  ImGuiWindowFlags flags = ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoScrollbar |
                           ImGuiWindowFlags_NoScrollWithMouse;
  if (viewport_no_titlebar_) flags |= ImGuiWindowFlags_NoTitleBar;

  // Zero padding so the framebuffer fills the entire panel.
  ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2{0, 0});
  bool open = ImGui::Begin("Viewport", nullptr, flags);
  ImGui::PopStyleVar();

  if (!open) {
    ImGui::End();
    return;
  }

  // Auto-hide the dock node's tab bar when only Viewport is in the node.
  if (ImGui::IsWindowDocked()) {
    if (ImGuiDockNode* node = ImGui::GetWindowDockNode()) {
      if (node->Windows.Size == 1) {
        node->LocalFlags |= ImGuiDockNodeFlags_NoTabBar;
      } else {
        node->LocalFlags &= ~ImGuiDockNodeFlags_NoTabBar;
      }
    }
  }

  const ImVec2 avail = ImGui::GetContentRegionAvail();
  EnsureTarget(static_cast<int>(avail.x), static_cast<int>(avail.y));

  if (target_valid_) {
    // raylib FBOs are y-flipped relative to ImGui's UV convention — flip V.
    const ImTextureID tex_id = static_cast<ImTextureID>(target_.texture.id);
    ImGui::Image(tex_id, avail, ImVec2(0, 1), ImVec2(1, 0));
  }

  // Right-click anywhere in the viewport for the toggle — essential when the
  // title bar is hidden.
  if (ImGui::BeginPopupContextWindow("ViewportContext", ImGuiPopupFlags_MouseButtonRight)) {
    ImGui::MenuItem("Hide Title Bar", nullptr, &viewport_no_titlebar_);
    ImGui::EndPopup();
  }

  ImGui::End();
}

void GameLayer::DrawHierarchyPanel() {
  if (!ImGui::Begin("Hierarchy", nullptr, ImGuiWindowFlags_NoCollapse)) {
    ImGui::End();
    return;
  }
  if (ImGui::TreeNodeEx("Scene", ImGuiTreeNodeFlags_DefaultOpen)) {
    ImGui::BulletText("Camera");
    ImGui::BulletText("Player");
    ImGui::BulletText("World");
    ImGui::TreePop();
  }
  ImGui::End();
}

void GameLayer::DrawConsolePanel() {
  if (!ImGui::Begin("Console", nullptr, ImGuiWindowFlags_NoCollapse)) {
    ImGui::End();
    return;
  }
  ImGui::TextDisabled("[INFO] enigmash initialized.");
  ImGui::TextDisabled("[INFO] Default dock layout applied.");
  ImGui::TextDisabled("[HINT] Right-click the viewport to toggle its title bar.");
  ImGui::End();
}
