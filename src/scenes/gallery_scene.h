#pragma once

#include "engine/scene.h"

namespace scenes {

class GalleryScene : public engine::Scene {
 public:
  GalleryScene() : Scene("Gallery") {}
  void OnUpdate(float dt) override;
  void OnRender(int target_w, int target_h) override;
};

}  // namespace scenes
