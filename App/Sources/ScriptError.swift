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
    case error
    case midiError
    case fileNotFound
    case missingSection
    case undefinedSection
    case invalidEndpoint
    case invalidNote
    case invalidKeyword
    case invalidDrum
    case invalidChord
    case invalidTransposition
    case invalidCC
    case noteIsTooLow
    case noteIsTooHigh
    case unsupportedTimeSignature
    case parenthesisMismatch
    case squareBracketMismatch
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
    var details: String
    var lineNumber : UInt16
    let id = UUID()
    
    init() {
        self.code = .ok
        self.info = ""
        self.lineNumber = 0
        self.details = ""
    }
    
    init(code: ScriptErrorCode, info: String, lineNumber: UInt16 = 0) {
        self.code = code
        self.info = info
        self.lineNumber = lineNumber
        self.details = ""
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
        case .error:
            message = info
        case .fileNotFound:
            message = String(localized: "Cannot open file: '\(info)'")
        case .missingSection:
            message = String(localized: "The section '\(info)' is mandatory and cannot be found")
        case .undefinedSection:
            message = String(localized: "The section '\(info)' cannot be found")
        case .invalidEndpoint:
            message = String(localized: "Invalid MIDI port: '\(info)'.\nYou can use one of the following ports or create a virtual port using MIDI Studio.\n \(details)")
        case .unexpectedKeyword:
            message = String(localized: "Unexpected keyword: '\(info)'")
        case .unsupportedTimeSignature:
            message = String(localized: "Unsupported time signature: '\(info)'")
        case .invalidTransposition:
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
        case .invalidCC:
            message = String(localized: "Invalid CC number: '\(info)'; should be a decimal number between 0.0 and 10.0)")
        case .syntaxError:
            message = String(localized: "Syntax error: '\(info)'.")
        case .parenthesisMismatch:
            message = String(localized: "Parenthesis mismatch")
        case .squareBracketMismatch:
            message = String(localized: "Square bracket mismatch")
        case .ccSyntaxError:
            message = String(localized: "Expected a CC name=number pair")
        default :
            message = String(localized: "Unexpected error")
        }
        
        return message
    }
}
