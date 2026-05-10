#pragma once

#include <entt/entt.hpp>

#include <cstdint>
#include <string>

namespace game { class World; }

namespace editor {

// Available drawing tools. Mirrors baba's set minus Select (clipboard
// paste isn't implemented yet — add when it's actually needed).
enum class Tool : uint8_t {
  Brush,
  Line,
  RectOutline,
  RectFilled,
  Bucket,
  Eraser,
};

// Mutable state shared across the editor panels for one scene
// instance. Held by GameplayScene; lives only as long as the scene.
struct State {
  std::string brush;        // currently-selected ObjectDef name; empty = nothing
  int cursor_x = 0;
  int cursor_y = 0;
  bool show_catalog = true;
  bool show_painter = true;
  bool show_inspector = true;
  bool show_hierarchy = true;
  bool show_toolbar = true;

  // Hierarchy → Inspector wiring. When valid, Inspector shows this
  // entity and offers cell editing; cleared on world reload because
  // entity ids would dangle against the new registry.
  entt::entity selected = entt::null;

  // Tool palette state. `hover_*` is written by GameplayScene each
  // frame from the viewport mouse projection — HandleEditorMouse and
  // DrawDragPreview both read it. `dragging` is set by HandleEditorMouse
  // on lmb-press for shape tools, cleared on release / cancel.
  Tool tool = Tool::Brush;
  bool dragging = false;
  int drag_start_x = 0;
  int drag_start_y = 0;
  int hover_x = 0;
  int hover_y = 0;
  bool hover_valid = false;
};

// Read-only browser over ObjectsRegistry. Click a row to set the
// active brush. Sprite preview is the def's fallback color so the
// catalog is meaningful before any sprite art ships.
void DrawCatalog(State& s, game::World& w);

// Coordinate inputs + a small surrounding canvas. Click a canvas cell
// to set the cursor and drop the active brush there. Erase wipes
// everything at the cursor.
void DrawPainter(State& s, game::World& w);

// Region-bucketed tree of the dynamic entities (Player + Pushable).
// Click a row to set State::selected; Inspector picks that up.
void DrawHierarchy(State& s, const game::World& w);

// Selection-priority. When `s.selected` is valid, shows that entity
// with editable Cell. Otherwise falls back to the cursor-based
// listing so the Painter workflow still has its readout.
void DrawInspector(State& s, game::World& w);

// Tiny menu for global actions: reload world from JSON (drops registry
// and rebuilds, losing painter state — that's the point of "hot
// reload": pick up external edits to objects.json / world/*.json).
void DrawMenu(State& s, game::World& w, bool& reload_request);

// Tool selector + keyboard shortcuts (1..6 / B L F G E). Reads
// `WantCaptureKeyboard` so shortcuts don't fire while a text widget
// has focus.
void DrawToolbar(State& s);

// Mouse → action dispatch. Caller must populate `s.hover_*` /
// `s.hover_valid` first (typically from the viewport projection).
// Honours `WantCaptureMouse` so clicks over other ImGui windows
// don't paint underneath them.
void HandleEditorMouse(State& s, game::World& w);

// Draws the in-flight drag shape (line / rect outline / rect filled)
// as semi-transparent fills in world coords. Call inside BeginMode2D
// so units == world pixels.
void DrawDragPreview(const State& s);

}  // namespace editor
