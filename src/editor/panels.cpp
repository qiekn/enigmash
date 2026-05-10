#include "editor/panels.h"

#include <imgui.h>
#include <raylib.h>

#include <algorithm>
#include <cstdint>
#include <unordered_set>
#include <utility>
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

// -----------------------------------------------------------------------------: tool helpers

// Bresenham. One cell per step, inclusive endpoints.
std::vector<std::pair<int, int>> RasterLine(int x0, int y0, int x1, int y1) {
  std::vector<std::pair<int, int>> out;
  int dx = std::abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
  int dy = -std::abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
  int err = dx + dy;
  int x = x0, y = y0;
  for (;;) {
    out.emplace_back(x, y);
    if (x == x1 && y == y1) break;
    const int e2 = 2 * err;
    if (e2 >= dy) { err += dy; x += sx; }
    if (e2 <= dx) { err += dx; y += sy; }
  }
  return out;
}

std::vector<std::pair<int, int>> RasterRectOutline(int x0, int y0, int x1, int y1) {
  std::vector<std::pair<int, int>> out;
  const int lx = std::min(x0, x1), rx = std::max(x0, x1);
  const int ly = std::min(y0, y1), ry = std::max(y0, y1);
  for (int x = lx; x <= rx; ++x) {
    out.emplace_back(x, ly);
    if (ry != ly) out.emplace_back(x, ry);
  }
  for (int y = ly + 1; y <= ry - 1; ++y) {
    out.emplace_back(lx, y);
    if (rx != lx) out.emplace_back(rx, y);
  }
  return out;
}

std::vector<std::pair<int, int>> RasterRectFilled(int x0, int y0, int x1, int y1) {
  std::vector<std::pair<int, int>> out;
  const int lx = std::min(x0, x1), rx = std::max(x0, x1);
  const int ly = std::min(y0, y1), ry = std::max(y0, y1);
  for (int y = ly; y <= ry; ++y)
    for (int x = lx; x <= rx; ++x) out.emplace_back(x, y);
  return out;
}

std::vector<std::pair<int, int>> RasterCells(Tool t, int x0, int y0, int x1, int y1) {
  switch (t) {
    case Tool::Line:        return RasterLine(x0, y0, x1, y1);
    case Tool::RectOutline: return RasterRectOutline(x0, y0, x1, y1);
    case Tool::RectFilled:  return RasterRectFilled(x0, y0, x1, y1);
    default:                return {};
  }
}

// Sorted set of sprite atlas ids at (x, y). Used as the flood-fill
// signature: cells with the same set are considered "same content".
std::vector<uint32_t> CellSignature(const game::World& w, int x, int y) {
  std::vector<uint32_t> sig;
  const auto& reg = w.Registry();
  for (auto [e, c, sp] : reg.view<const game::Cell, const game::Sprite>().each()) {
    if (c.x == x && c.y == y) sig.push_back(sp.atlas_id);
  }
  std::sort(sig.begin(), sig.end());
  return sig;
}

// 4-neighbor flood, clamped to the world bbox so an "empty" seed
// outside the loaded regions doesn't try to paint to infinity.
std::vector<std::pair<int, int>> FloodRegion(const game::World& w, int sx, int sy) {
  const auto b = w.GetBounds();
  if (sx < b.min_x || sx >= b.max_x || sy < b.min_y || sy >= b.max_y) return {};
  const auto target = CellSignature(w, sx, sy);

  auto pack = [](int x, int y) -> int64_t {
    return (static_cast<int64_t>(x) << 32) ^ static_cast<uint32_t>(y);
  };
  std::unordered_set<int64_t> seen;
  std::vector<std::pair<int, int>> out, stack;
  stack.emplace_back(sx, sy);
  seen.insert(pack(sx, sy));
  while (!stack.empty()) {
    auto [cx, cy] = stack.back();
    stack.pop_back();
    if (CellSignature(w, cx, cy) != target) continue;
    out.emplace_back(cx, cy);
    static constexpr int nbr[4][2] = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
    for (auto& d : nbr) {
      const int nx = cx + d[0], ny = cy + d[1];
      if (nx < b.min_x || nx >= b.max_x || ny < b.min_y || ny >= b.max_y) continue;
      if (!seen.insert(pack(nx, ny)).second) continue;
      stack.emplace_back(nx, ny);
    }
  }
  return out;
}

