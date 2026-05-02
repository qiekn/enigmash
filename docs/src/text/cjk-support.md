# Adding Simplified Chinese

The base `engine::text` setup ships **Noto Sans** (Latin-only). Adding
Chinese is more involved than it looks — you need to (a) get a font
that actually contains Han glyphs, (b) be careful about which TTF you
pick, and (c) keep the atlas from melting your VRAM.

This chapter records what worked and the dead-ends I hit on the way.

## TL;DR

```cpp
// game.cpp
engine::LoadFonts(engine::CodepointSet::AsciiPlusCJK);
```

Then ship `assets/fonts/noto/NotoSansSC-Regular.ttf` next to the
existing `NotoSans-Regular.ttf`. Both `engine::text` and `ImGuiLayer`
read `engine::GetCodepointSet()` and pick the SC face automatically.

## Why Noto Sans alone is not enough

`NotoSans-Regular.ttf` (the Latin Noto) doesn't contain CJK Unified
Ideographs. If you `DrawText("你好")` with it you get tofu (`◻◻`).

The CJK glyphs live in a separate font family:

| family             | covers                       |
|--------------------|------------------------------|
| `NotoSansSC`       | Simplified Chinese + Latin   |
| `NotoSansTC`       | Traditional Chinese + Latin  |
| `NotoSansJP`       | Japanese (kana + kanji)      |
| `NotoSansKR`       | Korean (hangul + hanja)      |
| `NotoSansCJK`      | Unified pan-CJK              |

We ship **NotoSansSC** because the game is shipping in zh-CN. Switching
to JP/KR is a one-line change in `engine::text.cpp`'s `kCjkPath`.

## Trap #1: don't use the Variable TTF

The canonical noto-cjk repo distributes its TTFs as **variable fonts**
(`NotoSansSC-VF.ttf`). VFs pack every weight from Thin through Black
into one file, with the actual rendered weight selected via the `fvar`
axis at draw time.

stb_truetype — used by both raylib and ImGui — **does not parse the
fvar axis**. It just renders the file's *default instance*, which for
the upstream Noto CJK VFs is **`wght=100` (Thin)**. The result is text
that looks like it's about to evaporate.

Confirming the effect on a real machine:

```
Before fix: thin, hairline strokes
After  fix: normal Regular weight
```

There are two ways out:

1. **Use a static TTF at the weight you want.** Both Google Fonts and
   the noto-cjk repo unfortunately only distribute *VF* TTFs publicly.
   The static OTFs they ship are CFF-based, which raylib's stb_truetype
   doesn't reliably handle either.
2. **Instance the VF down to a static TTF yourself.** This is the
   approach we use.

## Trap #2: don't use the OTF static distribution

The static-weight files at `noto-cjk/Sans/OTF/SimplifiedChinese/` *are*
in the right weight (Regular = wght 400) — but they're CFF-based OTF
(`.otf` with the `CFF` table, PostScript Type 2 outlines). Newer
stb_truetype builds added partial CFF support, but coverage is uneven
and at the time of writing the version raylib ships with renders these
files badly.

Conclusion: **use TrueType outlines (`glyf` table) only**. That means
either a TTF that's already static, or a VF that we statically instance
ourselves.

## Static-instance the VF with `fonttools`

`fonttools.varLib.instancer` takes a VF and pins one or more axes to a
constant, producing a static TTF as output. It also drops `fvar` /
`gvar` / `STAT` / `HVAR` so downstream consumers don't get confused.

```bash
# 1. Get the upstream variable font (~17 MB for the SC subset).
curl -L -o /tmp/NotoSansSC-VF.ttf \
  https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/Variable/TTF/Subset/NotoSansSC-VF.ttf

# 2. Pin the wght axis to 400 (Regular) and write out a static TTF.
python -m pip install --user fonttools
python -m fontTools.varLib.instancer \
  /tmp/NotoSansSC-VF.ttf wght=400 \
  -o assets/fonts/noto/NotoSansSC-Regular.ttf
```

The resulting file is ~10.6 MB, contains only `glyf` outlines at
`wght=400`, and renders identically through stb_truetype, FreeType, and
the OS shaper. This is what we commit into the repo.

If you ever need a Bold variant, run the instancer again with
`wght=700` and update the `kCjkPath` switch — that's it.

## Codepoint coverage

`engine::text.cpp::BuildCodepoints` decides which characters are baked
into the atlas:

