//
//  ScriptError.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import UniformTypeIdentifiers

enum ScriptErrorCode {
    case ok
    case midiError
    case fileNotFound
    case MissingSection
    case UndefinedSection
    case invalidEndpoint
    case invalidNote
    case invalidKeyword
    case invalidDrum
    case invalidChord
    case InvalidTransposition
    case noteIsTooLow
    case noteIsTooHigh
    case unsupportedTimeSignature
    case syntaxError
    case ccSyntaxError
    case unexpectedKeyword
    case invalidKey
    case invalidSectionName
    case unexpectedTextOutsideSection
}

// --------------------------------
// A script error
// --------------------------------
struct ScriptError : Identifiable {
    
    var code: ScriptErrorCode
    var info: String
    var lineNumber : UInt16
    let id = UUID()
    
    init() {
        self.code = .ok
        self.info = ""
        self.lineNumber = 0
    }
    
    init(code: ScriptErrorCode, info: String, lineNumber: UInt16 = 0) {
        self.code = code
        self.info = info
        self.lineNumber = lineNumber
    }
    
    func isOk() -> Bool {
        return (self.code == .ok)
    }
    
    func isErr() -> Bool {
        return (self.code != .ok)
    }
    
    func getMessageAndLineNumber() -> String {
        var message = getMessage()
        if (self.lineNumber > 0) {
            message += String(localized: " (Error at line \(self.lineNumber))")
        }
        return message
    }
    
    func getMessage() -> String {
        var message: String = ""
        
        switch code {
        case .fileNotFound:
            message = String(localized: "Cannot open file: '\(info)'")
        case .MissingSection:
            message = String(localized: "The section '\(info)' is mandatory and cannot be found")
        case .UndefinedSection:
            message = String(localized: "The section '\(info)' cannot be found")
        case .invalidEndpoint:
            message = String(localized: "Failed to open the MIDI enpoint: '\(info)'")
        case .unexpectedKeyword:
            message = String(localized: "Unexpected keyword: '\(info)'")
        case .unsupportedTimeSignature:
            message = String(localized: "Unsupported time signature: '\(info)'")
        case .InvalidTransposition:
            message = String(localized: "Unsupported transposition: '\(info)'")
        case .invalidSectionName:
            message = String(localized: "The section name '\(info)' has an invalid syntax")
        case .invalidKey:
            message = String(localized: "The key name '\(info)' has an invalid syntax")
        case .invalidNote:
            message = String(localized: "Invalid note: '\(info)'")
        case .noteIsTooHigh:
            message = String(localized: "Note is too high: '\(info)'")
        case .noteIsTooLow:
            message = String(localized: "Note is too low: '\(info)'")
        case .invalidDrum:
            message = String(localized: "Invalid drum note: '\(info)'")
        case .invalidKeyword:
            message = String(localized: "Invalid keyword: '\(info)'")
        case .invalidChord:
            message = String(localized: "Invalid chord: '\(info)'")
        case .syntaxError:
            message = String(localized: "Syntax error at: '\(info)'")
        case .ccSyntaxError:
            message = String(localized: "Expected a CC name=number pair")
        default :
            message = String(localized: "Unexpected error")
        }
        
        return message
    }
}
