#include "game/systems/render_tiles.h"

#include <raylib.h>

#include <algorithm>
#include <vector>

#include "game/components.h"
#include "game/world.h"

namespace game::systems {

void DrawTiles(const World& w) {
  // Sort by layer ascending so higher ZOrder paints on top. Stable-sort
  // so entities sharing a layer render in creation order — boundary
  // decals spawned by PatchWallSprite rely on this to land on top of
  // the wall they decorate (both at the wall's native layer).
  const auto& reg = w.Registry();
  auto view = reg.view<const VisualXY, const Sprite, const ZOrder>();

  std::vector<entt::entity> ents;
  ents.reserve(view.size_hint());
  for (auto e : view) {
    if (reg.all_of<Hidden>(e)) continue;
    ents.push_back(e);
  }
  std::stable_sort(ents.begin(), ents.end(), [&](entt::entity a, entt::entity b) {
    return view.get<const ZOrder>(a).layer < view.get<const ZOrder>(b).layer;
  });

  const auto& cache = w.Sprites();
  for (auto e : ents) {
    const auto& v = view.get<const VisualXY>(e);
    const auto& s = view.get<const Sprite>(e);
    const Texture2D& tex = cache.Get(s.atlas_id);
    if (tex.id == 0) continue;
    const Rectangle src{0, 0, (float)tex.width, (float)tex.height};
    const Rectangle dst{v.x, v.y, (float)kTilePx, (float)kTilePx};
    DrawTexturePro(tex, src, dst, Vector2{0, 0}, 0.0f, WHITE);
  }
}

}  // namespace game::systems
