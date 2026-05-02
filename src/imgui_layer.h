#pragma once

#include <raylib.h>

#include "layer.h"

class ImGuiLayer : public Layer {
 public:
  ImGuiLayer();

  void OnAttach() override;
  void OnDetach() override;
  void OnUpdate(float dt) override;
  void OnImGuiRender() override;

  // Begin/End bracket the per-frame ImGui pass around every layer's
  // OnImGuiRender. Keeping this explicit (rather than rolling it into
  // OnImGuiRender) lets the owner decide ordering relative to raylib draws.
  void Begin();
  void End();

  void ToggleVisible() { visible_ = !visible_; }
  bool IsVisible() const { return visible_; }

  Color BackgroundColor() const { return background_color_; }

  // Wires the View menu and Reset Layout to GameLayer-owned panel toggles.
  // Pass null to opt out of any individual entry.
  void BindGamePanelToggles(bool* viewport, bool* hierarchy, bool* console, bool* viewport_no_titlebar);

 private:
  void DrawMainMenuBar();
  void DrawDockSpace();
  void SetupDefaultLayout(unsigned int dockspace_id);
  void LoadFonts(float dpi_scale);
  void SetupStyle(float dpi_scale);

  static float GetDpiScale();

  static constexpr float kImGuiBaseFontSize = 18.0f;

  bool visible_ = true;
  bool show_demo_ = false;
  bool needs_default_layout_ = false;

  bool* show_viewport_ = nullptr;
  bool* show_hierarchy_ = nullptr;
  bool* show_console_ = nullptr;
  bool* viewport_no_titlebar_ = nullptr;

  // Theme background — kept minimal here; extend with a Themes panel later.
  Color background_color_{36, 36, 36, 255};
};
