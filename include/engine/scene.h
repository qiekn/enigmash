#pragma once

#include <string>
#include <utility>

namespace engine {

class SceneManager;

// -----------------------------------------------------------------------------: scene base
//
// Scenes are the unit the SceneManager stacks and swaps. The host owns the
// raylib window + RenderTexture; scenes only see the per-frame hooks.
//
// OnEnter / OnExit fire on the manager's own timeline (deferred to next
// frame boundary), so you can safely allocate GL resources in OnEnter and
// free them in OnExit without worrying about mid-frame state.
class Scene {
 public:
  virtual ~Scene() = default;

  virtual void OnEnter() {}
  virtual void OnExit() {}
  virtual void OnUpdate(float /*dt*/) {}
  virtual void OnRender(int /*target_w*/, int /*target_h*/) {}
  virtual void OnImGuiRender() {}

  // Overlays let SceneManager keep rendering the scene underneath (used by
  // the pause menu so the gameplay stays visible behind the dim panel).
  // Default false: most scenes fully cover the framebuffer.
  virtual bool IsOverlay() const { return false; }

  // Set when SceneManager takes ownership; scenes use it to request
  // transitions (Manager()->Switch<NextScene>()).
  void SetManager(SceneManager* m) { manager_ = m; }
  SceneManager* Manager() const { return manager_; }

  const std::string& Name() const { return name_; }

 protected:
  explicit Scene(std::string name) : name_(std::move(name)) {}
  std::string name_;
  SceneManager* manager_ = nullptr;
};

}  // namespace engine
