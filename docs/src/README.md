# enigmash

This book is a working journal for the **enigmash** clone — a C++23 + raylib
remake of [JackLance's PuzzleScript original][orig]. It documents engineering
decisions that are tedious to rediscover by reading the diff later.

The runtime is structured as a layered application:

- **`Game`** owns the raylib window and a `LayerStack`
- **`ImGuiLayer`** brings in a docking workspace and routes ImGui frames
- **`GameLayer`** renders the actual scene into a `RenderTexture2D` that the
  ImGui *Viewport* panel displays

The chapters that follow drill into the parts that are easy to get wrong on
the first try. Right now that means **text rendering** — picking a font,
keeping raylib + ImGui visually consistent, and adding CJK without melting
VRAM.

[orig]: https://www.puzzlescript.net/play.html?p=jacklance/enigmash
