# Scenes

A *scene* is the unit the game switches between — main menu, gameplay,
pause overlay, etc. `engine::SceneManager` (`src/engine/scene_manager.{h,cpp}`)
holds a stack of them and routes the per-frame hooks; scenes call back
via `Manager()->Switch<T>() / Push<T>() / Pop()` to navigate.

## Design

### Scene

Every scene derives from `engine::Scene` and overrides whichever hooks
it needs:

```cpp
class Scene {
 public:
  virtual void OnEnter() {}                  // construct GL resources
  virtual void OnExit() {}                   // free GL resources
  virtual void OnUpdate(float dt) {}         // input + state
  virtual void OnRender(int w, int h) {}     // draws into the bound RT
  virtual void OnImGuiRender() {}            // optional ImGui widgets
  virtual bool IsOverlay() const { return false; }
  SceneManager* Manager() const { return manager_; }
};
```

`OnEnter` / `OnExit` fire on the manager's own timeline (deferred — see
below), so a scene can allocate GL resources in `OnEnter` and free them
in `OnExit` without worrying about mid-frame state.

### SceneManager

The manager holds a stack and a *pending* transition. Transitions are
queued: they don't take effect until the next `Update()` boundary, so a
scene can safely call `Manager()->Switch<Next>()` from inside its own
`OnUpdate` without invalidating `this`.

```cpp
class SceneManager {
  template <class T, class... Args> void Switch(Args&&...);  // clear + push
  template <class T, class... Args> void Push  (Args&&...);  // overlay on top
  void Pop();                                                // drop topmost
  void RequestQuit();                                        // sets a flag

  void Update(float dt);
  void Render(int w, int h);
  void ImGuiRender();
};
```

| op       | effect                              | use case        |
|----------|-------------------------------------|-----------------|
| `Switch` | empty the stack, push one new scene | menu navigation |
| `Push`   | overlay a new scene on top          | pause / dialog  |
| `Pop`    | drop the topmost scene              | resume / dismiss |

### Update: deferred dispatch

```cpp
void SceneManager::Update(float dt) {
  ApplyPending();                              // resolves Switch/Push/Pop
  if (!stack_.empty()) stack_.back()->OnUpdate(dt);
}
```

Only the **topmost** scene receives `OnUpdate` — a paused gameplay
scene below the pause menu correctly stops ticking.

### Render: walk from the lowest opaque scene up

```cpp
void SceneManager::Render(int w, int h) {
  // Find the lowest opaque scene; everything below it is hidden anyway.
  std::size_t start = 0;
  for (std::size_t i = stack_.size(); i > 0; --i) {
    if (!stack_[i - 1]->IsOverlay()) { start = i - 1; break; }
  }
  for (std::size_t i = start; i < stack_.size(); ++i) {
    stack_[i]->OnRender(w, h);
  }
}
```

A scene that returns `IsOverlay() == false` (the default) is treated as
fully covering the framebuffer — anything below it is skipped to avoid
overdraw. The pause menu is the only overlay shipped; its `OnRender`
just draws a translucent dim on top of the gameplay pixels left in the
framebuffer from the same frame.

## Scenes shipped

Grouped by role:

**Navigation**
- `MainMenuScene` — root menu (Play / Settings / Gallery / Achievements
  / Credits / Quit). Only the `Quit` item terminates; ESC is
  intentionally inert here.

**Gameplay**
- `GameplayScene` — placeholder grid. ESC / P pushes the pause overlay.
- `PauseMenuScene` — the only `IsOverlay() == true` scene. ESC / P or
  *Resume* pops; *Quit to Menu* switches back to `MainMenuScene`.

**Outcome**
- `EndScene` — game-over / win screen, ESC / Enter returns to menu.

**Placeholders** (see next section)
- `SettingsScene`, `GalleryScene`, `AchievementsScene`, `CreditsScene`

## Placeholder design

Five of the scenes above are visually identical right now — centered
title, "press esc to return" hint at the bottom. Inlining that pattern
in each `OnRender` would mean five copies of the same `DrawText`
sequence, drifting apart over time and turning a one-line tweak into a
five-file edit.

`scenes::ui::DrawPlaceholderFrame` (`src/scenes/placeholder.{h,cpp}`)
extracts the shared draw. Each placeholder scene's `OnRender` shrinks
to three lines:

```cpp
void GalleryScene::OnRender(int w, int h) {
  ClearBackground(theme::kBackground);
  scenes::ui::DrawPlaceholderFrame(w, h, "Gallery");
}
```

Two deliberate choices about where it lives:

- **Under `scenes/`, not `engine/`.** It isn't a real engine primitive —
  it's scaffolding for the not-yet-implemented scenes. Putting it in
  `engine/` would imply long-term API.
- **A free function, not a base class.** Inheritance would lock the
  placeholder scenes into a specific `OnRender` shape. A free function
  composes — when one of the placeholders gets real content, it stops
  calling `DrawPlaceholderFrame` and writes its own `OnRender`. No
  inheritance to refactor away.

When the last placeholder gets filled in, delete
`scenes/placeholder.{h,cpp}`. The file is intentionally disposable.

## Boot flow

There's no `LogoScene` — the `.exe` launch path paints the logo
directly to the backbuffer:

1. `InitWindow` → GL context ready
2. `Game::ShowSplashFrame` paints `assets/textures/jl.png` once. The
   OS shows it immediately after `EndDrawing`'s SwapBuffers.
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

The flag is honoured at a frame boundary, so `Shutdown()` always runs
on the clean teardown path (font atlas freed, `window.state` saved, GL
context closed in order). Scenes never call `exit()` or `CloseWindow()`
themselves — see [the *request* pattern](#design) commentary.
