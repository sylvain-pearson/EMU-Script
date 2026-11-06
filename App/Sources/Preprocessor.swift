//
//  Preprocessor.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation
public class Preprocessor {
    
    private var document: EmuScriptDocument
    private var measures: [String: [String]] = [:]
    
    //-------------------------------
    // Initialize the preprocessor
    //-------------------------------
    init(_ document: EmuScriptDocument) {
        self.document = document
    }
    
    // ---------------------------------
    // Do the text lines preprocessing
    // ---------------------------------
    func preProcess(_ lineArray: [TextLine]) -> [TextLine] {
        let lines = lineArray
        
        // Replace sequences (up to 3 level of nesting)
        for _ in [1, 2, 3] {
            for line in lines {
                line.value = preProcess1(line.value)
            }
        }
        
        // Count the number of measures
        var mesasureCount = 0
        var countsArray : [String : Int] = [:]
        for line in lines {
            var count = line.value.split(separator: "|").count
            if let n = countsArray[line.key] {
                count += n
                countsArray[line.key] = count
            }
            countsArray[line.key] = count
            
            if (count > mesasureCount) {
                mesasureCount = count
            }
        }
        
        // Replace ... and *
        for line in lines {
            line.value = preProcess2(line.value, instrument: line.key, measureCount: mesasureCount)
        }
        
        // Replace instrument names
        for line in lines {
            line.value = preProcess3(line.value, instrument: line.key)
        }
        
        return lines
    }
    
    // -------------------------------------------------------------
    // The first preprocessing phase: the replacement of sequences
    // -------------------------------------------------------------
    func preProcess1(_ text: String) -> String
    {
        let phrases = text.split(separator: "|")
        var result = ""
        var m = 1
        
        // Process the sequences
        for phrase in phrases {
            if (result != "") {
                result += " | "
            }
            
            var newPhrase = String(phrase).trimmingCharacters(in: .whitespacesAndNewlines)
            let words = phrase.split(separator: "(")
            let id = String(words[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if (document.sequences[id] != nil) {
                // Found a sequence do the replacement of arg(n) parameters
                newPhrase = document.sequences[id]!
                
                var n = 0
                for argValue in document.parser.parseFunction(text: String(phrase)) {
                    let argName = String("$\(n)")
                    newPhrase = newPhrase.replacingOccurrences(of: argName, with: argValue)
                    n = n + 1
                }
            }
            
            result += newPhrase
            m += 1
        }
        
        return result.trimmingCharacters(in: ["\""])
    }
    
    // --------------------------------------------------------------
    // The second preprocessing phase: the replacement of * and ...
    // --------------------------------------------------------------
    func preProcess2(_ text: String, instrument: String, measureCount: Int) -> String
    {
        var phrases = text.split(separator: "|")
        var result = ""
        var m = 1
        
        // Process the measures repetition
        for phrase in phrases {
            if (result != "") {
                result += " | "
            }
            
            var newPhrase = String(phrase).trimmingCharacters(in: .whitespacesAndNewlines)
            let words = phrase.split(separator: "(")
            let id = String(words[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if (id == "*") {
                if (m > 1) {
                    newPhrase = String(phrases[m-2])
                    phrases[m-1] = phrases[m-2]
                }
                else {
                    newPhrase = "."
                }
                addMeasure(newPhrase, instrument: instrument)
            }
            else if (id == "...") {
                let measureCountBefore3dots = m - 1
                let measureCountAfter3dots = phrases.count - m
                var index = 0
                newPhrase = ""
                
                while (m <= measureCount - measureCountAfter3dots) {
                    if (!newPhrase.isEmpty) {
                        newPhrase += " | "
                    }
                    newPhrase += phrases[index]
                    addMeasure(String(phrases[index]), instrument: instrument)
                    m += 1
                    index += 1
                    
                    if (index >= measureCountBefore3dots) {
                        index = 0
                    }
                }
                
                if (measureCountBefore3dots == 0) {
                    newPhrase = "."
                }
            }
            else {
                addMeasure(newPhrase, instrument: instrument)
            }
            
            result += newPhrase
            m += 1
        }
        
        return result.trimmingCharacters(in: ["\""])
    }
    
    // -----------------------------------------------------------------------
    // The third preprocessing phase: copy the measures of other instruments
    // -----------------------------------------------------------------------
    func preProcess3(_ text: String, instrument: String) -> String {
        
        let phrases = text.split(separator: "|")
        var result = ""
        var m = 0
        
        for phrase in phrases {
            var newPhrase = String(phrase).trimmingCharacters(in: .whitespacesAndNewlines)
            let instrument = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let measures = self.measures[instrument] {
                if (measures.count > m) {
                    newPhrase = String(measures[m])
                }
            }
            
            if (!result.isEmpty) {
                result += " | "
            }
            
            result += newPhrase
            m += 1
        }
        
        return result
    }
    
    private func addMeasure(_ text: String, instrument: String) {
        if (measures[instrument] == nil) {
            measures[instrument]  = []
        }
        measures[instrument]!.append(text)
    }
}
