//
//  Step.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation

enum StepType {
    case synth
    case drum
    case sample
    case silence
    case text
}

// -------------------------------------------------------------------------------------------------
// A Step represent a MIDI note, interval, chord or sample, having a certain duration and velocity.
// -------------------------------------------------------------------------------------------------
class Step : Identifiable {
    
    private var type: StepType  // The step type
    
    var id = UUID()
    var notes: [Int]                // MIDI notes to be played
    var samples: [String]           // Names of samples to be played
    var ccMessages: [MidiControl]   // MIDI control messages
    var positions: [Int]            // Notes position on the staff (1 to 25)
    var text: String                // Text to be displayed
    var velocity: Int               // 0 = none, 128 = full
    var length: Int                 // 1 to 48 (in 4/4)
    var octave: UInt8               // The keyboard octave: 1 to 4 (or 0 if the step is a drum note)
    var sustain: Bool               // The note will be released in the next measure
    var sustained: Bool             // The note has been raised in the preceding measure
    var playing: StrumOrArp?        // Indication on how to do the strumming or arpeggio, if applicable
    var error: ScriptErrorCode      // An error code or ok
    
    func isError() -> Bool {
        return error != .ok
    }
    
    func isMIDINote() -> Bool {
        return (type == .synth || type == .drum)
    }
    
    func isSample() -> Bool {
        return (type == .sample)
    }
    
    func isSynth() -> Bool {
        return (type == .synth)
    }
    
    func isSilence() -> Bool {
        return (type == .silence)
    }
    
    func isText() -> Bool {
        return (type == .text)
    }
    
    func isEqual(_ step: Step)-> Bool {
        return step.id == id
    }
    
    func isSharp(pos: Int, transposition: Int8) -> Bool {
        var isSharp = false
        if (type == .synth) {
            if (pos < notes.count) {
                let note = notes[Int(pos)] - Int(transposition)
                isSharp = (note % 12 == 1 || note % 12 == 3 || note % 12 == 6 || note % 12 == 8 || note % 12 == 10)
            }
        }
        return isSharp
    }
    
    func isStrum() -> Bool {
        return (playing != nil && playing!.isStrum())
    }
    
    func isArp() -> Bool {
        return (playing != nil && playing!.isArp())
    }
    
    // ----------------------------------------------
    // Get the notes strumming or arpegio sequence
    // ----------------------------------------------
    func getNotesInPlayingOrder() -> [Int] {
        var sequence: [Int] = []

        if let playingOrder = self.playing {
            for i in playingOrder.sequence {
                if (i <= notes.count && i > 0) {
                    sequence.append(notes[Int(i-1)])
                }
            }
        }
        return sequence
    }
    
    // -----------------------------------
    // The default class initializer
    // -----------------------------------
    init() {
        self.length = 1
        self.velocity = 80
        self.notes = []
        self.samples = []
        self.ccMessages = []
        self.positions = []
        self.text = ""
        self.octave = 0
        self.sustain = false
        self.sustained = false
        self.playing = nil
        self.error = .ok
        self.type = .silence
    }
    
    // -----------------------------------
    // Creates a copy of the Step
    // -----------------------------------
    func clone() -> Step {
        let step = Step()
        step.length = length
        step.velocity = velocity
        step.notes = notes
        step.samples = samples
        step.ccMessages = ccMessages
        step.positions = positions
        step.text = text
        step.octave = octave
        step.sustain = sustain
        step.sustained = sustained
        step.playing = playing
        step.error = error
        step.type = type
        return step
    }
    
