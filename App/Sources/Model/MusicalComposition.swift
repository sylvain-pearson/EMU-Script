//
//  MusicalComposition.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation

// ----------------------------------------------------------------------------------
// A musical composition has many properties, including a list of musical sections
// ----------------------------------------------------------------------------------
struct MusicalComposition {
    
    var name: String
    var autor: String
    var timeSignature: String
    var BPM: UInt8
    var beatsPerMeasure: Int
    var stepsPerBeat: Int
    var transposition: Int8
    var sections: [MusicalSection] = [ ]
    
    // -----------------------------------
    // The default structure initializer
    // -----------------------------------
    init() {
        self.name = ""
        self.autor = ""
        self.timeSignature = "4/4"
        self.BPM = 120
        self.beatsPerMeasure = 4
        self.stepsPerBeat = 4
        self.transposition = 0
    }
    
    // -----------------------------------
    // Return the length of a section
    // -----------------------------------
    func getSectionLength(name: String) -> Int {
        for section in sections {
            if (section.name == name) {
                return section.getLength()
            }
        }
        return 0
    }
    
    // --------------------------------------
    // Return the requested musical section
    // --------------------------------------
    func getSection(name: String) -> MusicalSection {
        for section in sections {
            if (section.name == name) {
                return section
            }
        }
        return MusicalSection(name: "Error", length: 1)
    }
    
    // -------------------------------------------
    // Set the time signature of the composition
    // -------------------------------------------
    mutating func setTimeSignature(_ signature: String) -> Bool {
        var isOk = true
        
        timeSignature = signature
        
        switch (signature) {
        case "2/4":
            self.beatsPerMeasure = 2
            self.stepsPerBeat = 12
        case "3/4":
            self.beatsPerMeasure = 3
            self.stepsPerBeat = 12
        case "4/4":
            self.beatsPerMeasure = 4
            self.stepsPerBeat = 12
        case "5/4":
            self.beatsPerMeasure = 5
            self.stepsPerBeat = 12
        case "5/8":
            self.beatsPerMeasure = 5
            self.stepsPerBeat = 6
        case "6/8":
            self.beatsPerMeasure = 6
            self.stepsPerBeat = 6
        case "7/8":
            self.beatsPerMeasure = 7
            self.stepsPerBeat = 6
        default:
            isOk = false
            timeSignature = "4/4"
        }
        return isOk  
    }
    
    // ---------------------------------------------------------------------
    // Return the composition properties, in a format suitable for display
    // ---------------------------------------------------------------------
    func getProperties() -> Properties {
        var properties: Properties = Properties(text: String(localized: "Composition"))
        
        properties.items.append(PropertyInfo(value: self.name))
        properties.items.append(PropertyInfo(value: String(localized: "by ") + self.autor))
        properties.items.append(PropertyInfo(name: String(localized: "BPM"), value: self.BPM.description))
        properties.items.append(PropertyInfo(name: String(localized: "Time Signature"), value: self.timeSignature))
        properties.items.append(PropertyInfo(name: String(localized: "Transposition"), value: self.transposition.description))
        
        return properties
    }
}
