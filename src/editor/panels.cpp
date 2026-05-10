#include "editor/panels.h"

#include <imgui.h>

#include <cstdint>
#include <vector>

#include <magic_enum/magic_enum.hpp>

#include "game/components.h"
#include "game/objects_registry.h"
#include "game/world.h"

namespace editor {

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

// Find which region's bbox contains (x, y). Returns -1 for "no region"
// (entity sits outside every loaded region — gets bucketed under
// "Unassigned" in the hierarchy).
int RegionIndexFor(const game::World& w, int x, int y) {
  const auto& regs = w.Regions();
  for (size_t i = 0; i < regs.size(); ++i) {
    const auto& r = regs[i];
    if (x >= r.min_x && x < r.max_x && y >= r.min_y && y < r.max_y) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

// Cosmetic — a Pushable shows as "crate" in the hierarchy regardless
// of its per-region sprite variant.
const char* EntityLabel(const entt::registry& reg, entt::entity e) {
  if (reg.all_of<game::Player>(e)) return "player";
  if (reg.all_of<game::Pushable>(e)) return "crate";
  return "entity";
}

// Render the read-only flag list shared by the cursor view and the
// selection view of the Inspector.
void DrawEntityFlags(const entt::registry& reg, entt::entity e, const game::World& w) {
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
  if (auto* cv = reg.try_get<game::Conveyor>(e)) {
    ImGui::Text("  + Conveyor dir=%d", (int)cv->dir);
  }
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

void DrawHierarchy(State& s, const game::World& w) {
  if (!s.show_hierarchy) return;
  if (!ImGui::Begin("Hierarchy", &s.show_hierarchy)) {
    ImGui::End();
    return;
  }

  const auto& reg = w.Registry();
  const auto& regs = w.Regions();

  // Bucket dynamic entities (Player + Pushable, sans Hidden) by region
  // index. The +1 slot is for entities outside every region bbox.
  std::vector<std::vector<entt::entity>> buckets(regs.size() + 1);
  auto bucket_of = [&](entt::entity e) -> std::vector<entt::entity>& {
    const auto& c = reg.get<game::Cell>(e);
    const int idx = RegionIndexFor(w, c.x, c.y);
    return idx < 0 ? buckets.back() : buckets[idx];
  };

  for (auto [e, c] : reg.view<const game::Cell, const game::Player>().each()) {
    if (reg.all_of<game::Hidden>(e)) continue;
    bucket_of(e).push_back(e);
  }
  for (auto [e, c] : reg.view<const game::Cell, const game::Pushable>().each()) {
    if (reg.all_of<game::Hidden>(e)) continue;
    bucket_of(e).push_back(e);
  }

  auto draw_row = [&](entt::entity e) {
    ImGui::PushID((int)entt::to_integral(e));
    const auto& c = reg.get<game::Cell>(e);
    const char* label = EntityLabel(reg, e);
    char row[64];
    std::snprintf(row, sizeof(row), "%s #%u  (%d, %d)",
                  label, (unsigned)entt::to_integral(e), c.x, c.y);
    if (ImGui::Selectable(row, s.selected == e)) {
      s.selected = e;
    }
    ImGui::PopID();
  };

  for (size_t i = 0; i < regs.size(); ++i) {
    const auto& r = regs[i];
    char header[96];
    std::snprintf(header, sizeof(header), "%s  [%zu]",
                  std::string{magic_enum::enum_name(r.kind)}.c_str(),
                  buckets[i].size());
    if (ImGui::TreeNodeEx(header, ImGuiTreeNodeFlags_DefaultOpen)) {
      if (buckets[i].empty()) ImGui::TextDisabled("(empty)");
      for (auto e : buckets[i]) draw_row(e);
      ImGui::TreePop();
    }
  }

  if (!buckets.back().empty()) {
    char header[64];
    std::snprintf(header, sizeof(header), "Unassigned  [%zu]", buckets.back().size());
    if (ImGui::TreeNodeEx(header)) {
      for (auto e : buckets.back()) draw_row(e);
      ImGui::TreePop();
    }
  }

  ImGui::End();
}

void DrawInspector(State& s, game::World& w) {
  if (!s.show_inspector) return;
  if (!ImGui::Begin("Inspector", &s.show_inspector)) {
    ImGui::End();
    return;
  }

  auto& reg = w.Registry();

  // Selection-priority: when a hierarchy row is active and still valid,
  // show that entity with editable Cell. Otherwise fall back to the
  // cursor-based listing so the Painter workflow still has its readout.
  if (s.selected != entt::null && reg.valid(s.selected) && reg.all_of<game::Cell>(s.selected)) {
    const entt::entity e = s.selected;
    auto& c = reg.get<game::Cell>(e);

    ImGui::Text("%s #%u", EntityLabel(reg, e), (unsigned)entt::to_integral(e));
    ImGui::Separator();

    int xy[2] = {c.x, c.y};
    if (ImGui::InputInt2("cell", xy)) {
      c.x = xy[0];
      c.y = xy[1];
      // Snap the spring target to the new cell so the move is immediate.
      // Otherwise the renderer keeps lerping from the old VisualXY and
      // the user sees the entity drift across the world.
      if (auto* v = reg.try_get<game::VisualXY>(e)) {
        v->x = (float)(c.x * game::kTilePx);
        v->y = (float)(c.y * game::kTilePx);
        v->vx = 0.0f;
        v->vy = 0.0f;
      }
    }
    ImGui::Separator();
    DrawEntityFlags(reg, e, w);

    ImGui::Spacing();
    if (ImGui::SmallButton("clear selection")) s.selected = entt::null;

    ImGui::End();
    return;
  }

  ImGui::Text("cell (%d, %d)", s.cursor_x, s.cursor_y);
  ImGui::TextDisabled("(no entity selected — pick one from Hierarchy)");
  ImGui::Separator();

  int hits = 0;
  for (auto [e, c] : reg.view<const game::Cell>().each()) {
    if (c.x != s.cursor_x || c.y != s.cursor_y) continue;
    ++hits;
    ImGui::PushID((int)entt::to_integral(e));
    ImGui::Text("entity %u", (unsigned)entt::to_integral(e));
    DrawEntityFlags(reg, e, w);
    ImGui::PopID();
  }
  if (hits == 0) ImGui::TextDisabled("(no entities here)");
  ImGui::End();
}

void DrawMenu(State& s, game::World& w, bool& reload_request) {
  if (ImGui::Begin("Editor")) {
    ImGui::Checkbox("Catalog", &s.show_catalog); ImGui::SameLine();
    ImGui::Checkbox("Painter", &s.show_painter); ImGui::SameLine();
    ImGui::Checkbox("Inspector", &s.show_inspector); ImGui::SameLine();
    ImGui::Checkbox("Hierarchy", &s.show_hierarchy);
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

}  // namespace editor
