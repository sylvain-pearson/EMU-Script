//
//  Chords.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation

struct Chords {
    
    private var map: [String : String] = [:]
    
    init() {
        
        // Diatonic triads : C, Dm, Em, F, G, Am, B˚(diminished)
        map["1M"] = "1 3 5"
        map["2m"] = "2 4 6"
        map["3m"] = "3 5 7"
        map["4M"] = "4 6 1"
        map["5M"] = "5 7 2"
        map["6m"] = "6 1 3"
        map["7d"] = "7 2 4"
        
        // Chromatic major and minor triads : Cm, D, E, Fm, Gm, A, Bm, BM
        map["1m"] = "1 #2 5"
        map["2M"] = "2 #4 6"
        map["3M"] = "3 #5 7"
        map["4m"] = "4 #5 1"
        map["5m"] = "5 #6 2"
        map["6M"] = "6 #1 3"
        map["7m"] = "7 2 #4"
        map["7M"] = "7 #2 #4"
        
        // Chromatic diminished triads : C°, D°, E°, F°, G°, A°
        map["1d"] = "1 #2 #4"
        map["2d"] = "2 4 #5"
        map["3d"] = "3 5 #6"
        map["4d"] = "4 #5 7"
        map["5d"] = "5 #6 #1"
        map["6d"] = "6 1 #2"
        
        // Chromatic augmented triads : C+, D+, E+°, F+, G+, A+, B+
        map["1a"] = "1 3 #5"
        map["2a"] = "2 #4 #6"
        map["3a"] = "3 #5 1"
        map["4a"] = "4 6 #1"
        map["5a"] = "5 7 #2"
        map["6a"] = "6 #1 4"
        map["7a"] = "7 #2 5"
        
        // Diatonic seventh chords : CM7, Dm7, Em7, FM7, G7, Am7, Bø7
        map["1M7"] = "1 3 5 7"
        map["2m7"] = "2 4 6 1"
        map["3m7"] = "3 5 7 2"
        map["4M7"] = "4 6 1 3"
        map["5D7"] = "5 7 2 4"
        map["6m7"] = "6 1 3 5"
        map["7d7"] = "7 2 4 6"
        
        // Chromatic dominant sevenths chords : C7, D7, E7, F7, A7, B7
        map["1D7"] = "1 3 5 #6"
        map["2D7"] = "2 #4 6 1"
        map["3D7"] = "3 #5 7 2"
        map["4D7"] = "4 6 1 #2"
        map["6D7"] = "6 #1 3 5"
        map["7D7"] = "7 #2 #4 6"

        // Chromatic major sevenths chords : DM7, EM7, GM7, AM7, BM7
        map["2M7"] = "2 4 6 #1"
        map["3M7"] = "3 5 7 #2"
        map["5M7"] = "5 7 2 #4"
        map["6M7"] = "6 1 3 #5"
        map["7M7"] = "7 2 4 #6"

        // Chromatic minor sevenths chords : Cm7, Fm7, Gm7, Bm7
        map["1m7"] = "1 #2 5 #6"
        map["4m7"] = "4 #5 1 #2"
        map["5m7"] = "5 #6 2 4"
        map["7m7"] = "7 2 #4 6"
        
        // Chromatic diminished sevenths chords : , C°7, D°7, E°7, F°7, G°7, A°7
        map["1d7"] = "1 #2 #4 6"
        map["2d7"] = "2 4 #5 7"
        map["3d7"] = "3 5 #6 #1"
        map["4d7"] = "4 #5 7 2"
        map["5d7"] = "5 #6 #1 3"
        map["6d7"] = "6 1 #2 #4"
    }
    
    //--------------------------------
    // Returns the notes of a chord
    //--------------------------------
    func find(name: String) -> String {
        
        var chord = get(name: name)
        chord = chord.replacingOccurrences(of: " ", with: "")
        
        if (chord.hasPrefix("6") || chord.hasPrefix("#6") || chord.hasPrefix("7")) {
            chord = "'" + chord
        }
        
        return chord
    }
    
    //--------------------------------------------------------------------------------------------------
    // Returns the notes of a chord.
    //  - The chord is reduced, if the requested notes count is lower than the number of chord notes.
    //  - The chord is augmented, if the requested notes count is higher than the number of chord notes.
    //  - The chord's soot is returned, if the notes count is -1
    //--------------------------------------------------------------------------------------------------
    func find(name: String, notesCount: Int) -> String {
        
        var chord = get(name: name)
        if (chord != "")
        {
            if (notesCount == -1) {
                // return the chord's root
                chord = name
                if (chord.hasPrefix("'")) {
                    chord = String(chord.dropFirst())
                }
                chord = String(chord.first!)
                
            }
            else {
                let notes = chord.split(separator: " ")
                
                if (notesCount == 1) {
                    chord = String(notes[0])
                }
                else if (notesCount == 2) {
                    chord = String(notes[0] + notes[1])
                }
                else if (notesCount == 3) {
                    chord = String(notes[0] + notes[1] + notes[2])
                }
                else if (notesCount == 4) {
                    chord = String(notes[0] + notes[1] + notes[2] + notes[notes.count == 4 ? 3 : 0])
                }
                else if (notesCount == 5) {
                    chord = String(notes[0] + notes[1] + notes[2] + notes[notes.count == 4 ? 3 : 0]  + notes[notes.count == 4 ? 0 : 1])
                }
            }
            
            if (chord.hasPrefix("6") || chord.hasPrefix("#6") || chord.hasPrefix("7")) {
                chord = "'" + chord
            }
        }
        
        return chord
    }
    
    //-----------------------------------------------------------------------------------
    // Get the notes of the requested chord.
    //  - If the requested chord is prefixed by a quote, the lower inversion is returned
    //  - If the requested chord is suffixed by a quote, the higher inversion is returned
    // The function return a list of notes separated by spaces (as a string)
    //-----------------------------------------------------------------------------------
    private func get(name: String) -> String {
        var chordName = name
        var lowerInversion = false
        var higherInversion = false
        
        if (chordName.hasPrefix("'")) {
            lowerInversion = true
            chordName = String(chordName.dropFirst())
        }
        else if (chordName.hasSuffix("'")) {
            higherInversion = true
            chordName = String(chordName.dropLast())
        }
        
        var chord = map[chordName] ?? ""
        
        if (chord != "" && (lowerInversion || higherInversion))
        {
            let notes = chord.split(separator: " ")
             
            if (lowerInversion && notes.count == 3) {
                chord = String(notes[2] + " " + notes[0] + " " + notes[1])
            }
            else if (lowerInversion && notes.count == 4) {
                chord = String(notes[3] + " " + notes[0] + " " + notes[1] + " " + notes[2])
            }
            else if (higherInversion && notes.count == 3) {
                chord = String(notes[1] + " " + notes[2] + " " + notes[0])
            }
            else if (higherInversion && notes.count == 4) {
                chord = String(notes[1] + " " + notes[2] + " " + notes[3] + " " + notes[0])
            }
        }
        
        return chord
    }

}
