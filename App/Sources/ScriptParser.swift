//
//  ScriptParser.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import SwiftUI

enum TokenType: String {
    case undefined
    case number
    case comment
    case keyword
    case reserved
    case text
}

//----------------------------------------------------
// A line of text having a key part and a value part
//----------------------------------------------------
public class TextLine {
    
    private(set) var key: String
    private(set) var value: String
    private(set) var lineNumber: UInt16
    private(set) var error: ScriptError
    
    //--------------------------
    // Initialize a text line
    //--------------------------
    init(key: String, value: String, lineNumber: UInt16) {
        self.key = key
        self.value = value
        self.lineNumber = lineNumber
        
        if (self.key.wholeMatch(of: /[\/][a-zA-Z][a-zA-Z0-9_\.\-\/]+/) != nil) {
            // the key is a path
            self.error = ScriptError()
        }
        else if (self.key.wholeMatch(of: /[a-zA-Z][a-zA-Z0-9_\-]+/) != nil) {
            // the key is a keyword
            self.error = ScriptError()
        }
        else {
            // regex verification failed
            self.error = ScriptError(code: .invalidKey, info: self.key, lineNumber: self.lineNumber)
        }
    }
    
    //-------------------------------------
    // Get the key as an array of strings
    //-------------------------------------
    func getPath() -> [String] {
        return key.split(separator: "/").map(String.init)
    }
    
    //------------------------------------
    // Get the value an array of strings
    //------------------------------------
    func getValues(separator: Character) -> [String] {
        return value.split(separator: separator).map(String.init)
    }
}

//----------------------------------------------------
// A script section is a list of text lines
//----------------------------------------------------
public class ScriptSection {
    
    private(set) var name: String
    private(set) var lineNumber: UInt16
    private(set) var error: ScriptError
    private(set) var textLines: [TextLine]
    
    //------------------------------
    // Initialize a script section
    //------------------------------
    init(name: String, lineNumber: UInt16) {
        self.name = name
        self.lineNumber = lineNumber
        self.textLines = []
        
        if (self.name.wholeMatch(of: /[a-zA-Z][a-zA-Z0-9-_]*/) != nil) {
            // Section name format is ok
            self.error = ScriptError()
        }
        else {
            // regex verification failed
            self.error = ScriptError(code: .invalidSectionName, info: self.name, lineNumber: self.lineNumber)
        }
    }

    //---------------------------------------------------------
    // Move the requested text line at the top of the section
    //---------------------------------------------------------
    func moveLineFirst(key: String) {
        var orderedTextLines: [TextLine] = []
        
        for line in self.textLines {
            if (line.key == key) {
                orderedTextLines.append(line)
            }
        }
        for line in self.textLines {
            if (line.key != key) {
                orderedTextLines.append(line)
            }
        }
        self.textLines = orderedTextLines
    }
 
    //-------------------------------------------------
    // Return the line number of a specific text line
    //-------------------------------------------------
    func getLineNumber(key: String) -> UInt16 {
        for line in self.textLines {
            if (line.key == key) {
                return line.lineNumber
            }
        }
        return 0
    }
  
    //-----------------------------------------------
    // Append a text line to the end of the section
    //-----------------------------------------------
    fileprivate func append(_ textLine: TextLine) {
        textLines.append(textLine)
    }
}


//-----------------------------------------------------------------------------------
// This class can parse a text document containing [sections] with key:value pairs
//  - Section headers are enclosed within square braquets
//  - Keys and values are separated by the colon character
//  - A value can span over multiple lines
//  - Comments are prefixed by double slashes
//-----------------------------------------------------------------------------------
public class ScriptParser {
    
    private(set) var sections: [ScriptSection]
    private(set) var errors : [ScriptError]
    private(set) var errorLines : Set<UInt16>
    
    //--------------------------------
    // The default class initializer
    //--------------------------------
    init() {
        self.sections = []
        self.errors = []
        self.errorLines = []
    }
    
