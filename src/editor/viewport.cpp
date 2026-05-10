#include "editor/viewport.h"

namespace editor {

ViewportInfo& Viewport() {
  static ViewportInfo s;
  return s;
}

}  // namespace editor
