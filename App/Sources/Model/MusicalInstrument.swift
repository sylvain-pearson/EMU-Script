//
//  MusicalInstrument.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import UniformTypeIdentifiers

// ----------------------------------------------------------------
// A MIDI musical instrument
// ----------------------------------------------------------------
struct MusicalInstrument: Identifiable, Hashable {
    
    let id = UUID()
    let name: String
    var endpoint: String = "MIDI Input"     // The MIDI endpoint
    var channel: UInt8 = 0                  // The MIDI channel (0-15)
    var octave: UInt8 = 0                   // The keyboard octave: 1, 2, 3 or 4
    var velocity: UInt8 = 100               // The MIDI velocity: 0-127
    var isSelected = true
    
    func isDrum() -> Bool {
        return (octave == 0 && !isSampler())
    }
    
    func isSampler() -> Bool {
        return (endpoint == "")
    }
}