    //------------------------------
    // Parse the provided document
    //------------------------------
    func parse(_ textDocument: String) {

        let lines = textDocument.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var lineNumber : UInt16 = 0
        var section : ScriptSection? = nil
        var key = ""
        
        self.sections = []
        self.errors = []
        self.errorLines = []
        
        for var line in lines {
            
            line = line.trimmingCharacters(in: .whitespaces)
            lineNumber += 1
            
            if (line.hasPrefix("//")) {
                // Ignore comment line
                line = ""
            }
            else if (line.contains("//")) {
                line = String(line.split(separator: "//").first!)   // Remove any comment at the end of the line
            }

            if (line.hasPrefix("[") && line.hasSuffix("]")) {
                if section != nil {
                    self.sections.append(section!)
                    if (section!.error.isErr()) {
                        error(section!.error)
                    }
                }
                var sectionName = String(line.split(separator: "]").first!.split(separator: "[").last!)
                sectionName = sectionName.trimmingCharacters(in: .whitespaces)
                section = ScriptSection(name: sectionName, lineNumber: lineNumber)
                key = ""
                
                // Initialize with parent section lines, if any
                if (sectionName.count > 1 && sectionName.last!.isNumber) {
                    let parentSectionName = String(sectionName.prefix(sectionName.count - 1))
                    if let parentSection = getSection(name: parentSectionName) {
                        for line in parentSection.textLines {
                            section!.append(line)
                        }
                    }
                }
            }
            else if (section != nil && line.contains(":")) {
                key = String(line.split(separator: ":").first!).trimmingCharacters(in: .whitespaces)
                let value = String((line.split(separator: ":").last!).split(separator: "//").first!).trimmingCharacters(in: .whitespaces)
                let textLine = TextLine(key: key, value: value, lineNumber: lineNumber)
                section!.append(textLine)
                if (textLine.error.isErr()) {
                    error(textLine.error)
                }
            }
            else if (section != nil && line != "" && key != "") {
                let textLine = TextLine(key: key, value: line, lineNumber: lineNumber)
                section!.append(textLine)
                if (textLine.error.isErr()) {
                    error(textLine.error)
                }
            }
            else if (line != "") {
                error(.unexpectedTextOutsideSection, info: line, at: lineNumber)
            }
        }
        
        if let newSection = section {
            self.sections.append(newSection)
            if (newSection.error.isErr()) {
                error(newSection.error)
            }
        }
    }
    
    //------------------------------------
    // Add a new error to the error list
    //------------------------------------
    func error(_ code: ScriptErrorCode, info: String, at: UInt16 = 0) {
        let err = ScriptError(code: code, info: info, lineNumber: at)
        self.errors.append(err)
        self.errorLines.insert(at)
    }
    
    //---------------------------------
    // Add an error to the error list
    //---------------------------------
    func error(_ err: ScriptError) {
        let err = ScriptError(code: err.code, info: err.info, lineNumber: err.lineNumber)
        self.errors.append(err)
        self.errorLines.insert(err.lineNumber)
    }

    //----------------------------
    // Get the requested section
    //----------------------------
    func getSection(name: String) -> ScriptSection? {
        for section in self.sections {
            if (section.name == name) {
                return section
            }
        }
        return nil
    }
    
    //----------------------------------
    // Get the text lines of a section
    //----------------------------------
    func getTextLines(sectioName: String) -> [TextLine] {
        
        var textLines: [TextLine] = []

        if (sectioName.count > 1 && sectioName.last!.isNumber) {
            let parentSectionName = String(sectioName.prefix(sectioName.count - 1))
            if let parentSection = getSection(name: parentSectionName) {
                textLines.append(contentsOf: parentSection.textLines)
            }
        }

        if let section = getSection(name: sectioName) {
            textLines.append(contentsOf: section.textLines)
        }
        
        return textLines
    }
    
    //-------------------------------------------------
    // Get the line number of a specific line of text
    //-------------------------------------------------
    func getLineNumber(sectionName: String, lineKey: String) -> UInt16 {
        if let section = getSection(name: sectionName) {
            return section.getLineNumber(key: lineKey)
        } else {
            return 0
        }
    }
    
