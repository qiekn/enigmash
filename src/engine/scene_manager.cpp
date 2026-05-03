#include "engine/scene_manager.h"

namespace engine {

void SceneManager::Pop() { pending_op_ = Op::Pop; }

void SceneManager::RequestQuit() { quit_requested_ = true; }

void SceneManager::ApplyPending() {
  switch (pending_op_) {
    case Op::None:
      return;

    case Op::Switch: {
      // Tear the whole stack down, then activate the new scene. OnExit
      // runs top-down so a paused-under scene sees its overlay vanish
      // before its own teardown.
      while (!stack_.empty()) {
        stack_.back()->OnExit();
        stack_.pop_back();
      }
      pending_->SetManager(this);
      stack_.push_back(std::move(pending_));
      stack_.back()->OnEnter();
      break;
    }

    case Op::Push: {
      pending_->SetManager(this);
      stack_.push_back(std::move(pending_));
      stack_.back()->OnEnter();
      break;
    }

    case Op::Pop: {
      if (!stack_.empty()) {
        stack_.back()->OnExit();
        stack_.pop_back();
      }
      break;
    }
  }
  pending_op_ = Op::None;
  pending_.reset();
}

void SceneManager::Update(float dt) {
  ApplyPending();
  if (!stack_.empty()) stack_.back()->OnUpdate(dt);
}

void SceneManager::Render(int target_w, int target_h) {
  // Find the lowest *opaque* scene so we don't waste time clearing +
  // redrawing layers an overlay would cover anyway. Walking up from
  // there matches the visual stack: lower → upper.
  std::size_t start = 0;
  for (std::size_t i = stack_.size(); i > 0; --i) {
    if (!stack_[i - 1]->IsOverlay()) {
      start = i - 1;
      break;
    }
  }
  for (std::size_t i = start; i < stack_.size(); ++i) {
    stack_[i]->OnRender(target_w, target_h);
  }
}

void SceneManager::ImGuiRender() {
  // Only the active scene contributes ImGui (most scenes won't have any).
  if (!stack_.empty()) stack_.back()->OnImGuiRender();
}

}  // namespace engine
