#include "imgui_layer.h"

#include <algorithm>
#include <filesystem>

#include <raylib.h>

#include <GLFW/glfw3.h>
#include <imgui.h>
#include <imgui_impl_glfw.h>
#include <imgui_impl_opengl3.h>
#include <imgui_internal.h>

#include "engine/text.h"

ImGuiLayer::ImGuiLayer() : Layer("ImGuiLayer") {}

void ImGuiLayer::BindGamePanelToggles(bool* viewport, bool* hierarchy, bool* console, bool* viewport_no_titlebar) {
  show_viewport_ = viewport;
  show_hierarchy_ = hierarchy;
  show_console_ = console;
  viewport_no_titlebar_ = viewport_no_titlebar;
}

void ImGuiLayer::OnAttach() {
  const float dpi_scale = GetDpiScale();

  IMGUI_CHECKVERSION();
  ImGui::CreateContext();

  ImGuiIO& io = ImGui::GetIO();
  io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
  io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
  io.ConfigFlags |= ImGuiConfigFlags_ViewportsEnable;

  LoadFonts(dpi_scale);
  SetupStyle(dpi_scale);

  GLFWwindow* window = glfwGetCurrentContext();
  ImGui_ImplGlfw_InitForOpenGL(window, true);
  ImGui_ImplOpenGL3_Init("#version 330");

  // First-run layout resolution. ImGui auto-loads `imgui.ini` if present;
  // otherwise fall back to the hardcoded SetupDefaultLayout.
  const char* ini = io.IniFilename ? io.IniFilename : "imgui.ini";
  if (!std::filesystem::exists(ini)) {
    needs_default_layout_ = true;
  }
}

void ImGuiLayer::OnDetach() {
  ImGui_ImplOpenGL3_Shutdown();
  ImGui_ImplGlfw_Shutdown();
  ImGui::DestroyContext();
}

void ImGuiLayer::OnUpdate(float /*dt*/) {
  if (IsKeyPressed(KEY_GRAVE)) {
    ToggleVisible();
  }
}

void ImGuiLayer::Begin() {
  ImGui_ImplOpenGL3_NewFrame();
  ImGui_ImplGlfw_NewFrame();
  ImGui::NewFrame();
}

void ImGuiLayer::End() {
  ImGui::Render();
  ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

  if (ImGui::GetIO().ConfigFlags & ImGuiConfigFlags_ViewportsEnable) {
    GLFWwindow* backup = glfwGetCurrentContext();
    ImGui::UpdatePlatformWindows();
    ImGui::RenderPlatformWindowsDefault();
    glfwMakeContextCurrent(backup);
  }
}

void ImGuiLayer::OnImGuiRender() {
  // Visibility is gated by Game::Render before this runs, so no check here.
  DrawDockSpace();
  DrawMainMenuBar();

  if (show_demo_) {
    ImGui::ShowDemoWindow(&show_demo_);
  }
}

void ImGuiLayer::DrawDockSpace() {
  // PassthruCentralNode lets the raylib clear color show through where no
  // window is docked. The Viewport panel docks into the central node by
  // default (see SetupDefaultLayout).
  const ImGuiID dockspace_id = ImGui::DockSpaceOverViewport(
      0, ImGui::GetMainViewport(), ImGuiDockNodeFlags_PassthruCentralNode);

  if (needs_default_layout_) {
    needs_default_layout_ = false;
    SetupDefaultLayout(dockspace_id);
  }
}

void ImGuiLayer::SetupDefaultLayout(unsigned int dockspace_id) {
  const ImGuiID id = static_cast<ImGuiID>(dockspace_id);
  ImGui::DockBuilderRemoveNode(id);
  ImGui::DockBuilderAddNode(id, ImGuiDockNodeFlags_DockSpace);
  ImGui::DockBuilderSetNodeSize(id, ImGui::GetMainViewport()->Size);

  ImGuiID dock_main = id;
  const ImGuiID dock_left = ImGui::DockBuilderSplitNode(dock_main, ImGuiDir_Left, 0.18f, nullptr, &dock_main);
  const ImGuiID dock_bottom = ImGui::DockBuilderSplitNode(dock_main, ImGuiDir_Down, 0.28f, nullptr, &dock_main);

  ImGui::DockBuilderDockWindow("Hierarchy", dock_left);
  ImGui::DockBuilderDockWindow("Console", dock_bottom);
  ImGui::DockBuilderDockWindow("Viewport", dock_main);

  ImGui::DockBuilderFinish(id);
}

void ImGuiLayer::DrawMainMenuBar() {
  if (!ImGui::BeginMainMenuBar()) {
    return;
  }

  if (ImGui::BeginMenu("File")) {
    ImGui::MenuItem("Quit", "Alt+F4", nullptr, false);
    ImGui::EndMenu();
  }

  if (ImGui::BeginMenu("View")) {
    if (show_viewport_) ImGui::MenuItem("Viewport", nullptr, show_viewport_);
    if (show_hierarchy_) ImGui::MenuItem("Hierarchy", nullptr, show_hierarchy_);
    if (show_console_) ImGui::MenuItem("Console", nullptr, show_console_);
    ImGui::Separator();
    if (viewport_no_titlebar_) {
      ImGui::MenuItem("Hide Viewport Title Bar", nullptr, viewport_no_titlebar_);
    }
    if (ImGui::MenuItem("Reset Layout")) {
      needs_default_layout_ = true;
    }
    ImGui::Separator();
    ImGui::MenuItem("ImGui Demo", nullptr, &show_demo_);
    ImGui::EndMenu();
  }

  if (ImGui::BeginMenu("Help")) {
    ImGui::TextDisabled("Toggle UI: `");
    ImGui::TextDisabled("Borderless: F11");
    ImGui::EndMenu();
  }

  ImGui::EndMainMenuBar();
}

