#include "scenes/credits_scene.h"

#include <raylib.h>

#include "engine/scene_manager.h"
#include "engine/text.h"
#include "scenes/main_menu_scene.h"
#include "theme.h"

namespace scenes {

namespace {
constexpr const char* kLines[] = {
    "enigmash",
    "",
    "original puzzlescript : JackLance (p.i. / sqrt3)",
    "this clone            : qiekn",
    "fonts                 : Google Noto Sans / Noto Sans SC",
    "engine                : raylib + Dear ImGui",
};
}  // namespace

void CreditsScene::OnUpdate(float /*dt*/) {
  if (IsKeyPressed(KEY_ESCAPE) || IsKeyPressed(KEY_ENTER)) {
    Manager()->Switch<MainMenuScene>();
  }
}

void CreditsScene::OnRender(int w, int h) {
  ClearBackground(theme::kBackground);

  // Stack the credit lines vertically; the first line is the title (big),
  // the rest are body text.
  constexpr int kTitleSize = 40;
  constexpr int kBodySize = 20;
  constexpr float kBodyStep = 32.0f;

  const Vector2 title_size = engine::MeasureText(kLines[0], kTitleSize);
  engine::DrawText(kLines[0],
                   Vector2{(w - title_size.x) * 0.5f, h * 0.18f},
                   kTitleSize, RAYWHITE);

  const int n = static_cast<int>(sizeof(kLines) / sizeof(kLines[0]));
  const float start_y = h * 0.18f + 80.0f;
  for (int i = 1; i < n; ++i) {
    const Vector2 ls = engine::MeasureText(kLines[i], kBodySize);
    engine::DrawText(kLines[i],
                     Vector2{(w - ls.x) * 0.5f, start_y + (i - 1) * kBodyStep},
                     kBodySize, Color{200, 200, 220, 255});
  }

  engine::DrawText("press esc to return", Vector2{16.0f, h - 30.0f}, 16,
                   Color{140, 140, 160, 200});
}

}  // namespace scenes
