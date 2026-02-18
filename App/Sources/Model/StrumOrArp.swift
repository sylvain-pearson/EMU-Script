//
//  StrumOrArp.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

// ------------------------------------------------------
// Information on how to do the strumming or arpeggio
// ------------------------------------------------------
struct StrumOrArp {
    
    var step: UInt8         // The length of a step (1-12) or 0, when strumming
    var duration: UInt8     // The duration of each note, in steps (arp) or ms (strumming)
    var vdec: UInt8         // The velocity decrease, in percent (arp)
    var sequence: [UInt8]   // The playing order: a list of space separated numbers, where 1 refer to
                            // the first note of the step, 2 the second note of the step and so on.

    // Arpegio init
    init(sequence: [UInt8], step: UInt8, duration: UInt8) {
        self.step = step
        self.duration = duration
        self.sequence = sequence
        self.vdec = 0
        
        if (self.duration < 2) {
            self.duration = 2
        }
        else if (self.duration > 24) {
            self.duration = 24
        }
        
        if (self.step < 2) {
            self.step = 2
        }
        else if (self.step > 24) {
            self.step = 24
        }
    }
    
    // Strum init
    init(sequence: [UInt8], msec: UInt8, vdec: UInt8) {
        self.step = 0
        self.duration = msec
        self.sequence = sequence
        self.vdec = vdec
        
        if (self.duration < 3) {
            self.duration = 3
        }
        else if (self.duration > 15) {
            self.duration = 15
        }
        if (self.vdec > 10) {
            self.vdec = 10
        }
    }
    
    func isStrum() -> Bool {
        return (step == 0)
    }
    
    func isArp() -> Bool {
        return (step > 0)
    }
}
