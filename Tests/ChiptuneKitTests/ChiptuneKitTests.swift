//
//  ChiptuneKitTests.swift
//  ChiptuneKit
//
//  Created by Claude Code on 12/23/24.
//

import XCTest
@testable import ChiptuneKit

final class ChiptuneKitTests: XCTestCase {

    func testNoteFrequenciesExist() {
        // Verify all expected notes are defined
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
        // A4 should be 440 Hz (standard tuning)
        XCTAssertEqual(ChiptunePlayer.noteFrequencies["A4"], 440.00)
    }

    func testOdeToJoyMelodyLength() {
        // Ode to Joy melody should have 16 notes
        XCTAssertEqual(ChiptunePlayer.odeToJoyNotes.count, 16)
    }

    func testOdeToJoyNotesAreValid() {
        // All melody notes should exist in noteFrequencies
        for note in ChiptunePlayer.odeToJoyNotes {
            XCTAssertNotNil(ChiptunePlayer.noteFrequencies[note],
                           "Note \(note) should exist in noteFrequencies")
        }
    }

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
    func testGetVictoryNoteFrequency() {
        let player = ChiptunePlayer()
        // First note is E4
        let frequency = player.getVictoryNoteFrequency(noteIndex: 0)
        XCTAssertEqual(frequency, ChiptunePlayer.noteFrequencies["E4"])
    }

    @MainActor
    func testGetVictoryNoteFrequencyWrapsAround() {
        let player = ChiptunePlayer()
        // Index 16 should wrap to index 0
        let frequency16 = player.getVictoryNoteFrequency(noteIndex: 16)
        let frequency0 = player.getVictoryNoteFrequency(noteIndex: 0)
        XCTAssertEqual(frequency16, frequency0)
    }
}
