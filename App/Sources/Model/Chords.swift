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
        
        // Diatonic triads : C, Dm, Em, F, G, Am, B°
        map["C"]  = "1 3 5"
        map["Dm"] = "2 4 6"
        map["Em"] = "3 5 7"
        map["F"]  = "4 6 1"
        map["G"]  = "5 7 2"
        map["Am"] = "6 1 3"
        map["Bdim"] = "7 2 4"
        
        // Chromatic major and minor triads : Cm, D, E, Fm, Gm, A, Bm, B
        map["Cm"] = "1 #2 5"
        map["D"]  = "2 #4 6"
        map["E"]  = "3 #5 7"
        map["Fm"] = "4 #5 1"
        map["Gm"] = "5 #6 2"
        map["A"]  = "6 #1 3"
        map["Bm"] = "7 2 #4"
        map["B"]  = "7 #2 #4"
        
        // Chromatic diminished triads : C°, D°, E°, F°, G°, A°
        map["Cdim"] = "1 #2 #4"
        map["Ddim"] = "2 4 #5"
        map["Edim"] = "3 5 #6"
        map["Fdim"] = "4 #5 7"
        map["Gdim"] = "5 #6 #1"
        map["Adim"] = "6 1 #2"
        
        // Chromatic augmented triads : C+, D+, E+°, F+, G+, A+, B+
        map["Caug"] = "1 3 #5"
        map["Daug"] = "2 #4 #6"
        map["Eaug"] = "3 #5 1"
        map["Faug"] = "4 6 #1"
        map["Gaug"] = "5 7 #2"
        map["Aaug"] = "6 #1 4"
        map["Baug"] = "7 #2 5"
        
        // Diatonic seventh chords : CM7, Dm7, Em7, FM7, G7, Am7, Bø7
        map["CM7"] = "1 3 5 7"
        map["Dm7"] = "2 4 6 1"
        map["Em7"] = "3 5 7 2"
        map["FM7"] = "4 6 1 3"
        map["G7"]  = "5 7 2 4"
        map["Am7"] = "6 1 3 5"
        map["Bdim7"] = "7 2 4 6"
        
        // Chromatic dominant sevenths chords : C7, D7, E7, F7, A7, B7
        map["C7"] = "1 3 5 #6"
        map["D7"] = "2 #4 6 1"
        map["E7"] = "3 #5 7 2"
        map["F7"] = "4 6 1 #2"
        map["A7"] = "6 #1 3 5"
        map["B7"] = "7 #2 #4 6"

        // Chromatic major sevenths chords : DM7, EM7, GM7, AM7, BM7
        map["DM7"] = "2 4 6 #1"
        map["EM7"] = "3 5 7 #2"
        map["GM7"] = "5 7 2 #4"
        map["AM7"] = "6 1 3 #5"
        map["BM7"] = "7 2 4 #6"

        // Chromatic minor sevenths chords : Cm7, Fm7, Gm7, Bm7
        map["Cm7"] = "1 #2 5 #6"
        map["Fm7"] = "4 #5 1 #2"
        map["Gm7"] = "5 #6 2 4"
        map["Bm7"] = "7 2 #4 6"
        
        // Chromatic diminished sevenths chords : , C°7, D°7, E°7, F°7, G°7, A°7
        map["Cdim7"] = "1 #2 #4 6"
        map["Ddim7"] = "2 4 #5 7"
        map["Edim7"] = "3 5 #6 #1"
        map["Fdim7"] = "4 #5 7 2"
        map["Gdim7"] = "5 #6 #1 3"
        map["Adim7"] = "6 1 #2 #4"
        
        // Major chords synonyms
        map["AM"]  = map["A"]
        map["BM"]  = map["B"]
        map["CM"]  = map["C"]
        map["DM"]  = map["D"]
        map["EM"]  = map["E"]
        map["FM"]  = map["F"]
        map["GM"]  = map["G"]
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
            if (notesCount < 1) {
                // return the chord's root
                chord = name
                if (chord.hasPrefix("'")) {
                    chord = String(chord.dropFirst())
                }
                chord = String(chord.first!)
                
            }
            else {
                // Return the requested count of notes
                
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
                else if (notesCount >= 5) {
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
