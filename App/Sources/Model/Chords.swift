//
//  Chords.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation

struct Chords {
        
    //--------------------------------------------------------------------------------------------------
    // Returns the notes of a chord, as a string
    //  - The chord is reduced, if the requested notes count is lower than the number of chord notes.
    //  - The chord is augmented, if the requested notes count is higher than the number of chord notes.
    //  - If the notes count is 0, all chord notes are returned
    //--------------------------------------------------------------------------------------------------
    func get(_ text: String, notesCount: Int = 0) -> String {
        
        let notes = getChordNotes(text)
        var result = ""
        var n = 0
        
        for note in notes.prefix(notesCount == 0 ? notes.count : notesCount) {
            result += note
            n += 1
        }
        
        // Expand chord, if required
        if (n < notesCount) {
            for note in notes.prefix(notesCount) {
                if (n < notesCount) {
                    result += note
                    n += 1
                }
                else {
                    break
                }
            }
        }
        
        if (result.isEmpty == false) {
            if (text.hasPrefix("'")) {
                result = "'" + result
            }
            else if (text.hasSuffix("'")) {
                result = result + "'"
            }
        }
        
        return result
    }
    
    //---------------------------------
    // Check if a note is in a chord
    //---------------------------------
    func isChordNote(chord: String, note: String) -> Bool {
        let notes = getChordNotes(toNoteNumber(chord))
        return notes.contains(toNoteNumber(note))
    }
    
    //---------------------------------
    // Get a chord's root note
    //---------------------------------
    func getChordRoot(_ text: String) -> String {
        var root = ""
        
        let chord = trim(text)
        
        if let i = chord.firstIndex(of: "(") {
            if chord.hasSuffix(")") {
                let notes = chord.suffix(from: i).dropLast().dropFirst().split(separator: ",")
                root = String(notes[0])
            }
        }
        
        return root
    }
    
    //---------------------------------
    // Get a chord's bass note
    //---------------------------------
    func getChordBass(_ text: String) -> String {
        var bass = ""
        
        let chord = trim(text)
        
        if let i = chord.firstIndex(of: "(") {
            if chord.hasSuffix(")") {
                let notes = chord.suffix(from: i).dropLast().dropFirst().split(separator: ",")
                bass = String(notes[0])
                if notes.count > 1 {
                    bass = String(notes[1])
                }
            }
        }
        
        if (bass.isEmpty == false) {
            if (text.hasPrefix("'")) {
                bass = "'" + bass
            }
            else if (text.hasSuffix("'")) {
                bass = bass + "'"
            }
        }
        
        return bass
    }
    
    //-----------------------------------------------------------------------------------
    // Get the notes of the requested chord.The chords formats are:
    //  - name(root)        -> examples: maj(1), min(A)
    //  - name-ext(root)    -> examples: dim-min(7)
    //  - name(root,bass)   -" examples: maj(F,G), min(3,6)
    // The function return an array of notes
    //-----------------------------------------------------------------------------------
    func getChordNotes(_ text: String) -> [String] {
        var name = ""
        var root = ""
        var ext = ""
        var bass = ""
        
        let chord = trim(text)
        
        if let i = chord.firstIndex(of: "(") {
            name = String(chord.prefix(upTo: i))
            
            let name_ext = name.split(separator: "-")
            if (name_ext.count > 0) {
                name = String(name_ext[0])
            }
            if (name_ext.count > 1) {
                ext = String(name_ext[1])
            }
            
            if chord.hasSuffix(")") {
                let notes = chord.suffix(from: i).dropLast().dropFirst().split(separator: ",")
                root = String(notes[0])
                
                if notes.count > 1 {
                    bass = String(notes[1])
                }
            }
        }
        
        if (name.isEmpty || root.isEmpty) {
            return []
        }
        else {
            return getChordNotes(name: name, root: root, ext: ext, bass: bass)
        }
    }
    
