# Font wrapper (`engine::text`)

raylib's stock text APIs (`DrawText`, `DrawTextEx`) are fine for one-off
demos but they leave a few problems on your plate when you ship a real
game:

1. **No font cache.** `DrawTextEx` takes a `Font` value; you have to own
   and pass it everywhere yourself.
2. **No HiDPI story.** The font you bake at 18px stays 18 *physical* px
   on a 200% display, while ImGui scales its UI by `dpi_scale`. Result:
   raylib HUD text looks half the size of ImGui chrome on a 4K laptop.
3. **stb_truetype rounding artifacts at small bake sizes.** Descenders of
   `j` / `g` get clipped by 1px, the digit `1` floats above its
   baseline, and so on.

`engine::text` (in `src/engine/text.{h,cpp}`) is the wrapper layer that
solves all three. The public surface looks like this:

```cpp
namespace engine {

enum class CodepointSet { AsciiOnly, AsciiPlusCJK };

void LoadFonts(CodepointSet cps = CodepointSet::AsciiOnly,
               float ui_scale = -1.0f);
void UnloadFonts();

const Font& GetFont(int logical_size);
float UiScale();
CodepointSet GetCodepointSet();

void DrawText(std::string_view text, Vector2 pos, int size, Color color);
Vector2 MeasureText(std::string_view text, int size);

}  // namespace engine
```

The rest of this chapter walks through *why* each piece exists.

## Lifecycle: where to call `LoadFonts` / `UnloadFonts`

`LoadFontEx` uploads atlas pixels to a GL texture, and `UnloadFont`
expects that texture to still exist. So:

- Call **`engine::LoadFonts(...)` after `InitWindow(...)`** — at that
  point raylib has a GL context.
- Call **`engine::UnloadFonts()` before `CloseWindow(...)`** — once the
  GL context is gone every cached `Font` is dangling.

In `Game::Init` we sandwich it between `InitAudioDevice()` and the
`push_layer` calls. In `Game::Shutdown` it goes after `layers_.clear()`
(which detaches `GameLayer` and `ImGuiLayer`, both of which may still
reference `Font` handles) and before `CloseWindow()`.

```cpp
void Game::Init() {
  // ... InitWindow, SetTargetFPS, InitAudioDevice ...
  engine::LoadFonts(engine::CodepointSet::AsciiPlusCJK);
  layers_.push_layer(std::move(imgui_layer));
  layers_.push_layer(std::move(game_layer));
}

void Game::Shutdown() {
  // ...
  layers_.clear();
  engine::UnloadFonts();
  CloseAudioDevice();
  CloseWindow();
}
```

`LoadFonts` is idempotent — calling it twice is a no-op so layers can
defensively call it during `OnAttach` if they need to.

## DPI-aware sizing

`engine::DrawText` takes a *logical* size in UI points. Internally we
scale it to physical pixels by the same DPI multiplier ImGui uses, so
`engine::DrawText(..., 18, ...)` and `ImGui::Text` at 18pt render at the
same visual height.

```cpp
float DetectUiScale() {
  Vector2 dpi = GetWindowScaleDPI();
  return std::max(1.0f, std::max(dpi.x, dpi.y));
}

int Physical(int logical_size) {
  return static_cast<int>(std::round(logical_size * g_ui_scale));
}
```

The scale is captured once at `LoadFonts` time. If the window moves
between monitors at different DPIs you can pass an explicit value:

```cpp
engine::LoadFonts(CodepointSet::AsciiOnly, /*ui_scale=*/2.0f);
```

`ImGuiLayer::GetDpiScale` uses the exact same formula — that's the trick
that keeps the two text systems aligned.

## Super-sampled atlas, bilinear downsample

stb_truetype's signed-distance metrics get rounded harshly when you bake
glyphs at small target sizes. The fix: bake the atlas at **N× the
rendered size**, sample with `TEXTURE_FILTER_BILINEAR`, and let the GPU
downsample at draw time.

```cpp
constexpr int kSuperSampleAscii = 2;
constexpr int kSuperSampleCjk   = 1;  // see CJK chapter for why

FontEntry LoadOne(const char* path, int logical_size) {
  FontEntry entry{};
  entry.physical_size = Physical(logical_size);
  const int bake_size = entry.physical_size * SuperSampleFor(g_cps);
  entry.font = LoadFontEx(path, bake_size, ...);
  SetTextureFilter(entry.font.texture, TEXTURE_FILTER_BILINEAR);
  return entry;
}
```

When the user calls `DrawText("hi", pos, 18, ...)` we look up the entry
for size 18, then pass `physical_size` (not `bake_size`) into
`DrawTextEx`. raylib divides UVs by the bake size, so the GPU samples
the high-res atlas and the result is crisp.

> `TEXTURE_FILTER_POINT` here would alias hard. The whole reason we bake
> 2× is so the bilinear tap blurs sub-pixel positioning errors away.

## Per-size cache

We can't cache one atlas and rescale — the cost of `TEXTURE_FILTER_BILINEAR`
between very different sizes is visible blur. So the cache is keyed by
*logical size*, with lazy load on miss:

```cpp
std::unordered_map<int, FontEntry> g_cache;

const FontEntry& GetOrLoad(int logical_size) {
  if (auto it = g_cache.find(logical_size); it != g_cache.end()) {
    return it->second;
  }
  FontEntry entry = LoadOne(PathFor(g_cps), logical_size);
  auto [it, _] = g_cache.emplace(logical_size, entry);
  return it->second;
}
```

`LoadFonts` warms the cache for a few common sizes so the first frame
doesn't pause to rasterise. For ASCII we preload `{16, 18, 20, 24, 32}`
— with `kAtlasSuperSample = 2` and `g_ui_scale = 2` that's 5 atlases
of about a couple hundred glyphs each. Fine.

```cpp
constexpr int kPreloadAsciiSizes[] = {16, 18, 20, 24, 32};
```

If a layer asks for size 22 we lazy-load on demand; subsequent calls
hit the cache.

## What `DrawText` actually does

```cpp
void DrawText(std::string_view text, Vector2 pos, int size, Color color) {
  std::string s(text);
  const FontEntry& e = GetOrLoad(size);
  DrawTextEx(e.font, s.c_str(), pos,
             static_cast<float>(e.physical_size),
             kDefaultSpacing * g_ui_scale,
             color);
}
```

Three things to notice:

1. We pass `physical_size`, not the caller's logical `size`. This is
   what makes the 1:1 sampling possible — `DrawTextEx` ends up issuing
   draws at exactly the resolution the atlas was baked at, divided by
   the super-sample factor.
2. Spacing scales with `g_ui_scale`. Without this, kerning looks
   visibly tighter on HiDPI than on a 100% display.
3. We do `std::string s(text)` because `string_view` isn't guaranteed to
   be NUL-terminated and `DrawTextEx` wants `const char*`.

## Mirroring the choice in ImGui

`ImGuiLayer::LoadFonts` reads `engine::GetCodepointSet()` and picks the
matching face, so a Chinese string renders identically whether it goes
through `engine::DrawText` or `ImGui::Text`. The next chapter covers
the CJK case in detail.
