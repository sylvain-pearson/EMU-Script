//
//  EmuScriptApp.swift
//  EmuScript
//
//  Created by Sylvain Pearson on 2026-01-07.
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