```cpp
void BuildCodepoints(CodepointSet cps) {
  g_codepoints.clear();
  for (int c = 0x20; c <= 0x7E; ++c) g_codepoints.push_back(c);  // ASCII

  if (cps == CodepointSet::AsciiPlusCJK) {
    for (int c = 0x3000; c <= 0x303F; ++c) g_codepoints.push_back(c);  // CJK punct
    for (int c = 0x4E00; c <= 0x9FFF; ++c) g_codepoints.push_back(c);  // Han
    for (int c = 0xFF00; c <= 0xFFEF; ++c) g_codepoints.push_back(c);  // Half/Full
  }
}
```

The Han range alone is ~21 000 codepoints. That's not free.

## VRAM budget: super-sampling and preload list

For ASCII we bake the atlas at **2× the render size** to dodge
stb_truetype's small-size rounding artifacts (see the previous
chapter). With CJK that doubles the atlas footprint:

| set       | glyphs | super-sample | atlas (rough) |
|-----------|-------:|-------------:|--------------:|
| ASCII     |     95 |           2× | ~1 MB         |
| ASCII+CJK | 21 200 |           2× | ~30 MB        |
| ASCII+CJK | 21 200 |           1× | ~7 MB         |

Multiply by the number of preloaded sizes and the cost adds up fast.

So `engine::text` makes two adjustments when CJK is on:

1. **Drop super-sampling to 1×.** CJK strokes are thicker than Latin
   ones — the half-pixel rounding artefacts that 2× was hiding aren't
   visible on Han to begin with.
2. **Preload only one size (18pt).** Lazy-load any other size on
   first use. ASCII still preloads `{16, 18, 20, 24, 32}` because the
   per-atlas cost is negligible.

```cpp
constexpr int kPreloadAsciiSizes[] = {16, 18, 20, 24, 32};
constexpr int kPreloadCjkSizes[]   = {18};

constexpr int kSuperSampleAscii = 2;
constexpr int kSuperSampleCjk   = 1;
```

## Wiring it up: raylib side

```cpp
const char* PathFor(CodepointSet cps) {
  return cps == CodepointSet::AsciiPlusCJK ? kCjkPath : kRegularPath;
}

void LoadFonts(CodepointSet cps, float ui_scale) {
  if (!g_cache.empty()) return;  // idempotent
  g_cps = cps;
  g_ui_scale = (ui_scale > 0.0f) ? ui_scale : DetectUiScale();
  BuildCodepoints(cps);
  const char* path = PathFor(cps);
  if (cps == CodepointSet::AsciiPlusCJK) {
    for (int s : kPreloadCjkSizes)   g_cache[s] = LoadOne(path, s);
  } else {
    for (int s : kPreloadAsciiSizes) g_cache[s] = LoadOne(path, s);
  }
}
```

`g_cps` is exposed via `engine::GetCodepointSet()` so other layers can
mirror our choice without a separate config.

## Wiring it up: ImGui side

`ImGuiLayer::LoadFonts` reads the same global and picks both the font
file and the glyph range to load:

```cpp
void ImGuiLayer::LoadFonts(float dpi_scale) {
  ImGuiIO& io = ImGui::GetIO();
  const float font_size = kImGuiBaseFontSize * dpi_scale;
  const bool cjk = (engine::GetCodepointSet()
                    == engine::CodepointSet::AsciiPlusCJK);

  const std::filesystem::path path =
      cjk ? std::filesystem::path{"assets/fonts/noto/NotoSansSC-Regular.ttf"}
          : std::filesystem::path{"assets/fonts/noto/NotoSans-Regular.ttf"};

  const ImWchar* ranges =
      cjk ? io.Fonts->GetGlyphRangesChineseFull()
          : io.Fonts->GetGlyphRangesDefault();

  io.Fonts->Clear();
  if (std::filesystem::exists(path)) {
    io.FontDefault = io.Fonts->AddFontFromFileTTF(
        path.string().c_str(), font_size, nullptr, ranges);
  }
  if (io.FontDefault == nullptr) {
    io.FontDefault = io.Fonts->AddFontDefault();
  }
}
```

`GetGlyphRangesChineseFull()` covers Latin + Hiragana + Katakana +
Half/Fullwidth + CJK Unified Ideographs — same set as our raylib-side
codepoint list, give or take. The atlas ImGui builds is independent
from the raylib atlas, but both end up with the same glyph repertoire.

For tighter VRAM, swap in `GetGlyphRangesChineseSimplifiedCommon()` —
that ships ~2 500 of the most common simplified characters instead of
the full ~21 000.

## Testing

The placeholder scene writes a Chinese line so the regression is
visible at a glance:

```cpp
engine::DrawText("应无所住，而生其心。", Vector2{16, 48}, 24,
                 Color{220, 220, 240, 255});
```

If that line renders as tofu, your `assets/fonts/noto/NotoSansSC-Regular.ttf`
is missing or the wrong file. If it renders as Thin (visibly skinny
strokes), you grabbed the upstream VF directly without instancing it.
