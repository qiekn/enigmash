#pragma once

#include <string>

namespace game { class World; }

namespace scenes::editor {

// Mutable state shared across the editor panels for one scene
// instance. Held by GameplayScene; lives only as long as the scene.
struct State {
  std::string brush;        // currently-selected ObjectDef name; empty = nothing
  int cursor_x = 0;
  int cursor_y = 0;
  bool show_catalog = true;
  bool show_painter = true;
  bool show_inspector = true;
};

// Read-only browser over ObjectsRegistry. Click a row to set the
// active brush. Sprite preview is the def's fallback color so the
// catalog is meaningful before any sprite art ships.
void DrawCatalog(State& s, game::World& w);

// Coordinate inputs + a small surrounding canvas. Click a canvas cell
// to set the cursor and drop the active brush there. Erase wipes
// everything at the cursor.
void DrawPainter(State& s, game::World& w);

// Lists every entity at (cursor_x, cursor_y) and shows its components.
// No mutation — pair with the Painter for changes.
void DrawInspector(State& s, const game::World& w);

// Tiny menu for global actions: reload world from JSON (drops registry
// and rebuilds, losing painter state — that's the point of "hot
// reload": pick up external edits to objects.json / world/*.json).
void DrawMenu(State& s, game::World& w, bool& reload_request);

}  // namespace scenes::editor