// Skip if the cell already carries an entity with the same sprite —
// dragging across a row shouldn't keep stacking duplicates.
void PlaceBrushAt(const State& s, game::World& w, int x, int y) {
  if (s.brush.empty()) return;
  const auto* def = w.Objects().Find(s.brush);
  if (def == nullptr) return;
  const auto& reg = w.Registry();
  for (auto [e, c, sp] : reg.view<const game::Cell, const game::Sprite>().each()) {
    if (c.x == x && c.y == y && sp.atlas_id == def->sprite_id) return;
  }
  w.Spawn(s.brush, x, y);
}

void EraseAt(game::World& w, int x, int y) {
  auto& reg = w.Registry();
  std::vector<entt::entity> kill;
  for (auto [e, c] : reg.view<const game::Cell>().each()) {
    if (c.x == x && c.y == y) kill.push_back(e);
  }
  for (auto e : kill) reg.destroy(e);
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
    ImGui::Checkbox("Hierarchy", &s.show_hierarchy); ImGui::SameLine();
    ImGui::Checkbox("Tools", &s.show_toolbar); ImGui::SameLine();
    ImGui::Checkbox("Grid", &s.show_grid_settings);
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

void DrawToolbar(State& s) {
  if (!s.show_toolbar) return;
  if (!ImGui::Begin("Tools", &s.show_toolbar)) {
    ImGui::End();
    return;
  }

  struct Btn { const char* label; Tool t; ImGuiKey shortcut; };
  static constexpr Btn kBtns[] = {
      {"Brush",  Tool::Brush,       ImGuiKey_B},
      {"Line",   Tool::Line,        ImGuiKey_L},
      {"RectO",  Tool::RectOutline, ImGuiKey_None},
      {"RectF",  Tool::RectFilled,  ImGuiKey_F},
      {"Bucket", Tool::Bucket,      ImGuiKey_G},
      {"Eraser", Tool::Eraser,      ImGuiKey_E},
  };

  for (size_t i = 0; i < std::size(kBtns); ++i) {
    if (i > 0) ImGui::SameLine();
    const bool active = (s.tool == kBtns[i].t);
    if (active) ImGui::PushStyleColor(ImGuiCol_Button, ImVec4{0.40f, 0.50f, 0.30f, 1.0f});
    if (ImGui::Button(kBtns[i].label)) s.tool = kBtns[i].t;
    if (active) ImGui::PopStyleColor();
  }
  ImGui::TextDisabled("shortcuts: 1..6 / B L F G E");

  // Suppress shortcuts when a text widget owns input — typing "F" into
  // the Inspector's int field shouldn't switch tools.
  if (!ImGui::GetIO().WantCaptureKeyboard) {
    static constexpr ImGuiKey kNum[] = {ImGuiKey_1, ImGuiKey_2, ImGuiKey_3,
                                        ImGuiKey_4, ImGuiKey_5, ImGuiKey_6};
    for (size_t i = 0; i < std::size(kNum); ++i) {
      if (ImGui::IsKeyPressed(kNum[i])) s.tool = kBtns[i].t;
    }
    for (const auto& b : kBtns) {
      if (b.shortcut != ImGuiKey_None && ImGui::IsKeyPressed(b.shortcut)) {
        s.tool = b.t;
      }
    }
  }
  ImGui::End();
}

void HandleEditorMouse(State& s, game::World& w) {
  // Releasing while ImGui owns the mouse (e.g. cursor over a panel)
  // still needs to terminate any in-flight drag — otherwise dragging_
  // sticks until the next viewport click.
  const bool lmb_pressed = IsMouseButtonPressed(MOUSE_BUTTON_LEFT);
  const bool lmb_released = IsMouseButtonReleased(MOUSE_BUTTON_LEFT);
  const bool lmb_down = IsMouseButtonDown(MOUSE_BUTTON_LEFT);
  const bool rmb_pressed = IsMouseButtonPressed(MOUSE_BUTTON_RIGHT);

  if (ImGui::GetIO().WantCaptureMouse || !s.hover_valid) {
    if (lmb_released || rmb_pressed) s.dragging = false;
    return;
  }

  const int col = s.hover_x;
  const int row = s.hover_y;

  auto commit_shape = [&](bool erase) {
    auto cells = RasterCells(s.tool, s.drag_start_x, s.drag_start_y, col, row);
    for (auto [x, y] : cells) {
      if (erase) EraseAt(w, x, y);
      else PlaceBrushAt(s, w, x, y);
    }
  };

  switch (s.tool) {
    case Tool::Brush:
      if (lmb_down) PlaceBrushAt(s, w, col, row);
      break;
    case Tool::Line:
    case Tool::RectOutline:
    case Tool::RectFilled:
      if (lmb_pressed) {
        s.dragging = true;
        s.drag_start_x = col;
        s.drag_start_y = row;
      }
      if (lmb_released && s.dragging) {
        commit_shape(false);
        s.dragging = false;
      }
      if (rmb_pressed) s.dragging = false;
      break;
    case Tool::Bucket:
      if (lmb_pressed) {
        auto cells = FloodRegion(w, col, row);
        for (auto [x, y] : cells) PlaceBrushAt(s, w, x, y);
      }
      break;
    case Tool::Eraser:
      if (lmb_down) EraseAt(w, col, row);
      break;
  }
}

void DrawDragPreview(const State& s) {
  if (!s.dragging || !s.hover_valid) return;
  auto cells = RasterCells(s.tool, s.drag_start_x, s.drag_start_y, s.hover_x, s.hover_y);
  if (cells.empty()) return;
  const Color tint = (s.tool == Tool::Eraser) ? Color{235, 90, 90, 110}
                                              : Color{255, 220, 0, 110};
  for (auto [x, y] : cells) {
    DrawRectangle(x * game::kTilePx, y * game::kTilePx,
                  game::kTilePx, game::kTilePx, tint);
  }
}

void DrawGridBackground(const State& s, const game::World& w) {
  const auto b = w.GetBounds();
  if (b.max_x <= b.min_x || b.max_y <= b.min_y) return;
  DrawRectangle(b.min_x * game::kTilePx, b.min_y * game::kTilePx,
                (b.max_x - b.min_x) * game::kTilePx,
                (b.max_y - b.min_y) * game::kTilePx, s.bg_color);
}

void DrawGridOverlay(const State& s, const game::World& w) {
  if (!s.show_grid) return;
  const auto b = w.GetBounds();
  if (b.max_x <= b.min_x || b.max_y <= b.min_y) return;

  Color line = s.grid_color;
  line.a = static_cast<unsigned char>(
      std::clamp(static_cast<float>(line.a) * s.grid_opacity, 0.0f, 255.0f));
  const float t = std::max(0.5f, s.grid_thickness);
  const float pitch = static_cast<float>(game::kTilePx);
  const float ox = static_cast<float>(b.min_x) * pitch;
  const float oy = static_cast<float>(b.min_y) * pitch;
  const float w_px = static_cast<float>(b.max_x - b.min_x) * pitch;
  const float h_px = static_cast<float>(b.max_y - b.min_y) * pitch;
  const int cols = b.max_x - b.min_x;
  const int rows = b.max_y - b.min_y;

  // Verticals span full height. Horizontals are segmented between
  // verticals so intersections aren't painted twice (keeps alpha
  // uniform). Same trick as baba's DrawGridOverlay.
  for (int col = 0; col <= cols; ++col) {
    const float x = ox + col * pitch - t * 0.5f;
    DrawRectangleRec({x, oy - t * 0.5f, t, h_px + t}, line);
  }
  for (int row = 0; row <= rows; ++row) {
    const float y = oy + row * pitch - t * 0.5f;
    for (int col = 0; col < cols; ++col) {
      const float x = ox + col * pitch + t * 0.5f;
      const float w = std::max(0.0f, pitch - t);
      DrawRectangleRec({x, y, w, t}, line);
    }
  }
}

void DrawGridSettings(State& s) {
  if (!s.show_grid_settings) return;
  if (!ImGui::Begin("Grid", &s.show_grid_settings)) {
    ImGui::End();
    return;
  }
  ImGui::Checkbox("Show grid", &s.show_grid);

  auto col_to_f = [](Color c) {
    return ImVec4{c.r / 255.0f, c.g / 255.0f, c.b / 255.0f, c.a / 255.0f};
  };
  auto f_to_col = [](float v) {
    return static_cast<unsigned char>(std::clamp(v * 255.0f, 0.0f, 255.0f));
  };

  ImVec4 bg = col_to_f(s.bg_color);
  if (ImGui::ColorEdit4("Background", &bg.x, ImGuiColorEditFlags_NoInputs)) {
    s.bg_color = Color{f_to_col(bg.x), f_to_col(bg.y), f_to_col(bg.z), f_to_col(bg.w)};
  }
  ImVec4 gc = col_to_f(s.grid_color);
  if (ImGui::ColorEdit4("Grid line", &gc.x, ImGuiColorEditFlags_NoInputs)) {
    s.grid_color = Color{f_to_col(gc.x), f_to_col(gc.y), f_to_col(gc.z), f_to_col(gc.w)};
  }
  ImGui::SliderFloat("Opacity", &s.grid_opacity, 0.0f, 1.0f, "%.2f");
  ImGui::SliderFloat("Thickness", &s.grid_thickness, 0.5f, 6.0f, "%.1f px");
  ImGui::End();
}

}  // namespace editor
