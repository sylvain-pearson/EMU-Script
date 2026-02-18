//
//  MusicalSection.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation

// --------------------------------------------------------------
// A musical section has a list of measures for each instrument
// --------------------------------------------------------------
class MusicalSection {
    
    var name : String
    
    // Map instrument names to arrays of measures
    var measures: [String: [Measure]] = [:]
    
    init(name: String, length: Int) {
        self.name = name
    }
    
    // -------------------------------------------
    // Count the number measures in the section
    // -------------------------------------------
    func getLength() -> Int {
        var length  = 0
        for measure in measures.values {
            if (measure.count > length) {
                length = measure.count
            }
        }
        return length
    }
    
    // --------------------------------------
    // Return the requested measure
    // --------------------------------------
    func getMeasures(instrumentName: String) -> [Measure] {
        
        for measure in measures {
            if (measure.0 == instrumentName) {
                return measure.1
            }
        }
    
        return []
    }
    
    // -----------------------------------------------------------------------
    // Get the lenght of a note that is spread across more than one measure
    // -----------------------------------------------------------------------
    func getSustainedNoteDuration(instrumentName: String, measureNumber: Int) -> Int {
        var duration = 0
        var n = 0
        let measures = getMeasures(instrumentName: instrumentName)
        
        for measure in measures {
            if (n == measureNumber && duration == 0) {
                // First part of the note
                if let step = measure.steps.last {
                    duration += step.length
                }
            }
            else if (duration > 0) {
                // Continuation of the note
                if let step = measure.steps.first {
                    if (step.sustained == true) {
                        duration += step.length
                        if (measure.steps.count > 1) {
                            break
                        }
                    }
                    else {
                        break
                    }
                }
            }
            else {
                n = n + 1
            }
        }
        
        return duration
    }
    
    // -------------------------------------------
    // Get the chord from the chord progression
    // -------------------------------------------
    func getChordAt(measureNumber: Int, position: Int) -> String {
        var chord = ""
        let measures = getMeasures(instrumentName: "chord")
        if (measureNumber <= measures.count) {
            let measure = measures[measureNumber-1]
            var stepPosition = 0
            for step in measure.steps {
                if (position >= stepPosition && position < stepPosition + step.length) {
                    chord = step.text
                    break
                }
                stepPosition += step.length
            }
        }
        return chord
    }
}
