# ChiptuneKit

Real-time square wave audio synthesis for retro game sounds.

## Overview

ChiptuneKit provides AVAudioEngine-based square wave synthesis for creating authentic chiptune-style sounds. Perfect for retro games, binary educational apps, or any project that needs that classic 8-bit audio feel.

## Requirements

- iOS 17.0+ / macOS 14.0+ / visionOS 1.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add ChiptuneKit to your project using Xcode:

1. File > Add Package Dependencies...
2. Enter the repository URL or local path
3. Select the version/branch you want to use

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../ChiptuneKit")
]
```

## Usage

### Basic Usage

```swift
import ChiptuneKit

// Create player and start the audio engine
let player = ChiptunePlayer()
player.start()

// Play a specific note
player.playNote(named: "C4", duration: 0.15)

// Play by frequency
player.playNote(frequency: 440.0, duration: 0.2)

// Stop when done
player.stop()
```

### Bit Position Mapping (for binary games)

Map bit positions to musical notes using a pentatonic scale:

```swift
// Higher bit positions = higher notes
player.playNoteForBit(position: 0, activeBitCount: 8)   // Low note
player.playNoteForBit(position: 7, activeBitCount: 8)   // High note
```

### Victory Melody

Play the built-in Ode to Joy melody for victory sequences:

```swift
// Play melody notes in sequence
for i in 0..<16 {
    player.playVictoryNote(noteIndex: i, duration: 0.18)
    try? await Task.sleep(nanoseconds: 200_000_000)
}
```

### Volume Control

```swift
player.volume = 0.5  // 0.0 to 1.0
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

The following notes are available in the `noteFrequencies` dictionary:

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

## API Reference

### ChiptunePlayer

| Property/Method | Description |
|-----------------|-------------|
| `volume: Float` | Volume level (0.0-1.0, default: 0.3) |
| `start()` | Start the audio engine |
| `stop()` | Stop the audio engine |
| `playNote(frequency:duration:)` | Play note at specific frequency |
| `playNote(named:duration:)` | Play note by name (e.g., "C4") |
| `playNoteForBit(position:activeBitCount:duration:)` | Play note mapped to bit position |
| `playVictoryNote(noteIndex:duration:)` | Play victory melody note |
| `getVictoryNoteFrequency(noteIndex:)` | Get frequency for victory note |

### Static Properties

| Property | Description |
|----------|-------------|
| `noteFrequencies` | Dictionary mapping note names to frequencies |
| `odeToJoyNotes` | Array of note names for victory melody |

## Audio Session

On iOS, ChiptuneKit configures the audio session for `.playback` category with `.mixWithOthers` option, allowing sounds to play alongside other audio.

## Performance Notes

- The audio engine runs on a high-priority audio thread
- Call `start()` once when your view appears, not on every sound
- Call `stop()` when audio is no longer needed to free resources

## License

MIT License - see LICENSE file for details.
