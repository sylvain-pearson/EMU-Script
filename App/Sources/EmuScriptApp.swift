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
#if os(macOS)
        .commands {
            CommandGroup(replacing: .help) {
                Link("Online User Manual", destination: URL(string: "https://sylvain-pearson.github.io/EMU-Script/Doc/User-Manual.html")!)
                Link("Online Reference Manual", destination: URL(string: "https://sylvain-pearson.github.io/EMU-Script/Doc/Reference-Manual.html")!)
            }
        }
#endif
    }
}
