//
//  ChiptunePlayer.swift
//  ChiptuneKit
//
//  Generates chiptune-style sounds using AVAudioEngine with configurable
//  waveforms, envelopes, and amplitude modulation.
//
//  Created by Claude Code on 12/23/24.
//

import AVFoundation
import Combine
import Foundation

/// Generates chiptune-style sounds using AVAudioEngine.
///
/// Supports multiple waveform types (sine, triangle, square, sawtooth, pulse),
/// per-note envelope shaping (attack/release), and amplitude modulation (LFO).
///
/// ## Example Usage
///
/// ```swift
/// let player = ChiptunePlayer()
/// player.start()
///
/// // Play with default square wave
/// player.playNote(named: "C4", duration: 0.1)
///
/// // Play with custom tone settings
/// var settings = ToneSettings(waveform: .sine, attack: 0.01, release: 0.05)
/// player.playNote(frequency: 440.0, settings: settings)
///
/// // Play based on bit position (for binary games)
/// player.playNoteForBit(position: 7, activeBitCount: 8)
///
/// player.stop()
/// ```
@MainActor
public class ChiptunePlayer: ObservableObject {
    /// Required for ObservableObject conformance
    nonisolated public let objectWillChange = ObservableObjectPublisher()

    private var audioEngine: AVAudioEngine
    private var sourceNode: AVAudioSourceNode?
    private var currentPhase: Double = 0
    private var currentFrequency: Double = 0
    private var isPlaying: Bool = false
    private let sampleRate: Double = 44100

    // MARK: - Envelope & Modulation Frame Tracking

    /// Frame index within the current note (reset on each playNote call).
    private var noteFrameIndex: Int = 0

    /// Total frames for the current note's duration.
    private var noteTotalFrames: Int = 0

    // MARK: - Tone Settings

    /// Active tone settings applied to the render callback.
    /// Change this before calling `playNote` or use `playNote(frequency:settings:)`.
    public var toneSettings: ToneSettings = .default

    /// Volume control (0.0 to 1.0). Convenience accessor for `toneSettings.volume`.
    public var volume: Float {
        get { toneSettings.volume }
        set { toneSettings.volume = newValue }
    }

    /// Note frequencies for musical scales (in Hz).
    /// Using octave 4-5 range for pleasant chiptune sound.
    nonisolated public static let noteFrequencies: [String: Double] = [
        "C4": 261.63,
        "D4": 293.66,
        "E4": 329.63,
        "F4": 349.23,
        "G4": 392.00,
        "A4": 440.00,
        "B4": 493.88,
        "C5": 523.25,
        "D5": 587.33,
        "E5": 659.25,
        "F5": 698.46,
        "G5": 783.99
    ]

    /// Pentatonic scale frequencies for bit-position mapping.
    /// Two octaves of C, D, E, G, A — no dissonant intervals.
    nonisolated public static let pentatonicFrequencies: [Double] = [
        261.63, 293.66, 329.63, 392.00, 440.00,  // C4, D4, E4, G4, A4
        523.25, 587.33, 659.25, 783.99, 880.00    // C5, D5, E5, G5, A5
    ]

    /// Ode to Joy melody notes for victory sequences (legacy).
    /// The melody: E E F G | G F E D | C C D E | E D D
    nonisolated public static let odeToJoyNotes: [String] = [
        "E4", "E4", "F4", "G4",  // First phrase
        "G4", "F4", "E4", "D4",  // Second phrase
        "C4", "C4", "D4", "E4",  // Third phrase
        "E4", "D4", "D4", "D4"   // Fourth phrase (ending)
    ]

