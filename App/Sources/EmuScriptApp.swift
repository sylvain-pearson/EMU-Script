//
//  EmuScriptApp.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import SwiftUI

@main
struct EmuScriptApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: EmuScriptDocument()) { file in
            ContentView(document: file.$document)
        }
    }
        
}
