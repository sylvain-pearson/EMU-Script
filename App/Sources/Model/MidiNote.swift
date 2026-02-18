//
//  MidiNote.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

// --------------------------------
// The definition of a MIDI note
// --------------------------------
struct MidiNote {
    var name : String
    var value : Int = 0         // 0 to 127
}
