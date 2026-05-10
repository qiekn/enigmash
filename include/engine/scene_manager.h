#pragma once

#include <memory>
#include <utility>
#include <vector>

#include "engine/scene.h"

namespace engine {

// -----------------------------------------------------------------------------: scene manager
//
// Holds a stack of scenes and routes the per-frame hooks. Transitions are
// queued (Switch / Push / Pop) and applied at the top of Update() — never
// mid-frame — so a scene can safely call `Manager()->Switch<...>()` from
// inside its own OnUpdate without invalidating `this`.
//
// Switch:  empties the stack, pushes a single new scene. The default flow.
// Push:    overlays a new scene on top. Useful for pause menus / dialogs.
// Pop:     removes the topmost scene. No-op on an empty stack.
class SceneManager {
 public:
  template <class T, class... Args>
  void Switch(Args&&... args) {
    pending_ = std::make_unique<T>(std::forward<Args>(args)...);
    pending_op_ = Op::Switch;
  }

  template <class T, class... Args>
  void Push(Args&&... args) {
    pending_ = std::make_unique<T>(std::forward<Args>(args)...);
    pending_op_ = Op::Push;
  }

  void Pop();

  // Asks the host to terminate cleanly. Game::Run polls QuitRequested()
  // and breaks out of the main loop on the next iteration.
  void RequestQuit();
  bool QuitRequested() const { return quit_requested_; }

  // Per-frame hooks. Update applies pending transitions first, then ticks
  // the topmost scene only. Render walks the stack from the lowest opaque
  // scene up to the top so overlays are drawn last.
  void Update(float dt);
  void Render(int target_w, int target_h);
  void ImGuiRender();

  Scene* Active() const { return stack_.empty() ? nullptr : stack_.back().get(); }
  std::size_t Depth() const { return stack_.size(); }

 private:
  enum class Op { None, Switch, Push, Pop };
  void ApplyPending();

  std::vector<std::unique_ptr<Scene>> stack_;
  std::unique_ptr<Scene> pending_;
  Op pending_op_ = Op::None;
  bool quit_requested_ = false;
};

}  // namespace engine
