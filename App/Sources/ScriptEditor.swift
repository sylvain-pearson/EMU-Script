//
//  ScriptEditor.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation
import SwiftUI
import HighlightedTextEditor

private let headingRegex = try! NSRegularExpression(pattern: "\\[[a-zA-Z0-9\\-_]+\\]", options: [])
private let numberRegex = try! NSRegularExpression(pattern: "(?<!\\w)[A-G0-9]+(?!\\w)", options: [])
private let commentRegex = try! NSRegularExpression(pattern: "//.+", options: [])
private let textRegex = try! NSRegularExpression(pattern: "\\\"[^\\\"]+\\\"", options: [])
private let linePrefixRegex = try! NSRegularExpression(pattern: "[a-zA-Z0-9\\-/_]+:", options: [])

private let keywordRegex = try! NSRegularExpression(
    pattern: "(?<!\\w)(chord|root|bass|arg|args|min[679]*|maj[679]*|sus[24]*|dom[79]*|dim[79]*|aug[79]*|m7|M7|m9|M9|b5|m3|M3|P4|P5|m6|M6)(?![\\w\\-_])",
    options: []
)

#if os(macOS)
func acolor(_ c: Color) -> NSColor { return NSColor(c) }
#else
func acolor(_ c: Color) -> UIColor { return UIColor(c) }
#endif

public extension Sequence where Iterator.Element == HighlightRule {
    static var emu: [HighlightRule] {
        [
            HighlightRule(pattern: headingRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: acolor(Color.scriptHeader))
            ),
            HighlightRule(pattern: keywordRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: acolor(Color.scriptKeyword))
            ),
            HighlightRule(pattern: numberRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: acolor(Color.scriptNumber))
            ),
            HighlightRule(pattern: commentRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: acolor(Color.scriptComment))
            ),
            HighlightRule(pattern: textRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: acolor(Color.scriptText))
            ),
            HighlightRule(pattern: linePrefixRegex,
                formattingRule: TextFormattingRule(key: .foregroundColor, value: acolor(Color.scriptLinePrefix))
            ),
        ]
    }
}

var previousText = ""

//--------------------------------------------------------
// A script editor with syntax highlighting and undo/redo
//--------------------------------------------------------
struct ScriptEditor : View {
    
    @Binding var document: EmuScriptDocument
    @Binding var reload : Int
    
    var body: some View {
        
        VStack {
            HighlightedTextEditor(text: $document.text, highlightRules: .emu)
                .introspect { editor in
#if os(macOS)
                    editor.textView.font = NSFont.userFixedPitchFont(ofSize: 16)
#else
                    editor.textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
#endif
                }
                .onTextChange {
                    let lineCount = $0.components(separatedBy: .newlines).count
                    let previousLineCount = previousText.components(separatedBy: .newlines).count
                    
                    if (lineCount != previousLineCount) {
                        document.loadDocument()
                        reload += 1
                        previousText = $0
                    }
                }
                .onCommit {
                    previousText = document.text
                    document.loadDocument()
                }
#if os(iOS)
                .toolbarVisibility(.hidden, for: .automatic)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
#endif
            
#if os(iOS)
            if (document.parser.errors.count > 0) {
                HStack {
                    Image(systemName: "exclamationmark").foregroundStyle(.scriptError).bold()
                    Text(document.parser.errors.count > 0 ? document.parser.getErrorMessage() : "").padding(10)
                }
            }
#endif
        }
    }
}