    //---------------------------------------
    // Get the notes of the requested chord
    //---------------------------------------
    private func getChordNotes(name: String, root: String, ext: String, bass: String = "") -> [String] {
        var notes = [root]
        
        switch name {
        case "maj":
            notes.append(addSemitones(root, 4))
            notes.append(addSemitones(root, 7))
        case "min":
            notes.append(addSemitones(root, 3))
            notes.append(addSemitones(root, 7))
        case "dim":
            notes.append(addSemitones(root, 3))
            notes.append(addSemitones(root, 6))
        case "aug":
            notes.append(addSemitones(root, 4))
            notes.append(addSemitones(root, 8))
        case "sus2":
            notes.append(addSemitones(root, 2))
            notes.append(addSemitones(root, 7))
        case "sus", "sus4":
            notes.append(addSemitones(root, 5))
            notes.append(addSemitones(root, 7))
        case "dom7", "dom9":
            notes.append(addSemitones(root, 4))
            notes.append(addSemitones(root, 7))
            notes.append(addSemitones(root, 10))
        case "maj7", "maj9":
            notes.append(addSemitones(root, 4))
            notes.append(addSemitones(root, 7))
            notes.append(addSemitones(root, 11))
        case "min7", "min9":
            notes.append(addSemitones(root, 3))
            notes.append(addSemitones(root, 7))
            notes.append(addSemitones(root, 10))
        case "dim7", "dim9":
            notes.append(addSemitones(root, 3))
            notes.append(addSemitones(root, 6))
            notes.append(addSemitones(root, 9))
        case "aug7", "aug9":
            notes.append(addSemitones(root, 4))
            notes.append(addSemitones(root, 8))
            notes.append(addSemitones(root, 10))
        case "sus7", "sus9":
            notes.append(addSemitones(root, 5))
            notes.append(addSemitones(root, 7))
            notes.append(addSemitones(root, 10))
        case "maj6":
            notes.append(addSemitones(root, 4))
            notes.append(addSemitones(root, 7))
            notes.append(addSemitones(root, 9))
        case "min6":
            notes.append(addSemitones(root, 3))
            notes.append(addSemitones(root, 7))
            notes.append(addSemitones(root, 9))
        case "m3":
            notes.append(addSemitones(root, 3))     // minor third interval
        case "M3":
            notes.append(addSemitones(root, 4))     // major third interval
        case "P4":
            notes.append(addSemitones(root, 5))     // perfect fourth interval
        case "P5":
            notes.append(addSemitones(root, 7))     // perfect fifth interval
        case "m6":
            notes.append(addSemitones(root, 8))     // minor sixth interval
        case "M6":
            notes.append(addSemitones(root, 9))     // major sixth interval
        default:
            notes.removeAll()
        }
        
        if (name.last == "9") {
            notes.append(addSemitones(root, 2))    // major ninth interval
        }
        else if (ext.isEmpty == false && notes.count > 1) {
            // Handle extensions
            if (ext == "m7") {
                // Add a minor seventh
                notes.append(addSemitones(root, 10))
            }
            else if (ext == "M7") {
                // Add a major seventh
                notes.append(addSemitones(root, 11))
            }
            else if (ext == "m9") {
                // Add a minor ninth
                notes.append(addSemitones(root, 1))
            }
            else if (ext == "M9") {
                // Add a major ninth
                notes.append(addSemitones(root, 2))
            }
            else if (ext != "b5") {
                notes.removeAll()
            }
        }
        
        // flat five chord modifier
        if (ext == "b5"  && notes.count > 1) {
            let fifth = addSemitones(root, 7)
            var found = false
            var i = 0
            for n in notes {
                if (n == fifth) {
                    notes[i] = addSemitones(root, 6)
                    found = true
                    break
                }
                i = i + 1
            }
            if (found == false) {
                notes.removeAll()
            }
        }
        
        if (bass.isEmpty == false) {
            if (notes.contains(bass)) {
                while (notes.first != bass) {
                    notes.append(notes.removeFirst())
                }
            }
            else if (notes.count > 0) {
                notes.insert(bass, at: 0)
            }
        }
        
        return notes
    }
    
    //-------------------------------------------------
    // Add the requested count of semitones to a note
    //-------------------------------------------------
    private func addSemitones(_ note: String, _ count: Int8) -> String {
        var result = note
        
        let notes = [ "1", "#1", "2", "#2", "3", "4", "#4", "5", "#5", "6", "#6", "7" ]
        if let i = notes.firstIndex(of: note) {
            let j = (i + Int(count)) % 12
            result = notes[j]
        }
        else {
            let notes = [ "C", "#C", "D", "#D", "E", "F", "#F", "G", "#G", "A", "#A", "B" ]
            if let i = notes.firstIndex(of: note) {
                let j = (i + Int(count)) % 12
                result = notes[j]
            }
        }
        
        return result
    }
    
    //--------------------------------------------------
    // Convert a standard note (A-G) to a number (1-7)
    //--------------------------------------------------
    private func toNoteNumber(_ note: String) -> String {
        var result = note
        
        result.replace("C", with: "1")
        result.replace("D", with: "2")
        result.replace("E", with: "3")
        result.replace("F", with: "4")
        result.replace("G", with: "5")
        result.replace("A", with: "6")
        result.replace("B", with: "7")
        
        return result
    }
    
    //-------------------------------------------
    // Trim quote prefix and suffix from chord
    //-------------------------------------------
    private func trim(_ text: String) -> String {
        var chord = text
        
        if (chord.hasPrefix("'")) {
            chord = String(chord.dropFirst())
        }
        else if (chord.hasSuffix("'")) {
            chord = String(chord.dropLast())
        }
        return chord
    }
}
