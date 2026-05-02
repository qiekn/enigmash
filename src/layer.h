#pragma once

#include <string>
#include <utility>

// Base class for all engine layers. Layers form a stack: update/render in
// insertion order, overlays sit on top. Override the OnXxx hooks to plug
// into the per-frame loop driven by Game.
class Layer {
 public:
  explicit Layer(std::string name = "Layer") : name_(std::move(name)) {}
  virtual ~Layer() = default;

  virtual void OnAttach() {}
  virtual void OnDetach() {}
  virtual void OnUpdate(float /*dt*/) {}
  virtual void OnRender() {}
  virtual void OnImGuiRender() {}

  const std::string& Name() const { return name_; }

 protected:
  std::string name_;
};
