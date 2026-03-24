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
            undoStack.append(old)
        }

        undoStack.append(new)
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
            undoStack.append(old)
        }
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
                redoStack.append(currentText)
            }
            
            text = undoStack.removeLast()
            
            while (text == currentText && undoStack.count > 0) {
                text = undoStack.removeLast()
            }
            
            redoStack.append(text)
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
                undoStack.append(currentText)
            }
            
            text = redoStack.removeLast()
            
            while (text == currentText && redoStack.count > 0) {
                text = redoStack.removeLast()
            }
            
            undoStack.append(text)
        }

        return text
    }
}
