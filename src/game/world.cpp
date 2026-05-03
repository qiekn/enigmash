#include "game/world.h"

#include <raylib.h>

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

  if (HasTag(def->tags, Tag::Player)) reg_.emplace<Player>(e);
  if (HasTag(def->tags, Tag::Pushable)) reg_.emplace<Pushable>(e);
  if (HasTag(def->tags, Tag::Stop)) reg_.emplace<Stop>(e);
  if (HasTag(def->tags, Tag::Checkpoint)) reg_.emplace<Checkpoint>(e);
  if (HasTag(def->tags, Tag::Toggle)) reg_.emplace<Toggle>(e, def->toggle_radius);
  return e;
}

}  // namespace game