    // ---------------------------------------------------------------------
    // Return the step properties, in a format suitable for display
    // ---------------------------------------------------------------------
    func getProperties(transposition: Int8) -> Properties {
        var properties: Properties = Properties(text: String(localized: "Selection"))

        if (self.text != "" && !self.isError()) {
            properties.items.append(PropertyInfo(name: String(localized: "Text"), value: self.text))
        }
        
        if (self.isError()) {
            let error = ScriptError(code: self.error, info: self.text)
            properties.items.append(PropertyInfo(value: error.getMessage()))
        }
        else if (self.type == .synth) {
            properties.items.append(PropertyInfo(name: String(localized: "Octave"), value: self.octave.description))
        }
        else if (self.type == .sample) {
            properties.items.append(PropertyInfo(value: String(localized: "Sample") + String((self.samples.count > 1) ? "s" : "")))
        }
        else if (self.type == .drum) {
            for note in self.notes {
                var drumNote = ""
                
                switch (note) {
                    case 36: drumNote = String(localized:"Bass drum")
                    case 38: drumNote = String(localized:"Snare drum")
                    case 41: drumNote = String(localized:"Floor Tom 1")
                    case 45: drumNote = String(localized:"Floor Tom 1")
                    case 47: drumNote = String(localized:"Tom-tom 1")
                    case 48: drumNote = String(localized:"Tom-tom 2")
                    case 42: drumNote = String(localized:"Closed Hi-hat")
                    case 46: drumNote = String(localized:"Open Hi-hat")
                    case 51: drumNote = String(localized:"Ryde Cymbal")
                    case 61: drumNote = String(localized:"Crash Cymbal")
                    case 37: drumNote = String(localized:"Drum Stick")
                    default: drumNote = "?"
                }
                properties.items.append(PropertyInfo(value: drumNote))
            }
        }

        if (!self.isError()) {
            properties.items.append(PropertyInfo(name: String(localized: "Duration"), value: String(Float(self.length)/4)))
            properties.items.append(PropertyInfo(name: String(localized: "Velocity"), value: String(self.velocity)))
            
            var value = ""
            for note in self.notes {
                value += note.description + " "
            }
            if (value != "") {
                properties.items.append(PropertyInfo(name: "MIDI", value: value))
            }
            
            value = ""
            for note in self.notes {
                value += self.getMidiNoteAsText(note: note, transposition: transposition) + " "
            }
            if (value != "") {
                properties.items.append(PropertyInfo(name: String(localized: "Note(s)"), value: value))
            }
        }
        
        return properties
    }
    
    // -----------------------------------------------------------------
    // Get a MIDI note as text (such as: ♭G4)
    // -----------------------------------------------------------------
    func getMidiNoteAsText(note: Int, transposition: Int8) -> String {
        var textList: [String] = [ ]

        if (transposition == 3 /* E-bémol */ || transposition == 6 /* F */ || transposition == -2 /* B-bémol */ || transposition == -4 /* A-bémol */) {
            textList = ["C", "♭D", "D", "♭E", "E", "F", "♭G", "G", "♭A", "A", "♭B", "B"]
        }
        else {
            textList = ["C", "♯C", "D", "♯D", "E", "F", "♯F", "G", "♯G", "A", "♯A", "B"]
        }
        
        if (note != -1)  {
            return textList[note % 12] + String((note/12)-1)
        }
        else {
            return "?"
        }
    }
    
    // -----------------------------------------------------------
    // Add a synth note, interval or chord to the step
    // -----------------------------------------------------------
    func add(notes: String, octave: UInt8, transposition: Int8) {
        var isSharp = false
        var isHigher = notes.hasSuffix("'")
        let isLower = notes.hasPrefix("#'") || notes.hasPrefix("'")
        
        for c in notes {
            if (c == "#") {
                isSharp = true
            }
            else if (c != "'") {
                let note = (isSharp ? "#" : "" ) + (isLower ? "'" : "") + String(c) + (isHigher ? "'" : "")
                self.add(note: note, octave: octave, transposition: transposition)
                isSharp = false
                isHigher = false
            }
        }
        
        if (self.isError()) {
            self.text = notes
            self.notes = [-1]
      
            if (self.error == .noteIsTooLow) {
                self.positions = [0]
            }
            else if (self.error == .noteIsTooHigh) {
                self.positions = [15]
            }
            else if let c = notes.first {
                self.positions = [2]
                
                if (c == "#" || c == "#" || c.isNumber) {
                    self.error = .invalidNote
                }
                else {
                    self.error = .syntaxError
                }
            }
        }
    }
    
    // -----------------------------------------------------------------
    // Add an hard-coded MIDI note
    // -----------------------------------------------------------------
    func add(midiNote: Int, text: String, isDrum: Bool) {
        self.type = isDrum ?.drum : .synth
        self.text.append(text + " ")
        self.positions.append(12)
        self.notes.append(midiNote)
        self.octave = 0
    }
        