    /// Creates a new ChiptunePlayer instance.
    public init() {
        audioEngine = AVAudioEngine()
        setupAudioSession()
    }

    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #endif
    }

    // MARK: - Waveform Generation

    /// Generate a single sample for the given waveform at the current phase.
    ///
    /// Phase is normalized to [0, 1) representing one cycle of the waveform.
    /// - Parameters:
    ///   - phase: Normalized phase position (0.0 to 1.0)
    ///   - waveform: The waveform shape to generate
    ///   - dutyCycle: Duty cycle for pulse waveform (ignored for others)
    /// - Returns: Sample value in [-1.0, 1.0]
    nonisolated private func generateSample(phase: Double, waveform: ToneSettings.Waveform, dutyCycle: Double) -> Float {
        switch waveform {
        case .sine:
            return Float(sin(2.0 * .pi * phase))
        case .triangle:
            return Float(4.0 * abs(phase - 0.5) - 1.0)
        case .square:
            return phase < 0.5 ? 1.0 : -1.0
        case .sawtooth:
            return Float(2.0 * phase - 1.0)
        case .pulse:
            return phase < dutyCycle ? 1.0 : -1.0
        }
    }

    // MARK: - Envelope

    /// Calculate envelope amplitude for the current frame position.
    ///
    /// Linear attack ramp from 0→1, sustain at 1, linear release ramp from 1→0.
    /// - Parameters:
    ///   - framesElapsed: Frames since note start
    ///   - totalFrames: Total frames for the note duration
    ///   - attackFrames: Number of frames for attack ramp
    ///   - releaseFrames: Number of frames for release ramp
    /// - Returns: Envelope amplitude (0.0 to 1.0)
    nonisolated private func envelopeAmplitude(framesElapsed: Int, totalFrames: Int, attackFrames: Int, releaseFrames: Int) -> Float {
        guard totalFrames > 0 else { return 0 }

        // Attack phase
        if framesElapsed < attackFrames && attackFrames > 0 {
            return Float(framesElapsed) / Float(attackFrames)
        }

        // Release phase
        let releaseStart = totalFrames - releaseFrames
        if framesElapsed >= releaseStart && releaseFrames > 0 {
            let releaseElapsed = framesElapsed - releaseStart
            return max(0, 1.0 - Float(releaseElapsed) / Float(releaseFrames))
        }

        // Sustain phase
        return 1.0
    }

    // MARK: - LFO Modulation

    /// Calculate LFO amplitude modulation value.
    ///
    /// Produces a tremolo effect by modulating volume with a sine wave.
    /// - Parameters:
    ///   - framesElapsed: Frames since note start
    ///   - sampleRate: Audio sample rate
    ///   - rate: LFO frequency in Hz
    ///   - depth: Modulation depth (0.0 = no effect, 1.0 = full effect)
    /// - Returns: Amplitude multiplier (ranges from (1-depth) to 1.0)
    nonisolated private func lfoValue(framesElapsed: Int, sampleRate: Double, rate: Double, depth: Double) -> Float {
        guard depth > 0 && rate > 0 else { return 1.0 }
        let lfoPhase = Double(framesElapsed) / sampleRate * rate
        let lfo = sin(2.0 * .pi * lfoPhase)
        // Map sine [-1,1] to amplitude range [(1-depth), 1.0]
        return Float(1.0 - depth * 0.5 * (1.0 - lfo))
    }

    // MARK: - Audio Engine Setup

    private func setupSourceNode() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = ablPointer[0]
            let ptr = buffer.mData?.assumingMemoryBound(to: Float.self)

            // Snapshot settings for this render pass (avoid repeated property access)
            let playing = self.isPlaying
            let freq = self.currentFrequency
            let settings = self.toneSettings
            let sr = self.sampleRate
            let totalFrames = self.noteTotalFrames
            let attackFrames = Int(settings.attack * sr)
            let releaseFrames = Int(settings.release * sr)

            for frame in 0..<Int(frameCount) {
                if playing && freq > 0 {
                    let frameIndex = self.noteFrameIndex

                    // Stop if we've exceeded the note duration
                    guard frameIndex < totalFrames else {
                        ptr?[frame] = 0
                        self.isPlaying = false
                        continue
                    }

                    // Phase accumulation
                    let phaseIncrement = freq / sr
                    self.currentPhase += phaseIncrement
                    if self.currentPhase > 1.0 {
                        self.currentPhase -= 1.0
                    }

                    // Waveform
                    let sample = self.generateSample(
                        phase: self.currentPhase,
                        waveform: settings.waveform,
                        dutyCycle: settings.dutyCycle
                    )

                    // Envelope
                    let envelope = self.envelopeAmplitude(
                        framesElapsed: frameIndex,
                        totalFrames: totalFrames,
                        attackFrames: attackFrames,
                        releaseFrames: releaseFrames
                    )

                    // LFO modulation
                    let lfo = self.lfoValue(
                        framesElapsed: frameIndex,
                        sampleRate: sr,
                        rate: settings.modulation.rate,
                        depth: settings.modulation.enabled ? settings.modulation.depth : 0
                    )

                    ptr?[frame] = sample * settings.volume * envelope * lfo
                    self.noteFrameIndex += 1
                } else {
                    ptr?[frame] = 0
                }
            }

            return noErr
        }

        audioEngine.attach(sourceNode!)
        audioEngine.connect(sourceNode!, to: audioEngine.mainMixerNode, format: format)
    }

    // MARK: - Public API

    /// Start the audio engine.
    ///
    /// Call this before playing any notes. The engine will remain running
    /// until `stop()` is called.
    public func start() {
        guard !audioEngine.isRunning else { return }

        setupSourceNode()

        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    /// Stop the audio engine.
    ///
    /// Call this when audio is no longer needed to free resources.
    public func stop() {
        isPlaying = false
        audioEngine.stop()
        if let node = sourceNode {
            audioEngine.detach(node)
            sourceNode = nil
        }
    }

    /// Play a note at the given frequency for a duration using current tone settings.
    ///
    /// - Parameters:
    ///   - frequency: The frequency in Hz
    ///   - duration: How long to play in seconds
    public func playNote(frequency: Double, duration: Double) {
        currentFrequency = frequency
        currentPhase = 0
        noteFrameIndex = 0
        noteTotalFrames = Int(duration * sampleRate)
        isPlaying = true
    }

    /// Play a note at the given frequency using specific tone settings.
    ///
    /// Applies the settings before playing. The settings persist for subsequent
    /// calls to `playNote(frequency:duration:)`.
    ///
    /// - Parameters:
    ///   - frequency: The frequency in Hz
    ///   - settings: Tone settings to apply
    public func playNote(frequency: Double, settings: ToneSettings) {
        toneSettings = settings
        playNote(frequency: frequency, duration: settings.duration)
    }

    /// Play a named note (e.g., "C4", "E4").
    ///
    /// - Parameters:
    ///   - noteName: The note name (e.g., "C4", "A4", "G5")
    ///   - duration: How long to play in seconds (default: 0.15)
    public func playNote(named noteName: String, duration: Double = 0.15) {
        guard let frequency = ChiptunePlayer.noteFrequencies[noteName] else { return }
        playNote(frequency: frequency, duration: duration)
    }

    /// Play a note based on bit position.
    ///
    /// Maps bit positions to a pentatonic scale for pleasant sound.
    /// Higher bit positions produce higher notes.
    ///
    /// - Parameters:
    ///   - position: The bit position (0-15 typically)
    ///   - activeBitCount: Total number of active bits (for scaling)
    ///   - duration: How long to play in seconds (default: 0.15)
    public func playNoteForBit(position: Int, activeBitCount: Int, duration: Double = 0.15) {
        let noteIndex = position % ChiptunePlayer.pentatonicFrequencies.count
        let frequency = ChiptunePlayer.pentatonicFrequencies[noteIndex]
        playNote(frequency: frequency, duration: duration)
    }

    /// Get the pentatonic frequency for a bit position.
    ///
    /// - Parameter position: The bit position (0-15, wraps around)
    /// - Returns: The frequency in Hz
    nonisolated public static func pentatonicFrequency(forPosition position: Int) -> Double {
        let index = position % pentatonicFrequencies.count
        return pentatonicFrequencies[index]
    }

    /// Play a victory melody note by index (legacy Ode to Joy).
    ///
    /// Uses the Ode to Joy melody. Call repeatedly with incrementing indices
    /// to play the full melody.
    ///
    /// - Parameters:
    ///   - noteIndex: Index into the melody (0-15, wraps around)
    ///   - duration: How long to play in seconds (default: 0.18)
    public func playVictoryNote(noteIndex: Int, duration: Double = 0.18) {
        let notes = ChiptunePlayer.odeToJoyNotes
        let safeIndex = noteIndex % notes.count
        playNote(named: notes[safeIndex], duration: duration)
    }

    /// Get the frequency for a victory melody note.
    ///
    /// - Parameter noteIndex: Index into the melody (0-15, wraps around)
    /// - Returns: The frequency in Hz
    public func getVictoryNoteFrequency(noteIndex: Int) -> Double {
        let notes = ChiptunePlayer.odeToJoyNotes
        let safeIndex = noteIndex % notes.count
        return ChiptunePlayer.noteFrequencies[notes[safeIndex]] ?? 440.0
    }
}
