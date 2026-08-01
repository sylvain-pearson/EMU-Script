//
//  MidiControl.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

// ----------------------------------
// A MIDI control or program message
// ----------------------------------
struct MidiControl {
    
    var isProgramChange : Bool
    var id : UInt8
    var value : UInt8
    var curve : Curve? = nil
    
    init(id: UInt8, value: UInt8) {
        self.id = id
        self.value = value
        self.isProgramChange = false
    }
    
    init(id: UInt8, curve: Curve) {
        self.id = id
        self.value = 0
        self.isProgramChange = false
        self.curve = curve
    }
    
    init(bank: UInt8, program: UInt8) {
        self.isProgramChange = true
        self.id = bank
        self.value = program
    }
}
