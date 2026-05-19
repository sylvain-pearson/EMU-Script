//
//  ScriptEditor.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation
import SwiftUI

//--------------------------------------------------------
// A script editor with syntax highlighting and undo/redo
//--------------------------------------------------------
struct ScriptEditor : View {
    
    @Binding var document: EmuScriptDocument
    @Binding var reload : Int
    
    @State var selection = AttributedTextSelection()
    @State var text: AttributedString = AttributedString("")
    @State var keyPressed : Character?
    @State var isEdited = false
    @State var undoManager = UndoManager()
    @State var lastUpdate = Date.now
    
    var body: some View {
        
        TextEditor(text: $text, selection: $selection).font(.system(size: 16)).monospaced()
            .onAppear() {
                if (text.characters.count == 0) {
                    text = document.onUpdate(document.textDocument)
                }
            }
            .onKeyPress(action: { press in
                if (press.modifiers.isEmpty || press.modifiers == .shift) {
                    if (isEdited == false && undoManager.canUndo() == false) {
                        // Push the initial text
                        undoManager.push(old: document.textDocument)
                    }
                    else if (isEdited && lastUpdate.distance(to: Date.now) > TimeInterval(4)) {
                        // Last text update has been done at least 5 seconds ago, push it on the undo stack
                        undoManager.push(old: document.textDocument, new: document.updatedDocument)
                    }
                    isEdited = true
                    keyPressed = press.characters.first
                    lastUpdate = Date.now
                }
                return .ignored
            }
            )
            .onChange(of: text) { oldValue, newValue in
                if (keyPressed != nil) {
                    let reloadDocument = (keyPressed != nil && keyPressed! == "\r")
                    if (reloadDocument) {
                        undoManager.push(old: document.textDocument, new: String(newValue.characters))
                        reload += 1
                        isEdited = false
                    }
                    text = document.onUpdate(String(newValue.characters), reload: reloadDocument)
                    keyPressed = nil
                }
                else {
                    let diff = (document.updatedDocument.count - newValue.characters.count)
                    if (diff > 5 || diff < -5) {
                        if (newValue != "" && undoManager.contains(String(newValue.characters)) == false) {
                            // A cut or paste operation has been performed
                            undoManager.push(old: String(oldValue.characters), new: String(newValue.characters))
                            isEdited = true
                        }
                    }
                    text = document.onUpdate(String(newValue.characters))
                }
        }
        .onChange(of: reload) {
            text = document.onUpdate(document.updatedDocument)
        }
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                Spacer()
                
                Button { undo() }
                label: { Image(systemName: "arrow.uturn.left") }
                    .keyboardShortcut("z", modifiers: [.command]).disabled(undoManager.canUndo() == false)
                
                Button { redo() }
                label: { Image(systemName: "arrow.uturn.right") }
                    .keyboardShortcut("z", modifiers: [.command, .shift]) .disabled(undoManager.canRedo() == false)
                
                Button() { validate() }
                label: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(getStatusColor()) }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
        }
    }
    
    //------------------------------------------------------------------
    // Return the color yellow if there is an error, and gray otherwise
    //------------------------------------------------------------------
    func getStatusColor() -> Color {
        if (document.parser.errors.count > 0) {
            return .yellow
        }
        else {
            return .gray
        }
    }
    
    //--------------------------------------------------------------------
    // Check if there is any error in the script and refresh the display
    //--------------------------------------------------------------------
    func validate() {
        undoManager.push(old: document.textDocument, new: document.updatedDocument)
        text = document.onUpdate(String(text.characters), reload: true)
        reload += 1
        isEdited = false
    }
    
    //-----------------------
    // Undo the last change
    //-----------------------
    func undo() {
        if (undoManager.canUndo()) {
            text = document.onUpdate(undoManager.undo(document.updatedDocument))
            isEdited = false
        }
    }
    
    //-----------------------
    // Cancel the last undo
    //-----------------------
    func redo() {
        if (undoManager.canRedo()) {
            text = document.onUpdate(undoManager.redo(document.updatedDocument))
            isEdited = false
        }
    }
}
