//
//  ScriptEditor.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation
import SwiftUI

struct ScriptEditor : View {
    
    @Binding var document: EmuScriptDocument
    @Binding var reload : Int
    
    @State var selection = AttributedTextSelection()
    @State var text: AttributedString = AttributedString("")
    @State var keyPressed : Character?
        
    var body: some View {
        
        TextEditor(text: $text, selection: $selection).font(.system(size: 16)).monospaced()
            .onAppear() {
                if (text.characters.count == 0) {
                    text = document.onUpdate(document.textDocument)
                }
            }
            .onKeyPress(action: { press in
                keyPressed = press.characters.first
                return .ignored
            }

        )
        .onChange(of: text) { oldValue, newValue in
            if (keyPressed != nil) {
                text = document.onUpdate(String(newValue.characters), reload: keyPressed! == "\r")
                // onUpdate() triggers another call to onChange(). The next call will be ignored
                keyPressed = nil
            }
            else {
                keyPressed = " "
            }
        }
        .onChange(of: reload) {
            text = document.onUpdate(document.textDocument)
        }
    }
}