void ImGuiLayer::SetupStyle(float dpi_scale) {
  ImGui::StyleColorsDark();

  ImGuiStyle& style = ImGui::GetStyle();
  style.WindowRounding = 8.0f;
  style.FrameRounding = 8.0f;
  style.GrabRounding = 8.0f;
  style.TabRounding = 8.0f;
  style.ScrollbarRounding = 8.0f;
  style.WindowBorderSize = 1.0f;
  style.FrameBorderSize = 0.0f;
  style.WindowMenuButtonPosition = ImGuiDir_None;
  style.ScaleAllSizes(dpi_scale);

  // clang-format off
  auto& colors = style.Colors;
  colors[ImGuiCol_WindowBg]           = ImVec4{0.10f, 0.105f,  0.11f,  1.0f};
  colors[ImGuiCol_Header]             = ImVec4{0.20f, 0.205f,  0.21f,  1.0f};
  colors[ImGuiCol_HeaderHovered]      = ImVec4{0.30f, 0.305f,  0.31f,  1.0f};
  colors[ImGuiCol_HeaderActive]       = ImVec4{0.15f, 0.1505f, 0.151f, 1.0f};
  colors[ImGuiCol_Button]             = ImVec4{0.20f, 0.205f,  0.21f,  1.0f};
  colors[ImGuiCol_ButtonHovered]      = ImVec4{0.30f, 0.305f,  0.31f,  1.0f};
  colors[ImGuiCol_ButtonActive]       = ImVec4{0.15f, 0.1505f, 0.151f, 1.0f};
  colors[ImGuiCol_FrameBg]            = ImVec4{0.20f, 0.205f,  0.21f,  1.0f};
  colors[ImGuiCol_FrameBgHovered]     = ImVec4{0.30f, 0.305f,  0.31f,  1.0f};
  colors[ImGuiCol_FrameBgActive]      = ImVec4{0.15f, 0.1505f, 0.151f, 1.0f};
  colors[ImGuiCol_Tab]                = ImVec4{0.15f, 0.1505f, 0.151f, 1.0f};
  colors[ImGuiCol_TabHovered]         = ImVec4{0.38f, 0.3805f, 0.381f, 1.0f};
  colors[ImGuiCol_TabActive]          = ImVec4{0.28f, 0.2805f, 0.281f, 1.0f};
  colors[ImGuiCol_TabUnfocused]       = ImVec4{0.15f, 0.1505f, 0.151f, 1.0f};
  colors[ImGuiCol_TabUnfocusedActive] = ImVec4{0.20f, 0.205f,  0.21f,  1.0f};
  colors[ImGuiCol_TitleBg]            = ImVec4{0.15f, 0.1505f, 0.151f, 1.0f};
  colors[ImGuiCol_TitleBgActive]      = ImVec4{0.15f, 0.1505f, 0.151f, 1.0f};
  colors[ImGuiCol_TitleBgCollapsed]   = ImVec4{0.15f, 0.1505f, 0.151f, 1.0f};
  colors[ImGuiCol_DockingEmptyBg]     = ImVec4{0.0f,  0.0f,    0.0f,   0.0f};
  // clang-format on
}

void ImGuiLayer::LoadFonts(float dpi_scale) {
  // ImGui rasterises at the requested pt size — multiply by DPI scale so the
  // glyphs are sharp on HiDPI. raylib draws (engine::text) follow the same
  // rule, so a "size 18" string renders the same height in both worlds.
  //
  // Mirror engine::text's font + glyph-range choice based on the active
  // codepoint set, so a Chinese string renders identically whether it goes
  // through DrawTextEx or ImGui::Text.
  ImGuiIO& io = ImGui::GetIO();
  const float font_size = kImGuiBaseFontSize * dpi_scale;
  const bool cjk = (engine::GetCodepointSet() == engine::CodepointSet::AsciiPlusCJK);
  const std::filesystem::path path =
      cjk ? std::filesystem::path{"assets/fonts/noto/NotoSansSC-Regular.ttf"}
          : std::filesystem::path{"assets/fonts/noto/NotoSans-Regular.ttf"};
  const ImWchar* ranges =
      cjk ? io.Fonts->GetGlyphRangesChineseFull() : io.Fonts->GetGlyphRangesDefault();

  io.Fonts->Clear();
  if (std::filesystem::exists(path)) {
    io.FontDefault = io.Fonts->AddFontFromFileTTF(path.string().c_str(), font_size, nullptr, ranges);
  }
  if (io.FontDefault == nullptr) {
    io.FontDefault = io.Fonts->AddFontDefault();
  }
}

float ImGuiLayer::GetDpiScale() {
  Vector2 dpi = GetWindowScaleDPI();
  return std::max(1.0f, std::max(dpi.x, dpi.y));
}