    //-----------------------------------------------------------------------------------
    // Split a string into a list of tokens.
    // The tokens separators are: whitespace, parenthesis, curly braces, square brakets
    //------------------------------------------------------------------------------------
    func tokenise(text: String) -> [String] {
        
        var textList: [String] = []
        var token = ""
        
        for char in text {
            if (char.isWhitespace) {
                if (!token.isEmpty) {
                    textList.append(token)
                    token = ""
                }
            }
            else if (char == "(" || char == ")" || char == "[" || char == "]" || char == "{" || char == "}") {
                if (!token.isEmpty) {
                    textList.append(token)
                }
                textList.append(String(char))
                token = ""
            }
            else {
                token.append(String(char))
            }
        }
        
        if (!token.isEmpty) {
            textList.append(token)
        }
        
        return textList
    }
    
    //-------------------------------------
    // Add syntax highligting to a script
    //-------------------------------------
    func highlightText(_ text: String) -> AttributedString {
        
        var word = ""
        var last: Character = " "
        var wordType = TokenType.undefined
        var richText = AttributedString()
        var textLine = AttributedString()
        var lineNumber : UInt16 = 1
        
        for c in text + (text.hasSuffix("\n") ? "" : "\n") {
            if (c == "\"" && wordType == .undefined) {
                textLine += AttributedString(String(c))
                wordType = .text
            }
            else if (wordType == .text && c != "\""  && c != "\n") {
                word += String(c)
            }
            else if (wordType == .comment && c != "\n") {
                word += String(c)
            }
            else if (c == "/" && last == "/") {
                textLine += AttributedString(String(c))
                wordType = .comment
            }
            else if (((c == "$" || c == "@") && wordType == .undefined) || (c.isNumber && wordType == .reserved)) {
                word += String(c)
                wordType = .reserved
            }
            else if (wordType == .number && (c == "M" || c == "m" || c == "d" || c == "D" || c == "a")) {
                word += String(c)
                wordType = .reserved
            }
            else if (c.isNumber && wordType != .keyword) {
                word += String(c)
                wordType = .number
            }
            else if (c.isLetter || c.isNumber || (c == "-" && wordType == .keyword) ||  (c == "_" && wordType == .keyword)) {
                word += String(c)
                wordType = .keyword
            }
            else {
                if (!word.isEmpty || wordType == .text) {
                    var highligthedWord = AttributedString(word)
 
                    if (wordType == .comment) {
                        highligthedWord.foregroundColor = .gray
                    }
                    else if (wordType == .text) {
                        highligthedWord.foregroundColor = Color(hue: 0.3, saturation: 1, brightness: 0.65)
                    }
                    else if (wordType == .number) {
                        highligthedWord.foregroundColor = Color(hue: 0.07, saturation: 1, brightness: 0.6)
                    }
                    else if (wordType == .reserved) {
                        highligthedWord.foregroundColor = Color(hue: 0.3, saturation: 1, brightness: 0.5)
                    }
                    else {
                        highligthedWord.foregroundColor = .black
                        if (c == "]") {
                            highligthedWord.foregroundColor = Color(hue: 0.9, saturation: 1, brightness: 0.8)
                        }
                        else if (c == ":") {
                            highligthedWord.foregroundColor = Color(hue: 0.65, saturation: 1, brightness: 0.8)
                        }
                    }
                    
                    textLine += highligthedWord
                    word = ""
                    wordType = .undefined
                }
                
                if (c == "\t") {
                    textLine += AttributedString(String("   "))
                }
                else {
                    textLine += AttributedString(String(c))
                }
            }
            
            if (c == "\n") {
                if (errorLines.contains(lineNumber)) {
                    textLine.backgroundColor = Color(hue: 0.15, saturation: 0.3, brightness: 1)
                }
                richText.append(textLine)
                textLine = ""
                lineNumber += 1
            }
            last = c
        }
        
        return richText
    }

}
