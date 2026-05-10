#pragma once

#include <entt/entt.hpp>

#include <string>

namespace game { class World; }

namespace editor {

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

  // Hierarchy → Inspector wiring. When valid, Inspector shows this
  // entity and offers cell editing; cleared on world reload because
  // entity ids would dangle against the new registry.
  entt::entity selected = entt::null;
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

}  // namespace editor
