#pragma once

#include <raylib.h>

#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>

namespace game {

// Behavior bitset bound to an object kind. Mirrors the `tags` array in
// objects.json — kept small and explicit so we can branch cheaply during
// loading instead of doing string compares everywhere.
enum class Tag : uint16_t {
  None      = 0,
  Stop      = 1u << 0,
  Pushable  = 1u << 1,
  Toggle    = 1u << 2,
  Checkpoint= 1u << 3,
  Player    = 1u << 4,
};

constexpr Tag operator|(Tag a, Tag b) {
  return static_cast<Tag>(static_cast<uint16_t>(a) | static_cast<uint16_t>(b));
}
constexpr Tag& operator|=(Tag& a, Tag b) { a = a | b; return a; }
constexpr bool HasTag(Tag flags, Tag t) {
  return (static_cast<uint16_t>(flags) & static_cast<uint16_t>(t)) != 0;
}

// One entry per named object in objects.json. `sprite_id` is the
// SpriteCache slot — assigned at load time, indexed via Sprite::atlas_id.
struct ObjectDef {
  std::string name;
  int8_t layer = 0;
  Color color{255, 0, 255, 255};   // hot-pink fallback so omissions are loud
  std::string sprite_path;          // empty → procedural placeholder
  uint32_t sprite_id = 0;
  Tag tags = Tag::None;
  uint8_t toggle_radius = 0;
};

// Reads assets/data/objects.json. Returns false on parse failure (with
// TraceLog). On success, defs are owned by the registry and looked up by
// name. Names are case-sensitive on purpose: world JSON uses the same
// strings as keys.
class ObjectsRegistry {
 public:
  bool LoadFromFile(const std::string& path);

  const ObjectDef* Find(const std::string& name) const;
  ObjectDef* Find(const std::string& name);

  const std::vector<ObjectDef>& All() const { return defs_; }
  std::vector<ObjectDef>& All() { return defs_; }

 private:
  std::vector<ObjectDef> defs_;
  std::unordered_map<std::string, std::size_t> by_name_;
};

}  // namespace game
