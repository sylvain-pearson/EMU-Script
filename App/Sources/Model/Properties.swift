//
//  Properties.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import UniformTypeIdentifiers

// ----------------------------------------------------------------
// A property than can be a "key: value" pair or just a value
// ----------------------------------------------------------------
struct PropertyInfo : Identifiable {
    
    let id = UUID()
    var name : String
    var value : String
    var separator : String
  
    init(name: String, value: String) {
        self.name = name
        self.value = value
        self.separator = ": "
    }
    
    init(value: String) {
        self.name = ""
        self.value = value
        self.separator = ""
    }
}

// -----------------------------------
// A collection of properties
// -----------------------------------
struct Properties {
    var text: String = ""
    var isSelection = false
    var items: [PropertyInfo] = []
}
