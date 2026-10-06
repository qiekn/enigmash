# ENIGMASH (Jai rewirte)

![jacklance](https://github.com/user-attachments/assets/c5cb81a2-069e-4f31-8db4-6c126de24043)

[orig]: https://www.puzzlescript.net/play.html?p=jacklance/enigmash

# Build

```jai
jai first.jai - release
```

## Source layout

- `src/core/`: rendering and audio APIs, textures, fonts, camera math, asset package.
- `src/game/`: puzzle simulation, sessions, input, menus and game-specific assets.
- `src/game/render/`: world drawing, HUD and visual effects, shared with the editor.
- `src/editor/`: level editing and editor UI.
- `src/main.jai`: application setup, event routing and frame loop.

Core APIs take explicit resources and camera instances. Game and editor code own
their state and use these APIs; backend calls stay inside core.

## Checks

```powershell
jai -quiet tests/camera.jai
jai -quiet tests/session_audio.jai
.\.build\camera_tests.exe
.\.build\session_audio_tests.exe
```
