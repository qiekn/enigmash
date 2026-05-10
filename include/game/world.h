#pragma once

#include <entt/entt.hpp>
#include <raylib.h>

#include <string>
#include <vector>

#include "game/components.h"
#include "game/objects_registry.h"
#include "game/sprite_cache.h"

namespace game {

// One tile = kTilePx x kTilePx in render units. The source PNG is 128 px
// (SpriteCache::kSourcePx); the renderer downscales via DrawTexturePro
// with POINT filter so the pixel feel survives.
inline constexpr int kTilePx = 64;

// World holds the EnTT registry plus the per-game asset bundles
// (ObjectsRegistry + SpriteCache). The Gameplay scene owns one of these;
// systems take it by reference. Constructed on the main thread once raylib
// is initialised — sprite atlases need a live GL context.
class World {
 public:
  World() = default;
  World(const World&) = delete;
  World& operator=(const World&) = delete;

  // Loads object catalog + registers their textures (does not upload to
  // GPU yet; call sprites_.EnsureLoaded() afterwards).
  bool LoadObjects(const std::string& objects_json_path);

  // Loads a world index (regions list) and every region file it points
  // to, spawning all entities at their region-relative cell coords plus
  // the region's origin offset. Tracks the bounding box across regions
  // so the camera can frame the whole world (BoundsMin/BoundsMax).
  // Requires LoadObjects to have been called first.
  bool LoadWorld(const std::string& index_json_path);

  // Spawn one entity at a logical cell using the named ObjectDef. Pulls
  // sprite_id, layer, and color through the registry. Returns the entity,
  // or `entt::null` if the name is unknown.
  entt::entity Spawn(const std::string& name, int x, int y);

  // World-space bounding box in cells (inclusive min, exclusive max),
  // computed during LoadWorld. (0,0)..(0,0) when no world is loaded.
  struct Bounds { int min_x, min_y, max_x, max_y; };
  Bounds GetBounds() const { return bounds_; }

  // Per-region metadata stitched together by LoadWorld. Each entry stores
  // its world-space bounding box (origin + size) plus the gameplay
  // mechanic that governs it. RegionUnderPlayer scans this list.
  // If `cell_kind` is non-empty (size == width * height where
  // width = max_x - min_x, etc.), it overrides `kind` per cell: 0 means
  // fall back to `kind`, 1..6 maps to Region enum values 1..6.
  struct RegionInfo {
    std::string id;
    Region kind = Region::None;
    int min_x = 0, min_y = 0, max_x = 0, max_y = 0;
    std::vector<uint8_t> cell_kind;  // row-major, optional
  };
  const std::vector<RegionInfo>& Regions() const { return regions_; }

  entt::registry& Registry() { return reg_; }
  const entt::registry& Registry() const { return reg_; }

  ObjectsRegistry& Objects() { return objects_; }
  const ObjectsRegistry& Objects() const { return objects_; }

  SpriteCache& Sprites() { return sprites_; }
  const SpriteCache& Sprites() const { return sprites_; }

 private:
  entt::registry reg_;
  ObjectsRegistry objects_;
  SpriteCache sprites_;
  Bounds bounds_{0, 0, 0, 0};
  std::vector<RegionInfo> regions_;
  // Heads of the two named-link clusters, written on the first spawn
  // of each kind so subsequent spawns join the same group.
  entt::entity link_a_head_ = entt::null;
  entt::entity link_b_head_ = entt::null;
};

}  // namespace game
