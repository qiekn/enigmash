#include "layers/game_layer.h"

#include <imgui.h>
#include <imgui_internal.h>

#include "scenes/main_menu_scene.h"

GameLayer::GameLayer() : Layer("GameLayer") {}

GameLayer::~GameLayer() = default;

void GameLayer::OnAttach() {
  // Allocate something non-zero so the first frame has a valid texture even
  // before the Viewport panel reports its real size.
  EnsureTarget(1280, 720);

  // The .exe-launch logo is painted directly to the backbuffer by
  // Game::ShowSplashFrame() before any layers come up — by the time we
  // get here, the user has already seen it. Boot straight into the menu.
  scenes_.Switch<scenes::MainMenuScene>();
}

void GameLayer::OnDetach() {
  if (target_valid_) {
    UnloadRenderTexture(target_);
    target_valid_ = false;
  }
  // SceneManager destructor will OnExit each remaining scene through
  // unique_ptr destruction order. Force a deterministic teardown here so
  // the GL context is still valid when textures get released.
  while (scenes_.Active() != nullptr) {
    scenes_.Pop();
    scenes_.Update(0.0f);  // applies the pending Pop
  }
}

void GameLayer::OnUpdate(float dt) { scenes_.Update(dt); }

void GameLayer::OnRender() {
  if (!target_valid_) return;
  BeginTextureMode(target_);
  // Scenes own their own ClearBackground — overlays rely on the previous
  // pixels being intact, so we don't pre-clear here.
  scenes_.Render(target_w_, target_h_);
  EndTextureMode();
}

void GameLayer::OnImGuiRender() {
  if (show_viewport_) DrawViewportPanel();
  if (show_hierarchy_) DrawHierarchyPanel();
  if (show_console_) DrawConsolePanel();
  scenes_.ImGuiRender();
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
  if (ImGui::TreeNodeEx("SceneManager", ImGuiTreeNodeFlags_DefaultOpen)) {
    if (engine::Scene* active = scenes_.Active()) {
      ImGui::BulletText("active: %s", active->Name().c_str());
    } else {
      ImGui::BulletText("(no active scene)");
    }
    ImGui::BulletText("stack depth: %zu", scenes_.Depth());
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
