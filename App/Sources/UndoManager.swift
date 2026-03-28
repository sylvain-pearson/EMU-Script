//
//  UndoManager.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

class UndoManager
{
    private var undoStack: [String] = []
    private var redoStack: [String] = []
    
    //----------------------------------------
    // Push a change on top of the undo stack
    //----------------------------------------
    func push(old: String, new: String) {

        if (undoStack.isEmpty) {
            pushToUndoStack(old)
        }
        
        pushToUndoStack(new)
        redoStack.removeAll()
        
        if (undoStack.count > 20) {
            undoStack.removeFirst()
        }
    }
    
    //------------------------
    // Push the initial text
    //------------------------
    func push(old: String) {
        if (undoStack.isEmpty) {
            pushToUndoStack(old)
        }
    }
    
    //----------------------------------------------------------------------------------
    // Check if the top of the undo stack (or redo stack) contains the provided string
    //----------------------------------------------------------------------------------
    func contains(_ text : String) -> Bool {
        var contain = false
        if (undoStack.isEmpty == false && undoStack.last! == text) {
            contain = true
        }
        else if (redoStack.isEmpty == false && redoStack.last! == text) {
            contain = true
        }
        return contain
    }
    
    //--------------------------------------------------------
    // Return true, if it is possible to undo the last change
    //--------------------------------------------------------
    func canUndo() -> Bool {
        return (undoStack.count > 0)
    }
    
    //--------------------------------------------------------
    // Return true, if it is possible to redo the last undo
    //--------------------------------------------------------
    func canRedo() -> Bool {
        return (redoStack.count > 0)
    }
    
    //----------------------------------------------------------
    // Remove the string on top of the undo stack and return it
    //----------------------------------------------------------
    func undo(_ currentText : String) -> String {
        var text = ""

        if (undoStack.count > 0) {
            
            if (redoStack.count == 0) {
                pushToRedoStack(currentText)
            }
            
            text = undoStack.removeLast()
            
            while (text == currentText && undoStack.count > 0) {
                text = undoStack.removeLast()
            }
            
            pushToRedoStack(text)
        }

        return text
    }
    
    //----------------------------------------------------------
    // Remove the string on top of the redo stack and return it
    //----------------------------------------------------------
    func redo(_ currentText : String) -> String {
        var text = ""

        if (redoStack.count > 0) {
            
            if (undoStack.count == 0) {
                pushToUndoStack(currentText)
            }
            
            text = redoStack.removeLast()
            
            while (text == currentText && redoStack.count > 0) {
                text = redoStack.removeLast()
            }
            
            pushToUndoStack(text)
        }

        return text
    }
    
    private func pushToUndoStack(_ text: String) {
        if (undoStack.count == 0 || undoStack.last! != text) {
            undoStack.append(text)
        }
    }
    
    private func pushToRedoStack(_ text: String) {
        if (redoStack.count == 0 || redoStack.last! != text) {
            redoStack.append(text)
        }
    }
}
