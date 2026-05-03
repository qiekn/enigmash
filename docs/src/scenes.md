# Scenes

Scenes are the unit the game switches between — logo splash, menu, gameplay,
pause overlay, etc. `engine::SceneManager` (`src/engine/scene_manager.{h,cpp}`)
holds a stack and routes the per-frame hooks; scenes call back via
`Manager()->Switch<T>()` / `Push<T>()` / `Pop()` to navigate.

Transitions are queued and applied at the top of `Update()`, so a scene
can safely call `Manager()->Switch<...>()` from inside its own `OnUpdate`
without invalidating `this`.

## Operations

| op       | effect                                          | use case          |
|----------|-------------------------------------------------|-------------------|
| `Switch` | empty the stack, push one new scene             | menu navigation   |
| `Push`   | overlay a new scene on top                      | pause / dialog    |
| `Pop`    | drop the topmost scene                          | resume / dismiss  |

`Render()` walks the stack from the lowest *opaque* scene up, so an overlay
(`IsOverlay() == true`) keeps the scene below visible.

## Scenes shipped

| scene                | role                                | exits via                                       |
|----------------------|-------------------------------------|-------------------------------------------------|
| `MainMenuScene`      | root menu (Play / Settings / …)     | enter on item, ESC = quit                       |
| `GameplayScene`      | actual puzzle (placeholder grid)    | ESC / P → push `PauseMenuScene`                 |
| `PauseMenuScene`     | overlay over gameplay               | ESC / P or Resume = pop, Quit = switch to menu  |
| `SettingsScene`      | placeholder                         | ESC → menu (or pop if pushed from pause)        |
| `GalleryScene`       | placeholder                         | ESC → menu                                      |
| `AchievementsScene`  | placeholder                         | ESC → menu                                      |
| `CreditsScene`       | static credits list                 | ESC → menu                                      |
| `EndScene`           | game-over / win                     | ESC / Enter → menu                              |

`PauseMenuScene` is the only `IsOverlay() == true` scene right now — the
gameplay underneath stays rendered so the dim panel reads as a true pause.

The shared placeholder chrome (centered title + bottom hint) lives in
`scenes::ui::DrawPlaceholderFrame` (`src/scenes/placeholder.{h,cpp}`); the
five "🔲 placeholder" scenes call into it. Delete `placeholder.{h,cpp}` once
every placeholder has been replaced with real content.

## Boot flow

There's no `LogoScene` — the `.exe` launch path paints the logo directly:

1. `InitWindow` → GL context ready
2. `Game::ShowSplashFrame` paints `assets/textures/jl.png` to the
   backbuffer. The OS shows it immediately.
3. Heavy init runs (`engine::LoadFonts(AsciiPlusCJK)`, ImGui context,
   layer attach) — the user keeps seeing the splash.
4. Main loop starts, `GameLayer::OnAttach` does
   `scenes_.Switch<MainMenuScene>()`.

This sidesteps the 1-2 s "frozen window" feel that the CJK font atlas
bake would otherwise produce.

## Quitting

A scene asks to terminate via `Manager()->RequestQuit()`, which sets a
flag. `Game::Run` polls it after each `Tick`:

```cpp
while (!WindowShouldClose() && !game_layer_->QuitRequested()) {
  Tick();
}
Shutdown();
```

The flag is honoured at a frame boundary, so `Shutdown()` always runs on
the clean teardown path (font atlas freed, `window.state` saved, GL
context closed in order). Scenes never call `exit()` or `CloseWindow()`
themselves.
