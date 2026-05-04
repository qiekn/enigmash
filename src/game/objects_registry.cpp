#include "game/objects_registry.h"

#include <raylib.h>

#include <cstdio>
#include <fstream>
#include <nlohmann/json.hpp>
#include <string>

namespace game {

namespace {

// Parses "#rrggbb" / "#rrggbbaa" / [r,g,b,a] arrays. Anything else is
// rejected loudly so a typo doesn't silently render hot-pink.
bool ParseColor(const nlohmann::json& j, Color& out) {
  if (j.is_string()) {
    std::string s = j.get<std::string>();
    if (s.empty() || s[0] != '#') return false;
    s.erase(0, 1);
    if (s.size() != 6 && s.size() != 8) return false;
    auto hex2 = [](const std::string& h, std::size_t i) -> int {
      auto v = std::stoul(h.substr(i, 2), nullptr, 16);
      return static_cast<int>(v);
    };
    out.r = (unsigned char)hex2(s, 0);
    out.g = (unsigned char)hex2(s, 2);
    out.b = (unsigned char)hex2(s, 4);
    out.a = s.size() == 8 ? (unsigned char)hex2(s, 6) : 255;
    return true;
  }
  if (j.is_array() && (j.size() == 3 || j.size() == 4)) {
    out.r = (unsigned char)j[0].get<int>();
    out.g = (unsigned char)j[1].get<int>();
    out.b = (unsigned char)j[2].get<int>();
    out.a = j.size() == 4 ? (unsigned char)j[3].get<int>() : 255;
    return true;
  }
  return false;
}

Tag TagFromString(const std::string& s) {
  if (s == "stop") return Tag::Stop;
  if (s == "pushable") return Tag::Pushable;
  if (s == "toggle") return Tag::Toggle;
  if (s == "checkpoint") return Tag::Checkpoint;
  if (s == "player") return Tag::Player;
  if (s == "link_a") return Tag::LinkA;
  if (s == "link_b") return Tag::LinkB;
  if (s == "goal") return Tag::Goal;
  if (s == "toggleable") return Tag::Toggleable;
  if (s == "convey_n") return Tag::ConveyN;
  if (s == "convey_s") return Tag::ConveyS;
  if (s == "convey_e") return Tag::ConveyE;
  if (s == "convey_w") return Tag::ConveyW;
  return Tag::None;
}

}  // namespace

bool ObjectsRegistry::LoadFromFile(const std::string& path) {
  std::ifstream in(path);
  if (!in) {
    TraceLog(LOG_ERROR, "ObjectsRegistry: failed to open %s", path.c_str());
    return false;
  }

  nlohmann::json root;
  try {
    in >> root;
  } catch (const std::exception& e) {
    TraceLog(LOG_ERROR, "ObjectsRegistry: parse error in %s: %s", path.c_str(), e.what());
    return false;
  }
  if (!root.is_object()) {
    TraceLog(LOG_ERROR, "ObjectsRegistry: root must be an object");
    return false;
  }

  defs_.clear();
  by_name_.clear();
  defs_.reserve(root.size());

  for (auto& [name, body] : root.items()) {
    if (name.starts_with("_")) continue;  // _comment etc.
    if (!body.is_object()) continue;

    ObjectDef def;
    def.name = name;
    if (auto it = body.find("layer"); it != body.end() && it->is_number_integer()) {
      def.layer = static_cast<int8_t>(it->get<int>());
    }
    if (auto it = body.find("color"); it != body.end()) {
      ParseColor(*it, def.color);
    }
    if (auto it = body.find("sprite"); it != body.end() && it->is_string()) {
      def.sprite_path = it->get<std::string>();
    }
    if (auto it = body.find("radius"); it != body.end() && it->is_number_integer()) {
      def.toggle_radius = static_cast<uint8_t>(it->get<int>());
    }
    if (auto it = body.find("tags"); it != body.end() && it->is_array()) {
      for (auto& t : *it) {
        if (t.is_string()) def.tags |= TagFromString(t.get<std::string>());
      }
    }

    by_name_[def.name] = defs_.size();
    defs_.push_back(std::move(def));
  }

  TraceLog(LOG_INFO, "ObjectsRegistry: loaded %zu defs from %s", defs_.size(), path.c_str());
  return true;
}

const ObjectDef* ObjectsRegistry::Find(const std::string& name) const {
  auto it = by_name_.find(name);
  return it == by_name_.end() ? nullptr : &defs_[it->second];
}

ObjectDef* ObjectsRegistry::Find(const std::string& name) {
  auto it = by_name_.find(name);
  return it == by_name_.end() ? nullptr : &defs_[it->second];
}

}  // namespace game
