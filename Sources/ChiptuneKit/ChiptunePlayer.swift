//
//  ChiptunePlayer.swift
//  ChiptuneKit
//
//  Generates chiptune-style square wave sounds using AVAudioEngine.
//
//  Created by Claude Code on 12/23/24.
//

import AVFoundation
import Combine
import Foundation

/// Generates chiptune-style square wave sounds using AVAudioEngine.
///
/// ## Example Usage
///
/// ```swift
/// let player = ChiptunePlayer()
/// player.start()
///
/// // Play a specific note
/// player.playNote(named: "C4", duration: 0.1)
///
/// // Play based on bit position (for binary games)
/// player.playNoteForBit(position: 7, activeBitCount: 8)
///
/// // Play victory melody note
/// player.playVictoryNote(noteIndex: 0)
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

    /// Volume control (0.0 to 1.0)
    public var volume: Float = 0.3

    /// Note frequencies for musical scales (in Hz).
    /// Using octave 4-5 range for pleasant chiptune sound.
    public static let noteFrequencies: [String: Double] = [
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

    /// Ode to Joy melody notes for victory sequences.
    /// The melody: E E F G | G F E D | C C D E | E D D
    public static let odeToJoyNotes: [String] = [
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

    private func setupSourceNode() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = ablPointer[0]
            let ptr = buffer.mData?.assumingMemoryBound(to: Float.self)

            for frame in 0..<Int(frameCount) {
                if self.isPlaying && self.currentFrequency > 0 {
                    // Generate square wave
                    let phaseIncrement = self.currentFrequency / self.sampleRate
                    self.currentPhase += phaseIncrement
                    if self.currentPhase > 1.0 {
                        self.currentPhase -= 1.0
                    }

                    // Square wave: high for first half, low for second half
                    let squareValue: Float = self.currentPhase < 0.5 ? 1.0 : -1.0
                    ptr?[frame] = squareValue * self.volume
                } else {
                    ptr?[frame] = 0
                }
            }

            return noErr
        }

        audioEngine.attach(sourceNode!)
        audioEngine.connect(sourceNode!, to: audioEngine.mainMixerNode, format: format)
    }

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

    /// Play a note at the given frequency for a duration.
    ///
    /// - Parameters:
    ///   - frequency: The frequency in Hz
    ///   - duration: How long to play in seconds
    public func playNote(frequency: Double, duration: Double) {
        currentFrequency = frequency
        currentPhase = 0
        isPlaying = true

        // Stop the note after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.9) { [weak self] in
            self?.isPlaying = false
        }
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
        // Pentatonic scale for pleasant sound: C, D, E, G, A
        let pentatonicFrequencies: [Double] = [
            261.63, 293.66, 329.63, 392.00, 440.00,  // C4, D4, E4, G4, A4
            523.25, 587.33, 659.25, 783.99, 880.00   // C5, D5, E5, G5, A5
        ]

        // Scale position to available notes
        let noteIndex = min(position % pentatonicFrequencies.count, pentatonicFrequencies.count - 1)
        let frequency = pentatonicFrequencies[noteIndex]

        playNote(frequency: frequency, duration: duration)
    }

    /// Play a victory melody note by index.
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
