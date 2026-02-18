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
    
    init(id: UInt8, value: UInt8) {
        self.id = id
        self.value = value
        self.isProgramChange = false
    }
    
    init(bank: UInt8, program: UInt8) {
        self.isProgramChange = true
        self.id = bank - 1
        self.value = program - 1
    }
}
