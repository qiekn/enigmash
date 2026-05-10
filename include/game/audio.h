#pragma once

namespace game::audio {

// Eight slots mirroring the original PuzzleScript's SFX0..SFX7 hooks.
// Names describe the gameplay event, not the original PS encoding.
enum class Sfx {
  R1Push = 0,    // SFX0 — sokoban box step
  R2Climb = 1,   // SFX1 — r2 climb
  R2Fall = 2,    // SFX2 — r2 gravity fall
  R3Push = 3,    // SFX3 — chain segment moves
  R3Sink = 4,    // SFX4 — chain sinks (placeholder, no port mechanic yet)
  R4Push = 5,    // SFX5 — billiards push
  R5Move = 6,    // SFX6 — slide / conveyor
  ToggleSwap = 7,  // SFX7 — toggle activates
  Count
};

// Synthesises 8 placeholder blips into raylib Sound slots; safe to call
// after InitAudioDevice. Idempotent — second call is a no-op so unit
// tests / hot reload don't leak. Pair with Shutdown() before
// CloseAudioDevice.
void Init();
void Shutdown();

// Plays one of the 8 slots. No-op if Init() hasn't run or the slot id
// is out of range. Calls into raylib's PlaySound (cuts off in-flight
// instance of the same slot — fine for our short blips).
void Play(Sfx id);

}  // namespace game::audio