    // -----------------------------------------------------------------
    // Add a sample to the step
    // -----------------------------------------------------------------
    func add(sample: String) {
        self.type = .sample
        self.text.append(String(sample) + " ")
        self.positions.append(7)
        self.samples.append(sample)
        self.octave = 0
    }
    
    // -----------------------------------------------------------------
    // Add lyrics to the step
    // -----------------------------------------------------------------
    func add(text: String)  {
        self.type = .text
        self.text = text
        self.octave = 0
    }
    
    // -----------------------------------------------------------------
    // Add a drum note to the step
    // -----------------------------------------------------------------
    func add(drum: String)
    {
        self.type = .drum
        if (drum == ".") {
            self.type = .silence
        }
        
        var note = 0

        switch (drum.lowercased()) {
            case "b": note = 36     // bass drum
            case "s": note = 38     // snare drum
            case "1": note = 41     // floor tom 1
            case "2": note = 45     // floor tom 2
            case "3": note = 47     // tom-tom 1
            case "4": note = 48     // tom-tom 2
            case "i": note = 37     // drum stick
            case "h": note = 42     // closed hi-hat
            case "o": note = 46     // open hi-hat
            case "r": note = 51     // ryde cymbal
            case "c": note = 49     // crash symbal
            case ".": note = 0      // silence
            default:
                self.error = .invalidDrum
        }
        
        if (!self.isSilence()) {
            self.notes.append(note)
            self.text.append(String(drum))  // + " "
            self.octave = 0
        }
    }
    
    // -----------------------------------------------------------
    // Add a synth note to the step
    // -----------------------------------------------------------
    private func add(note: String, octave: UInt8, transposition: Int8) {
        var pos = 0
        var text = ""
        var isError = true
        
        var previousMidiNote = 0
        if (self.notes.last != nil) {
            previousMidiNote = self.notes.last!
        }
        
        let notes = [
            "'1", "#'1", "'2", "#'2", "'3", "'4", "#'4", "'5", "#'5", "'6", "#'6", "'7",
            "1",  "#1",  "2",  "#2",  "3",  "4",  "#4",  "5",  "#5",  "6",  "#6",  "7",
            "1'", "#1'", "2'", "#2'", "3'", "4'", "#4'", "5'", "#5'", "6'", "#6'", "7'"
        ]
        
        let posMap = [
            -4, -4, -3, -3, -2, -1, -1,  0,  0,  1,  1,  2,
            3,   3,  4,  4,  5,  6,  6,  7,  7,  8,  8,  9,
            10, 10, 11, 11, 12, 13, 13, 14, 14, 15, 15, 16
        ]
        
        let textList = ["1", "♯1", "2", "♯2", "3", "4", "♯4", "5", "♯5", "6", "♯6", "7"]
        
        for n in notes {
            pos += 1
            if (note == n) {
                isError = false
                break
            }
        }
        
        self.type = .synth
        if (note == ".") {
            self.text = ""
            self.type = .silence
        }
        else if (isError) {
            self.error = .syntaxError
        }
        else
        {
            self.positions.append(posMap[pos-1])
            
            if (!self.isSilence() && !self.isError()) {
                let midiNote = (Int(octave-1) * 12) + pos - 1
                self.notes.append(midiNote + Int(transposition))
                
                if (self.octave == 0 && midiNote > 24) {
                    self.octave = UInt8((midiNote) / 12) - 2
                }
                
                text = textList[midiNote % 12]
            }
            
            // Make sure that notes are in ascending order
            while (self.notes.count > 1 && previousMidiNote >= self.notes.last!) {
                self.notes[self.notes.count - 1] += 12
                self.positions[self.positions.count - 1] += 7
            }
            
            if (text != "") {
                self.text.append(text)
                self.text.append(" ")
            }
            if let pos = self.positions.last {
                if (pos < 0) {
                    self.error = .noteIsTooLow
                }
                else if (pos > 15) {
                    self.error = .noteIsTooHigh
                }
            }
        }
    }
}
