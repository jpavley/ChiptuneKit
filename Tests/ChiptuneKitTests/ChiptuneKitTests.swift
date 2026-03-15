//
//  ChiptuneKitTests.swift
//  ChiptuneKit
//
//  Created by Claude Code on 12/23/24.
//

import XCTest
@testable import ChiptuneKit

final class ChiptuneKitTests: XCTestCase {

    // MARK: - Note Frequency Tests

    func testNoteFrequenciesExist() {
        XCTAssertNotNil(ChiptunePlayer.noteFrequencies["C4"])
        XCTAssertNotNil(ChiptunePlayer.noteFrequencies["D4"])
        XCTAssertNotNil(ChiptunePlayer.noteFrequencies["E4"])
        XCTAssertNotNil(ChiptunePlayer.noteFrequencies["F4"])
        XCTAssertNotNil(ChiptunePlayer.noteFrequencies["G4"])
        XCTAssertNotNil(ChiptunePlayer.noteFrequencies["A4"])
        XCTAssertNotNil(ChiptunePlayer.noteFrequencies["B4"])
        XCTAssertNotNil(ChiptunePlayer.noteFrequencies["C5"])
    }

    func testA4FrequencyIsStandard() {
        XCTAssertEqual(ChiptunePlayer.noteFrequencies["A4"], 440.00)
    }

    // MARK: - Pentatonic Scale Tests

    func testPentatonicFrequenciesCount() {
        XCTAssertEqual(ChiptunePlayer.pentatonicFrequencies.count, 10)
    }

    func testPentatonicFrequencyForPosition() {
        // Position 0 = C4
        XCTAssertEqual(ChiptunePlayer.pentatonicFrequency(forPosition: 0), 261.63)
        // Position 4 = A4
        XCTAssertEqual(ChiptunePlayer.pentatonicFrequency(forPosition: 4), 440.00)
        // Position 10 wraps to C4
        XCTAssertEqual(ChiptunePlayer.pentatonicFrequency(forPosition: 10), 261.63)
    }

    // MARK: - Legacy Melody Tests

    func testOdeToJoyMelodyLength() {
        XCTAssertEqual(ChiptunePlayer.odeToJoyNotes.count, 16)
    }

    func testOdeToJoyNotesAreValid() {
        for note in ChiptunePlayer.odeToJoyNotes {
            XCTAssertNotNil(ChiptunePlayer.noteFrequencies[note],
                           "Note \(note) should exist in noteFrequencies")
        }
    }

    // MARK: - ToneSettings Tests

    func testToneSettingsDefaultValues() {
        let settings = ToneSettings.default
        XCTAssertEqual(settings.waveform, .square)
        XCTAssertEqual(settings.dutyCycle, 0.5, accuracy: 0.001)
        XCTAssertEqual(settings.attack, 0, accuracy: 0.001)
        XCTAssertEqual(settings.release, 0, accuracy: 0.001)
        XCTAssertEqual(settings.volume, 0.3, accuracy: 0.001)
        XCTAssertEqual(settings.duration, 0.15, accuracy: 0.001)
        XCTAssertEqual(settings.tempo, 200, accuracy: 0.1)
    }

    func testWaveformEnumCases() {
        let allCases = ToneSettings.Waveform.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.sine))
        XCTAssertTrue(allCases.contains(.triangle))
        XCTAssertTrue(allCases.contains(.square))
        XCTAssertTrue(allCases.contains(.sawtooth))
        XCTAssertTrue(allCases.contains(.pulse))
    }

    func testToneSettingsCustomInit() {
        let settings = ToneSettings(
            waveform: .sine,
            dutyCycle: 0.3,
            attack: 0.01,
            release: 0.05,
            volume: 0.5,
            duration: 0.1,
            tempo: 300,
            modulation: .init(enabled: true, rate: 5.0, depth: 0.3)
        )
        XCTAssertEqual(settings.waveform, .sine)
        XCTAssertEqual(settings.dutyCycle, 0.3, accuracy: 0.001)
        XCTAssertEqual(settings.attack, 0.01, accuracy: 0.001)
        XCTAssertEqual(settings.release, 0.05, accuracy: 0.001)
        XCTAssertEqual(settings.volume, 0.5, accuracy: 0.001)
        XCTAssertEqual(settings.duration, 0.1, accuracy: 0.001)
        XCTAssertEqual(settings.tempo, 300, accuracy: 0.1)
        XCTAssertTrue(settings.modulation.enabled)
        XCTAssertEqual(settings.modulation.rate, 5.0, accuracy: 0.001)
        XCTAssertEqual(settings.modulation.depth, 0.3, accuracy: 0.001)
    }

    func testFilterSettingsDefaults() {
        let filter = ToneSettings.FilterSettings()
        XCTAssertFalse(filter.enabled)
        XCTAssertEqual(filter.cutoff, 20000, accuracy: 0.1)
        XCTAssertEqual(filter.resonance, 0, accuracy: 0.001)
    }

    func testModulationSettingsDefaults() {
        let mod = ToneSettings.ModulationSettings()
        XCTAssertFalse(mod.enabled)
        XCTAssertEqual(mod.rate, 0, accuracy: 0.001)
        XCTAssertEqual(mod.depth, 0, accuracy: 0.001)
    }

    // MARK: - Player Tests

    @MainActor
    func testDefaultVolume() {
        let player = ChiptunePlayer()
        XCTAssertEqual(player.volume, 0.3, accuracy: 0.001)
    }

    @MainActor
    func testVolumeCanBeSet() {
        let player = ChiptunePlayer()
        player.volume = 0.5
        XCTAssertEqual(player.volume, 0.5, accuracy: 0.001)
    }

    @MainActor
    func testToneSettingsCanBeSet() {
        let player = ChiptunePlayer()
        player.toneSettings = ToneSettings(waveform: .sine, volume: 0.7)
        XCTAssertEqual(player.toneSettings.waveform, .sine)
        XCTAssertEqual(player.volume, 0.7, accuracy: 0.001)
    }

    @MainActor
    func testGetVictoryNoteFrequency() {
        let player = ChiptunePlayer()
        let frequency = player.getVictoryNoteFrequency(noteIndex: 0)
        XCTAssertEqual(frequency, ChiptunePlayer.noteFrequencies["E4"])
    }

    @MainActor
    func testGetVictoryNoteFrequencyWrapsAround() {
        let player = ChiptunePlayer()
        let frequency16 = player.getVictoryNoteFrequency(noteIndex: 16)
        let frequency0 = player.getVictoryNoteFrequency(noteIndex: 0)
        XCTAssertEqual(frequency16, frequency0)
    }
}
