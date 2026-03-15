//
//  ToneSettings.swift
//  ChiptuneKit
//
//  Configures waveform, envelope, filter, and modulation for tone synthesis.
//
//  Created by Claude Code on 3/15/26.
//

import Foundation

/// Configuration for tone synthesis parameters.
///
/// Controls waveform shape, envelope (attack/release), volume, timing,
/// and optional amplitude modulation (LFO). Filter settings are modeled
/// but not rendered in v1.
///
/// ## Example Usage
///
/// ```swift
/// var settings = ToneSettings.default
/// settings.waveform = .triangle
/// settings.attack = 0.01
/// settings.release = 0.05
/// settings.volume = 0.5
/// player.playNote(frequency: 440.0, settings: settings)
/// ```
public struct ToneSettings: Sendable {

    /// Waveform shape for oscillator output.
    public enum Waveform: String, Sendable, CaseIterable {
        case sine
        case triangle
        case square
        case sawtooth
        case pulse
    }

    /// Low-pass filter configuration (modeled but not rendered in v1).
    public struct FilterSettings: Sendable {
        public var enabled: Bool
        public var cutoff: Double   // Hz
        public var resonance: Double // 0.0-1.0

        public init(enabled: Bool = false, cutoff: Double = 20000, resonance: Double = 0) {
            self.enabled = enabled
            self.cutoff = cutoff
            self.resonance = resonance
        }
    }

    /// Amplitude modulation (LFO tremolo) configuration.
    public struct ModulationSettings: Sendable {
        public var enabled: Bool
        public var rate: Double   // Hz
        public var depth: Double  // 0.0-1.0

        public init(enabled: Bool = false, rate: Double = 0, depth: Double = 0) {
            self.enabled = enabled
            self.rate = rate
            self.depth = depth
        }
    }

    // MARK: - Properties

    /// Oscillator waveform shape.
    public var waveform: Waveform

    /// Duty cycle for pulse waveform (0.0-1.0). Ignored for other waveforms.
    public var dutyCycle: Double

    /// Attack time in seconds (ramp from 0 to full volume).
    public var attack: Double

    /// Release time in seconds (ramp from full volume to 0).
    public var release: Double

    /// Output volume (0.0-1.0).
    public var volume: Float

    /// Note duration in seconds.
    public var duration: Double

    /// Tempo in BPM (used by caller for scheduling, not by player).
    public var tempo: Double

    /// Low-pass filter settings (modeled, not rendered in v1).
    public var filter: FilterSettings

    /// Amplitude modulation settings.
    public var modulation: ModulationSettings

    // MARK: - Initialization

    public init(
        waveform: Waveform = .square,
        dutyCycle: Double = 0.5,
        attack: Double = 0,
        release: Double = 0,
        volume: Float = 0.3,
        duration: Double = 0.15,
        tempo: Double = 200,
        filter: FilterSettings = FilterSettings(),
        modulation: ModulationSettings = ModulationSettings()
    ) {
        self.waveform = waveform
        self.dutyCycle = dutyCycle
        self.attack = attack
        self.release = release
        self.volume = volume
        self.duration = duration
        self.tempo = tempo
        self.filter = filter
        self.modulation = modulation
    }

    // MARK: - Presets

    /// Default settings matching original ChiptunePlayer behavior (square wave, no envelope).
    public static let `default` = ToneSettings()
}
