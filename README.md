# ChiptuneKit

Real-time audio synthesis for retro game sounds with configurable waveforms, envelopes, and modulation.

**Live demo:** <https://jpavley.github.io/ChiptuneKit/>

A browser-based playground for designing chiptune `ToneSettings` interactively — pick a waveform, shape its envelope and modulation, sketch rhythm patterns, audition presets, and render the result to a downloadable WAV. Runs entirely on the Web Audio API; nothing to install.

## Overview

ChiptuneKit provides AVAudioEngine-based synthesis for creating authentic chiptune-style sounds. Supports sine, triangle, square, sawtooth, and pulse waveforms with per-note envelope shaping and amplitude modulation (LFO tremolo).

## Requirements

- iOS 17.0+ / macOS 14.0+ / visionOS 1.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add ChiptuneKit to your project using Xcode:

1. File > Add Package Dependencies...
2. Enter `https://github.com/jpavley/ChiptuneKit.git`
3. Select the version/branch you want to use

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jpavley/ChiptuneKit.git", from: "1.0.0")
]
```

## Usage

### Basic Usage

```swift
import ChiptuneKit

// Create player and start the audio engine
let player = ChiptunePlayer()
player.start()

// Play a specific note (uses default square wave)
player.playNote(named: "C4", duration: 0.15)

// Play by frequency
player.playNote(frequency: 440.0, duration: 0.2)

// Stop when done
player.stop()
```

### Custom Tone Settings

Configure waveform, envelope, and modulation per note:

```swift
// Create a warm sine with gentle attack and tremolo
let settings = ToneSettings(
    waveform: .sine,
    attack: 0.01,
    release: 0.05,
    volume: 0.5,
    duration: 0.15,
    modulation: .init(enabled: true, rate: 5.0, depth: 0.3)
)

// Play with custom settings (settings persist for subsequent calls)
player.playNote(frequency: 440.0, settings: settings)

// Or set settings globally
player.toneSettings = settings
player.playNote(named: "E4", duration: 0.1)
```

### Waveforms

Five waveform types are available:

- **sine** — Pure fundamental tone, warm and clean
- **triangle** — Mellow, odd harmonics only (softer than square)
- **square** — Classic chiptune buzz, rich in odd harmonics
- **sawtooth** — Bright, contains all harmonics
- **pulse** — Variable duty cycle for thin/nasal tones

```swift
// Pulse waveform with narrow duty cycle
let pulseTone = ToneSettings(waveform: .pulse, dutyCycle: 0.25)
player.playNote(frequency: 440.0, settings: pulseTone)
```

### Bit Position Mapping (for binary games)

Map bit positions to musical notes using a pentatonic scale:

```swift
// Higher bit positions = higher notes
player.playNoteForBit(position: 0, activeBitCount: 8)   // Low note (C4)
player.playNoteForBit(position: 7, activeBitCount: 8)   // High note (E5)

// Get frequency for a position
let freq = ChiptunePlayer.pentatonicFrequency(forPosition: 3)  // G4
```

### Victory Melody (Legacy)

Play the built-in Ode to Joy melody for victory sequences:

```swift
for i in 0..<16 {
    player.playVictoryNote(noteIndex: i, duration: 0.18)
    try? await Task.sleep(nanoseconds: 200_000_000)
}
```

### Volume Control

```swift
player.volume = 0.5  // 0.0 to 1.0 (convenience for toneSettings.volume)
```

### SwiftUI Integration

```swift
struct GameView: View {
    @StateObject private var audioPlayer = ChiptunePlayer()

    var body: some View {
        Button("Play Sound") {
            audioPlayer.playNote(named: "E4")
        }
        .onAppear { audioPlayer.start() }
        .onDisappear { audioPlayer.stop() }
    }
}
```

## Available Notes

| Note | Frequency (Hz) |
|------|----------------|
| C4 | 261.63 |
| D4 | 293.66 |
| E4 | 329.63 |
| F4 | 349.23 |
| G4 | 392.00 |
| A4 | 440.00 |
| B4 | 493.88 |
| C5 | 523.25 |
| D5 | 587.33 |
| E5 | 659.25 |
| F5 | 698.46 |
| G5 | 783.99 |

## Pentatonic Scale (Bit Position Mapping)

| Position | Note | Frequency (Hz) |
|----------|------|----------------|
| 0 | C4 | 261.63 |
| 1 | D4 | 293.66 |
| 2 | E4 | 329.63 |
| 3 | G4 | 392.00 |
| 4 | A4 | 440.00 |
| 5 | C5 | 523.25 |
| 6 | D5 | 587.33 |
| 7 | E5 | 659.25 |
| 8 | G5 | 783.99 |
| 9 | A5 | 880.00 |

Positions 10-15 wrap back to the beginning.

## API Reference

### ToneSettings

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `waveform` | `Waveform` | `.square` | Oscillator shape |
| `dutyCycle` | `Double` | `0.5` | Pulse width (pulse only) |
| `attack` | `Double` | `0` | Attack time (seconds) |
| `release` | `Double` | `0` | Release time (seconds) |
| `volume` | `Float` | `0.3` | Output volume (0-1) |
| `duration` | `Double` | `0.15` | Note duration (seconds) |
| `tempo` | `Double` | `200` | BPM (caller scheduling) |
| `filter` | `FilterSettings` | disabled | Low-pass filter (v2) |
| `modulation` | `ModulationSettings` | disabled | LFO tremolo |

### ChiptunePlayer

| Method | Description |
|--------|-------------|
| `start()` | Start the audio engine |
| `stop()` | Stop the audio engine |
| `playNote(frequency:duration:)` | Play at frequency with current settings |
| `playNote(frequency:settings:)` | Play with specific tone settings |
| `playNote(named:duration:)` | Play note by name (e.g., "C4") |
| `playNoteForBit(position:activeBitCount:duration:)` | Pentatonic note for bit position |
| `pentatonicFrequency(forPosition:)` | Get frequency for bit position (static) |
| `playVictoryNote(noteIndex:duration:)` | Play legacy Ode to Joy note |

## Audio Session

On iOS, ChiptuneKit configures the audio session for `.ambient` category with `.mixWithOthers` option, allowing sounds to play alongside other audio.

## Performance Notes

- The audio engine runs on a high-priority audio thread
- Waveform generation, envelope, and LFO are computed per-frame in the render callback (no allocations)
- Call `start()` once when your view appears, not on every sound
- Call `stop()` when audio is no longer needed to free resources

## Examples

The [`Examples/chiptune-playground/`](Examples/chiptune-playground/) directory holds reference material from ChiptuneKit's development:

- **`*-tone.txt`** — Sample `ToneSettings` configurations.
- **`index.html`** — A standalone HTML page for previewing tones in the browser.
- **`chiptune-symphony.wav`** — A ~4.5 MB rendered example of the configured tones.
- **`RHYTHM-INTEGRATION-GUIDE.md`** — Notes on wiring `RhythmSettings` into a host app, written from the perspective of BQ16 (ChiptuneKit's first consumer).

These files are not built or installed by SPM — they're reference material only.

## License

MIT License - see LICENSE file for details.
