# Rhythm Pattern Integration Guide for BQ16

## Overview

The ChiptuneKit `ToneSettings.RhythmSettings` struct is ready to use. This guide covers the changes needed in the BQ16 game to support rhythmic victory animations where bit cell bounces follow the short/long note pattern.

## Files to Modify

| File                                                     | Purpose                                       |
| -------------------------------------------------------- | --------------------------------------------- |
| `Card Flip Animation/Game Engine/LevelTonePresets.swift` | Configure rhythm per difficulty level         |
| `Card Flip Animation/ContentView.swift`                  | Victory animation note scheduling (~line 537) |
| `Card Flip Animation/Screens/GameCompletedScreen.swift`  | End-game victory loop (~line 295)             |

## Step 1: Configure Level Rhythm Presets

In `LevelTonePresets.swift`, add a `rhythm:` parameter to each level's `ToneSettings` init. Levels without rhythm keep the default (disabled).

Example for Nibble with `| Da Da Daa Da |`:

```swift
case .fourBitNibble:
    // Movement I: Gentle sine, slow and patient
    return ToneSettings(
        waveform: .sine,
        attack: 0,
        release: 0.025,
        volume: 0.35,
        duration: 0.150,
        tempo: 300,
        modulation: .init(enabled: true, rate: 2.6, depth: 0.46),
        rhythm: .init(enabled: true, pattern: [1, 1, 2, 1], multiplier: 2.0)
    )
```

### Suggested rhythm patterns by level

These are starting points. Adjust to taste.

| Level  | Bits | Pattern                    | Notation                              |
| ------ | ---- | -------------------------- | ------------------------------------- |
| Nibble | 4    | `[1, 1, 2, 1]`             | `\| Da Da Daa Da \|`                  |
| ASCII  | 7    | `[1, 1, 2, 1]`             | `\| Da Da Daa Da \|`                  |
| Byte   | 8    | `[1, 1, 2, 1, 2, 2, 1, 1]` | `\| Da Da Daa Da \| Daa Daa Da Da \|` |
| Nobble | 10   | `[2, 1, 1, 1]`             | `\| Daa Da Da Da \|`                  |
| Gibble | 12   | `[1, 2, 1, 1, 2, 1, 1, 2]` | `\| Da Daa Da Da \| Daa Da Da Daa \|` |
| Gobble | 14   | `[1, 1, 2, 1, 1, 2, 2, 1]` | `\| Da Da Daa Da \| Da Daa Daa Da \|` |
| Word   | 16   | `[2, 1, 1, 2, 1, 1, 2, 1]` | `\| Daa Da Da Daa \| Da Da Daa Da \|` |

Multiplier of `2.0` works well at all tempos. Higher tempos (Gobble at 530, Word at 600) may benefit from `1.5` for subtler swing.

## Step 2: Update Victory Animation in ContentView.swift

Find `playVictoryAnimation()` (~line 537). The current scheduling uses uniform spacing:

```swift
// CURRENT CODE
for (index, bitPosition) in trace.enumerated() {
    let delay = Double(index) * noteSpacing

    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
        guard victoryGenerationID == currentGeneration else { return }
        bouncingPositions = [bitPosition]
        let freq = ChiptunePlayer.pentatonicFrequency(forPosition: bitPosition)
        chiptunePlayer.playNote(frequency: freq, duration: settings.duration)
    }
}

let totalDuration = Double(trace.count) * noteSpacing + 0.5
DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [self] in
    guard victoryGenerationID == currentGeneration else { return }
    isPlayingVictory = false
    bouncingPositions = []
    container.handleEvent(.victoryComplete)
}
```

Replace the loop and settle timeout with cumulative timing that respects rhythm:

```swift
// NEW CODE
var cumulativeDelay = 0.0
for (index, bitPosition) in trace.enumerated() {
    let rm = settings.rhythm.multiplier(forNoteAt: index)
    let noteDuration = settings.duration * rm
    let currentDelay = cumulativeDelay

    DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) { [self] in
        guard victoryGenerationID == currentGeneration else { return }
        bouncingPositions = [bitPosition]
        let freq = ChiptunePlayer.pentatonicFrequency(forPosition: bitPosition)
        chiptunePlayer.playNote(frequency: freq, duration: noteDuration)
    }

    cumulativeDelay += noteSpacing * rm
}

DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeDelay + 0.5) { [self] in
    guard victoryGenerationID == currentGeneration else { return }
    isPlayingVictory = false
    bouncingPositions = []
    container.handleEvent(.victoryComplete)
}
```

> **Note:** The Reduce Motion path (~line 544) skips the animation entirely and needs no changes.

### Why this works for animation sync

The bounce is triggered inside the same `DispatchQueue.main.asyncAfter` block as the note. Since both fire at `cumulativeDelay`, audio and visual stay synchronized. Long notes get more time before the next bounce, creating visible rhythmic movement in the bit cells.

In GameCompletedScreen, the trailing glow (how long a bit stays lit after being toggled on) also scales with rhythm: `0.3 * rm`. This means long notes produce a longer visible glow, reinforcing the rhythmic feel visually.

## Step 3: Update Victory Loop in GameCompletedScreen.swift

Find `playVictoryAnimation()` (~line 295). Apply the same cumulative timing change to the loop, the trailing glow linger, and the loop restart:

```swift
// NEW CODE
var cumulativeDelay = 0.0
for (index, bitPosition) in trace.enumerated() {
    let rm = settings.rhythm.multiplier(forNoteAt: index)
    let noteDuration = settings.duration * rm
    let currentDelay = cumulativeDelay

    DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) { [self] in
        guard victoryGenerationID == currentGeneration else { return }

        bouncingPositions = [bitPosition]
        bitValues[bitPosition] = true

        let freq = ChiptunePlayer.pentatonicFrequency(forPosition: bitPosition)
        chiptunePlayer?.playNote(frequency: freq, duration: noteDuration)

        // Trailing glow scales with rhythm — long notes stay lit longer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 * rm) { [self] in
            guard victoryGenerationID == currentGeneration else { return }
            bitValues[bitPosition] = false
        }
    }

    cumulativeDelay += noteSpacing * rm
}

// Loop restart uses rhythm-aware total duration
DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeDelay + 0.5) { [self] in
    guard victoryGenerationID == currentGeneration else { return }
    isPlayingVictory = false
    bouncingPositions = []
    resetBitValues()
    playVictoryAnimation()
}
```

> **Note:** The Reduce Motion path (~line 302) skips the animation entirely and needs no changes.

## How It Works

1. `rhythm.multiplier(forNoteAt: index)` returns `1.0` for short notes and `rhythmMultiplier` (e.g. `2.0`) for long notes
2. The pattern cycles via modulo: a 4-beat pattern repeats every 4 notes regardless of trace length
3. Note **duration**, **spacing**, and **trailing glow** all scale by the same multiplier
4. When rhythm is disabled, `multiplier(forNoteAt:)` always returns `1.0` — identical to current behavior

## Testing

- With rhythm **disabled**: all sequences should sound and animate exactly as before
- With rhythm **enabled**: you should hear and see short-long patterns in the victory animation
- Try the playground first (open `index.html`, enable Rhythm, play any sequence) to audition patterns before committing to level presets
