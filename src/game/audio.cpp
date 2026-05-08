#include "game/audio.h"

#include <raylib.h>

#include <array>
#include <cmath>
#include <cstdint>

namespace game::audio {

namespace {

// Per-slot synth recipe. Frequency in Hz, duration in seconds, plus a
// glide ratio (final = start * glide) for the toggle-swap chirp. These
// are placeholder voices — the original PS sfxr seeds give a richer
// sound, but the rendering algorithm is heavyweight and a separate
// task. Keep them short so cut-offs don't bother anyone.
struct Voice {
  float freq;
  float duration;
  float glide;     // 1.0 = no glide; 0.25 = sweep down to a quarter
  float decay;     // exponential envelope rate (higher = snappier)
  bool square;     // square vs. sine, picked by feel per voice
};

constexpr std::array<Voice, 8> kVoices = {{
    {220.0f, 0.06f, 1.0f, 22.0f, true},   // 0 push
    {520.0f, 0.10f, 1.6f, 16.0f, false},  // 1 climb (rising)
    {110.0f, 0.18f, 0.5f, 9.0f,  true},   // 2 fall (downward thud)
    {260.0f, 0.07f, 1.0f, 20.0f, true},   // 3 chain
    { 90.0f, 0.22f, 0.7f, 7.0f,  true},   // 4 sink
    {340.0f, 0.07f, 1.0f, 20.0f, true},   // 5 billiards
    {480.0f, 0.05f, 1.0f, 28.0f, false},  // 6 slide
    {780.0f, 0.14f, 0.30f, 14.0f, false}, // 7 toggle (chirp down)
}};

constexpr int kSampleRate = 22050;
constexpr float kPi = 3.14159265358979323846f;

bool g_initialized = false;
std::array<Sound, static_cast<size_t>(Sfx::Count)> g_sounds{};

Sound SynthesizeBlip(const Voice& v) {
  const int frames = static_cast<int>(v.duration * kSampleRate);
  Wave wave{};
  wave.frameCount = static_cast<unsigned int>(frames);
  wave.sampleRate = kSampleRate;
  wave.sampleSize = 16;
  wave.channels = 1;
  // raylib UnloadWave will free this via MemFree, so keep the allocator
  // matched (raylib's MemAlloc maps to RL_MALLOC = malloc by default).
  wave.data = MemAlloc(frames * sizeof(int16_t));
  auto* samples = static_cast<int16_t*>(wave.data);
  for (int i = 0; i < frames; ++i) {
    const float t = static_cast<float>(i) / kSampleRate;
    const float u = t / v.duration;  // 0..1
    const float freq = v.freq * (1.0f + (v.glide - 1.0f) * u);
    const float env = std::exp(-t * v.decay);
    const float phase = 2.0f * kPi * freq * t;
    const float wave_val = v.square ? (std::sin(phase) >= 0.0f ? 1.0f : -1.0f)
                                    : std::sin(phase);
    samples[i] = static_cast<int16_t>(wave_val * env * 11000.0f);
  }
  Sound s = LoadSoundFromWave(wave);
  UnloadWave(wave);  // frees wave.data; Sound has its own GPU/audio buffer
  return s;
}

}  // namespace

void Init() {
  if (g_initialized) return;
  if (!IsAudioDeviceReady()) return;
  for (size_t i = 0; i < kVoices.size(); ++i) {
    g_sounds[i] = SynthesizeBlip(kVoices[i]);
  }
  g_initialized = true;
}

void Shutdown() {
  if (!g_initialized) return;
  for (auto& s : g_sounds) {
    UnloadSound(s);
    s = Sound{};
  }
  g_initialized = false;
}

void Play(Sfx id) {
  if (!g_initialized) return;
  const auto idx = static_cast<size_t>(id);
  if (idx >= g_sounds.size()) return;
  PlaySound(g_sounds[idx]);
}

}  // namespace game::audio
