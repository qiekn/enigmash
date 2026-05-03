#include "scenes/editor_panels.h"

#include <imgui.h>

#include <cstdint>
#include <vector>

#include "game/components.h"
#include "game/objects_registry.h"
#include "game/world.h"

namespace scenes::editor {

namespace {

constexpr float kCanvasCellPx = 22.0f;
constexpr int kCanvasRange = 7;  // ±7 cells from cursor

ImU32 ImColFromColor(Color c) {
  return IM_COL32(c.r, c.g, c.b, c.a);
}

// Find the topmost (highest ZOrder) entity at a cell so the painter
// canvas previews what would appear on screen there.
const game::ObjectDef* TopmostDefAt(const game::World& w, int x, int y) {
  const auto& reg = w.Registry();
  const game::ObjectDef* best = nullptr;
  int8_t best_layer = -127;
  for (auto [e, c, sp, z] : reg.view<const game::Cell, const game::Sprite, const game::ZOrder>().each()) {
    if (c.x != x || c.y != y) continue;
    if (z.layer < best_layer) continue;
    auto* def = w.Objects().FindBySpriteId(sp.atlas_id);
    if (def == nullptr) continue;
    best = def;
    best_layer = z.layer;
  }
  return best;
}

}  // namespace

void DrawCatalog(State& s, game::World& w) {
  if (!s.show_catalog) return;
  if (!ImGui::Begin("Object Catalog", &s.show_catalog)) {
    ImGui::End();
    return;
  }
  ImGui::TextDisabled("read-only — edit assets/data/objects.json then Reload");
  ImGui::Separator();
  for (const auto& def : w.Objects().All()) {
    ImGui::PushID(def.name.c_str());
    // Color swatch.
    ImDrawList* dl = ImGui::GetWindowDrawList();
    ImVec2 p0 = ImGui::GetCursorScreenPos();
    const float sz = ImGui::GetTextLineHeight();
    dl->AddRectFilled(p0, ImVec2(p0.x + sz, p0.y + sz), ImColFromColor(def.color));
    ImGui::Dummy(ImVec2(sz + 6, sz));
    ImGui::SameLine();

    bool selected = s.brush == def.name;
    if (ImGui::Selectable(def.name.c_str(), selected)) {
      s.brush = def.name;
    }
    if (ImGui::IsItemHovered()) {
      ImGui::SetTooltip("layer=%d  tags=0x%x", (int)def.layer, (unsigned)def.tags);
    }
    ImGui::PopID();
  }
  ImGui::End();
}

void DrawPainter(State& s, game::World& w) {
  if (!s.show_painter) return;
  if (!ImGui::Begin("Tile Painter", &s.show_painter)) {
    ImGui::End();
    return;
  }
  ImGui::Text("Brush: %s", s.brush.empty() ? "(none — pick from Catalog)" : s.brush.c_str());
  ImGui::InputInt("X", &s.cursor_x);
  ImGui::InputInt("Y", &s.cursor_y);

  if (ImGui::Button("Paint") && !s.brush.empty()) {
    w.Spawn(s.brush, s.cursor_x, s.cursor_y);
  }
  ImGui::SameLine();
  if (ImGui::Button("Erase Cell")) {
    auto& reg = w.Registry();
    std::vector<entt::entity> kill;
    for (auto [e, c] : reg.view<game::Cell>().each()) {
      if (c.x == s.cursor_x && c.y == s.cursor_y) kill.push_back(e);
    }
    for (auto e : kill) reg.destroy(e);
  }
  ImGui::Separator();

  // Mini canvas: ±kCanvasRange cells around cursor. Click to move
  // cursor + drop brush. Each tile is filled with the topmost def's
  // color so the canvas is a low-fi mirror of the actual viewport.
  const float side = kCanvasCellPx * (2 * kCanvasRange + 1);
  ImVec2 origin = ImGui::GetCursorScreenPos();
  ImDrawList* dl = ImGui::GetWindowDrawList();

  for (int dy = -kCanvasRange; dy <= kCanvasRange; ++dy) {
    for (int dx = -kCanvasRange; dx <= kCanvasRange; ++dx) {
      const int wx = s.cursor_x + dx;
      const int wy = s.cursor_y + dy;
      const ImVec2 p0{origin.x + (dx + kCanvasRange) * kCanvasCellPx,
                      origin.y + (dy + kCanvasRange) * kCanvasCellPx};
      const ImVec2 p1{p0.x + kCanvasCellPx, p0.y + kCanvasCellPx};

      const game::ObjectDef* def = TopmostDefAt(w, wx, wy);
      ImU32 fill = def ? ImColFromColor(def->color) : IM_COL32(28, 28, 32, 255);
      dl->AddRectFilled(p0, p1, fill);
      dl->AddRect(p0, p1, IM_COL32(70, 70, 80, 255));
      if (dx == 0 && dy == 0) {
        dl->AddRect(p0, p1, IM_COL32(255, 220, 0, 255), 0, 0, 2.5f);
      }
    }
  }

  ImGui::InvisibleButton("painter_canvas", ImVec2(side, side));
  if (ImGui::IsItemClicked()) {
    ImVec2 mp = ImGui::GetMousePos();
    const int gx = (int)((mp.x - origin.x) / kCanvasCellPx);
    const int gy = (int)((mp.y - origin.y) / kCanvasCellPx);
    if (gx >= 0 && gx <= 2 * kCanvasRange && gy >= 0 && gy <= 2 * kCanvasRange) {
      s.cursor_x = (s.cursor_x - kCanvasRange) + gx;
      s.cursor_y = (s.cursor_y - kCanvasRange) + gy;
      if (!s.brush.empty()) {
        w.Spawn(s.brush, s.cursor_x, s.cursor_y);
      }
    }
  }
  ImGui::End();
}

void DrawInspector(State& s, const game::World& w) {
  if (!s.show_inspector) return;
  if (!ImGui::Begin("Inspector", &s.show_inspector)) {
    ImGui::End();
    return;
  }
  ImGui::Text("cell (%d, %d)", s.cursor_x, s.cursor_y);
  ImGui::Separator();

  const auto& reg = w.Registry();
  int hits = 0;
  for (auto [e, c] : reg.view<const game::Cell>().each()) {
    if (c.x != s.cursor_x || c.y != s.cursor_y) continue;
    ++hits;
    ImGui::PushID((int)entt::to_integral(e));
    ImGui::Text("entity %u", (unsigned)entt::to_integral(e));
    if (auto* sp = reg.try_get<game::Sprite>(e)) {
      auto* def = w.Objects().FindBySpriteId(sp->atlas_id);
      ImGui::Text("  kind: %s", def ? def->name.c_str() : "?");
    }
    if (auto* z = reg.try_get<game::ZOrder>(e)) {
      ImGui::Text("  layer: %d", (int)z->layer);
    }
    if (reg.all_of<game::Player>(e)) ImGui::TextDisabled("  + Player");
    if (reg.all_of<game::Pushable>(e)) ImGui::TextDisabled("  + Pushable");
    if (reg.all_of<game::Stop>(e)) ImGui::TextDisabled("  + Stop");
    if (reg.all_of<game::Goal>(e)) ImGui::TextDisabled("  + Goal");
    if (reg.all_of<game::Checkpoint>(e)) ImGui::TextDisabled("  + Checkpoint");
    if (auto* l = reg.try_get<game::Linked>(e)) {
      ImGui::Text("  + Linked head=%u", (unsigned)entt::to_integral(l->head));
    }
    if (auto* sg = reg.try_get<game::SnakeSegment>(e)) {
      ImGui::Text("  + SnakeSegment order=%u", (unsigned)sg->order);
    }
    ImGui::PopID();
  }
  if (hits == 0) ImGui::TextDisabled("(no entities here)");
  ImGui::End();
}

void DrawMenu(State& s, game::World& w, bool& reload_request) {
  if (ImGui::Begin("Editor")) {
    ImGui::Checkbox("Catalog", &s.show_catalog); ImGui::SameLine();
    ImGui::Checkbox("Painter", &s.show_painter); ImGui::SameLine();
    ImGui::Checkbox("Inspector", &s.show_inspector);
    ImGui::Separator();
    if (ImGui::Button("Reload world from JSON")) {
      reload_request = true;
    }
    ImGui::SameLine();
    ImGui::TextDisabled("(drops painter edits, resets undo/checkpoint)");
    ImGui::Text("brush: %s", s.brush.empty() ? "—" : s.brush.c_str());
    (void)w;
  }
  ImGui::End();
}

}  // namespace scenes::editor
