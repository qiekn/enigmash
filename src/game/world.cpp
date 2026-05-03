#include "game/world.h"

#include <raylib.h>

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <nlohmann/json.hpp>
#include <string>

#include "game/components.h"

namespace game {

bool World::LoadObjects(const std::string& path) {
  if (!objects_.LoadFromFile(path)) return false;
  for (auto& def : objects_.All()) {
    def.sprite_id = sprites_.Register(def.name, def.sprite_path, def.color);
  }
  return true;
}

entt::entity World::Spawn(const std::string& name, int x, int y) {
  const ObjectDef* def = objects_.Find(name);
  if (def == nullptr) {
    TraceLog(LOG_WARNING, "World::Spawn: unknown object '%s'", name.c_str());
    return entt::null;
  }
  entt::entity e = reg_.create();
  reg_.emplace<Cell>(e, x, y);
  reg_.emplace<VisualXY>(e, (float)(x * kTilePx), (float)(y * kTilePx), 0.0f, 0.0f);
  reg_.emplace<Sprite>(e, def->sprite_id);
  reg_.emplace<ZOrder>(e, def->layer);

  if (HasTag(def->tags, Tag::Player)) {
    reg_.emplace<Player>(e);
    reg_.emplace<Facing>(e, Direction::South);
    reg_.emplace<LastToggle>(e);
  }
  if (HasTag(def->tags, Tag::Pushable)) reg_.emplace<Pushable>(e);
  if (HasTag(def->tags, Tag::Stop)) reg_.emplace<Stop>(e);
  if (HasTag(def->tags, Tag::Checkpoint)) reg_.emplace<Checkpoint>(e);
  if (HasTag(def->tags, Tag::Goal)) reg_.emplace<Goal>(e);
  if (HasTag(def->tags, Tag::Toggle)) reg_.emplace<Toggle>(e, def->toggle_radius);
  if (HasTag(def->tags, Tag::Toggleable)) reg_.emplace<Toggleable>(e);
  if (HasTag(def->tags, Tag::SnakeBody)) reg_.emplace<SnakeSegment>(e, (uint8_t)0);

  // Linked clusters: first spawned member becomes its own head, every
  // subsequent member of the same kind joins it. Stored per-tag so two
  // groups (link_a / link_b) coexist independently.
  auto link_first = [&](Tag t, entt::entity& head_slot) {
    if (!HasTag(def->tags, t)) return;
    if (head_slot == entt::null) head_slot = e;
    reg_.emplace<Linked>(e, head_slot);
  };
  link_first(Tag::LinkA, link_a_head_);
  link_first(Tag::LinkB, link_b_head_);
  return e;
}

namespace {

Region RegionFromString(const std::string& s) {
  if (s == "r1_sokoban") return Region::R1Sokoban;
  if (s == "r2_gravity") return Region::R2Gravity;
  if (s == "r3_chain")   return Region::R3Chain;
  if (s == "r4_shoot")   return Region::R4Shoot;
  if (s == "r5_snake")   return Region::R5Snake;
  if (s == "r6_cluster") return Region::R6Cluster;
  return Region::None;
}

// Loads one region file: { width, height, region?, background?, cells: [[[name,...],...]...] }.
// All entities are emplaced at (origin_x + cx, origin_y + cy). Returns
// true on success; updates `out_w` / `out_h` with the region's bounds
// and `out_kind` with the parsed region mechanic (None if unspecified).
bool LoadRegionFile(World& world, const std::string& path, int origin_x, int origin_y,
                    int& out_w, int& out_h, Region& out_kind) {
  std::ifstream in(path);
  if (!in) {
    TraceLog(LOG_ERROR, "World::LoadWorld: cannot open region '%s'", path.c_str());
    return false;
  }
  nlohmann::json j;
  try {
    in >> j;
  } catch (const std::exception& e) {
    TraceLog(LOG_ERROR, "World::LoadWorld: parse error in '%s': %s", path.c_str(), e.what());
    return false;
  }

  const int w = j.value("width", 0);
  const int h = j.value("height", 0);
  const std::string bg = j.value("background", std::string{});
  const std::string region_str = j.value("region", std::string{});
  out_kind = RegionFromString(region_str);
  const auto cells = j.find("cells");
  if (w <= 0 || h <= 0 || cells == j.end() || !cells->is_array()) {
    TraceLog(LOG_ERROR, "World::LoadWorld: '%s' missing width/height/cells", path.c_str());
    return false;
  }

  for (int y = 0; y < h; ++y) {
    if (y >= (int)cells->size() || !(*cells)[y].is_array()) continue;
    const auto& row = (*cells)[y];
    for (int x = 0; x < w; ++x) {
      if (!bg.empty()) world.Spawn(bg, origin_x + x, origin_y + y);
      if (x >= (int)row.size() || !row[x].is_array()) continue;
      for (const auto& name : row[x]) {
        if (name.is_string()) {
          world.Spawn(name.get<std::string>(), origin_x + x, origin_y + y);
        }
      }
    }
  }
  out_w = w;
  out_h = h;
  return true;
}

}  // namespace

bool World::LoadWorld(const std::string& path) {
  std::ifstream in(path);
  if (!in) {
    TraceLog(LOG_ERROR, "World::LoadWorld: cannot open '%s'", path.c_str());
    return false;
  }
  nlohmann::json root;
  try {
    in >> root;
  } catch (const std::exception& e) {
    TraceLog(LOG_ERROR, "World::LoadWorld: parse error in '%s': %s", path.c_str(), e.what());
    return false;
  }
  const auto regions = root.find("regions");
  if (regions == root.end() || !regions->is_array()) {
    TraceLog(LOG_ERROR, "World::LoadWorld: '%s' has no regions[] array", path.c_str());
    return false;
  }

  // Resolve region files relative to the index file's directory so the
  // index can use bare names like "r1.json".
  std::filesystem::path base = std::filesystem::path(path).parent_path();

  bounds_ = Bounds{0, 0, 0, 0};
  regions_.clear();
  bool any = false;

  for (const auto& r : *regions) {
    const auto file_it = r.find("file");
    const auto origin_it = r.find("origin");
    if (file_it == r.end() || !file_it->is_string()) continue;
    int ox = 0, oy = 0;
    if (origin_it != r.end() && origin_it->is_array() && origin_it->size() == 2) {
      ox = (*origin_it)[0].get<int>();
      oy = (*origin_it)[1].get<int>();
    }
    const std::string fpath = (base / file_it->get<std::string>()).string();
    int w = 0, h = 0;
    Region kind = Region::None;
    if (!LoadRegionFile(*this, fpath, ox, oy, w, h, kind)) continue;

    // Index-level region kind override wins over the file-level one so
    // the same region body can be reused under a different mechanic.
    if (auto it = r.find("region"); it != r.end() && it->is_string()) {
      kind = RegionFromString(it->get<std::string>());
    }

    RegionInfo info;
    info.id = r.value("id", std::string{});
    info.kind = kind;
    info.min_x = ox;
    info.min_y = oy;
    info.max_x = ox + w;
    info.max_y = oy + h;
    regions_.push_back(std::move(info));

    if (!any) {
      bounds_ = Bounds{ox, oy, ox + w, oy + h};
      any = true;
    } else {
      bounds_.min_x = std::min(bounds_.min_x, ox);
      bounds_.min_y = std::min(bounds_.min_y, oy);
      bounds_.max_x = std::max(bounds_.max_x, ox + w);
      bounds_.max_y = std::max(bounds_.max_y, oy + h);
    }
  }

  TraceLog(LOG_INFO, "World::LoadWorld: bounds = (%d,%d)..(%d,%d)",
           bounds_.min_x, bounds_.min_y, bounds_.max_x, bounds_.max_y);
  return any;
}

}  // namespace game
