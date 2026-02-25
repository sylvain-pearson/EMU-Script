//
//  EmuScriptDocument.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import SwiftUI
import UniformTypeIdentifiers

// The type of document
extension UTType { static var emuscript: UTType { UTType(importedAs: "spearson.emuscript") } }


// -----------------------------------------------------------------------------------------
// The lists of instruments and playlist items. It is made global, so the user's selection
// is retained when the document is reloaded
// -----------------------------------------------------------------------------------------
class Global {
    static var instruments: [MusicalInstrument] = [ ]
    static var playlist: [PlaylistItem] = [ ]
}

// ----------------------------------------------------------------
// The clickable area of a note on the staff
// ----------------------------------------------------------------
struct NotePosition {
    var x: Int
    var y: Int
    var width: Int
    var height: Int
    var step : Step
}

// ------------------------------------------------------------------------
// An EmuScript document is a musical composition loaded from a text file
// ------------------------------------------------------------------------
final public class EmuScriptDocument: FileDocument  {
    
    var textDocument: String
    var parser : ScriptParser
    var instruments: [MusicalInstrument] = []
    var playlist: [PlaylistItem] = []
    var sequences: [String : String] = [:]
    var midiNotes: [String : MidiNote] = [:]
    var ccNumbers: [String : Int] = [:]
    var sampleFiles: [String : Sample] = [:]
    var strumOrArps: [String : StrumOrArp]  = [:]
    var chords = Chords()
    var documentEdited = false
    
    var composition: MusicalComposition
    var measuresCount = 8
    var positions : [NotePosition] = []
    
    var richText: AttributedString = AttributedString("")
    
    static public var readableContentTypes: [UTType] { [.emuscript] }
    
    // -------------------------------
    // Thw default class initializer
    // -------------------------------
    init() {
        self.composition = MusicalComposition()
        self.parser = ScriptParser()
        self.documentEdited = true
        self.textDocument = """
        [composition]
        title: "Untitled"
        by: "Someone"
        time: 4/4
        BPM: 120
        transposition: 0
        playlist: intro

        [instruments]
        synth: "MIDI Input", channel=1, octave=3, velocity=80

        [intro]
        synth: 1 2 3 4 | 5 6 7 1'
        """
        
        loadDocument()
        self.richText = parser.highlightText(self.textDocument)
    }
    
    // ----------------------------------------------------------------------
    // The class initializer: loads an EMU-Script document from a text file
    // ----------------------------------------------------------------------
    public init(configuration: ReadConfiguration) throws {
        
        guard let data = configuration.file.regularFileContents,
              let fileContent = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self.textDocument = fileContent
        self.composition = MusicalComposition()
        self.instruments = []
        self.playlist = []
        self.measuresCount = 0
        self.parser = ScriptParser()
        self.documentEdited = true
        
        loadDocument()
        self.richText = parser.highlightText(self.textDocument)
    }

    // ----------------------------------------------------------------------------------------
    // This function is called when the user has selected or unselected a musical instrument
    // ----------------------------------------------------------------------------------------
    public func onInstrumentSelection(id: UUID, isSelected : Bool) {
        for i in 0..<instruments.count {
            if (instruments[i].id == id) {
                instruments[i].isSelected = isSelected
                Global.instruments = instruments
                break
            }
        }
    }
    
    // ----------------------------------------------------------------------------------------
    // This function is called when the user has selected or unselected a playlist item
    // ----------------------------------------------------------------------------------------
    public func onPlaylistSelection(id: UUID, isSelected : Bool) {
        for i in 0..<playlist.count {
            if (playlist[i].id == id) {
                playlist[i].isSelected = isSelected
                Global.playlist = playlist
                break
            }
        }
    }
    
    // -------------------------------------------------------------------
    // This function is called when the user update the script
    // -------------------------------------------------------------------
    func onUpdate(_ text: AttributedString, reload : Bool = false) {
        self.documentEdited = true
        if (reload) {
            self.textDocument = String(richText.characters)
            loadDocument()
        }
        else {
            self.richText = parser.highlightText(String(text.characters))
        }
    }
    
    // -------------------------------------------------------------
    // Get the main octave of the instrument as a MIDI value (0-7)
    // -------------------------------------------------------------
    func getInstrumentOctave(name: String) -> UInt8 {
        var octave: UInt8 = 0
        for instrument in instruments {
            if (instrument.name == name) {
                octave = instrument.octave
            }
        }
        if (octave == 0) {  // drum or sampler
            return 0
        }
        else {
            return octave + 2
        }
    }
    
    // -------------------------------------------------------------
    // Get the velocity of the instrument as a MIDI value (0-127)
    // -------------------------------------------------------------
    func getInstrumentVelocity(name: String) -> UInt8 {
        var velocity: UInt8 = 0
        for instrument in instruments {
            if (instrument.name == name) {
                velocity = instrument.velocity
            }
        }
        return velocity
    }

    // -------------------------------------------------
    // Load all sections of the text document (script)
    // -------------------------------------------------
    func loadDocument()
    {
        self.composition = MusicalComposition()
        self.instruments = []
        self.playlist = []
        self.measuresCount = 0

        self.parser.parse(self.textDocument)
        
        loadCompositionSection()
        loadInstrumentsSection()
        loadSequencesSection()
        loadSoundsSection()

        let sectionNames = Set(playlist.map { $0.name })
        for sectionName in sectionNames {
            loadMusicalSection(name: sectionName)
        }
        
        loadControlSection()
        
        measuresCount = 0
        for item in playlist {
            for section in composition.sections {
                if (item.name == section.name) {
                    measuresCount = measuresCount + section.getLength()
                }
            }
        }
           
        // Restore the previous selection of instruments, if any
        for i in 0..<instruments.count {
            if (i < Global.instruments.count && instruments[i].name == Global.instruments[i].name) {
                instruments[i].isSelected = Global.instruments[i].isSelected
            }
        }
        // Restore the previous selection of playlist items, if any
        for i in 0..<playlist.count {
            if (i < Global.playlist.count && playlist[i].name == Global.playlist[i].name) {
                playlist[i].isSelected = Global.playlist[i].isSelected
            }
        }
        
        self.richText = parser.highlightText(self.textDocument)
        self.documentEdited = false
    }
        
    // ------------------------------------
    // Load the [composition) section
    // ------------------------------------
    func loadCompositionSection()  {
           
        let sectionName = "composition"
        if let section = parser.getSection(name: sectionName)
        {
            for line in section.textLines
            {
                let key = line.key.lowercased()
                
                if (key == "playlist") {
                    for sectionName in line.getValues(separator: ",") {
                        playlist.append(PlaylistItem(name: String(sectionName).trimmingCharacters(in: .whitespaces)))
                    }
                }
                else if (key == "bpm") {
                    self.composition.BPM = UInt8(toNumber(line.value))
                }
                else if (key == "time") {
                    let timeSignature = line.value
                    if (!self.composition.setTimeSignature(timeSignature)) {
                        parser.error(.unsupportedTimeSignature, info: timeSignature, at: line.lineNumber)
                    }
                }
                else if (key == "transposition") {
                    let transposition = toNumber(line.value)
                    if (transposition >= -7 && transposition <= 7) {
                        self.composition.transposition = Int8(transposition)
                    } else {
                        parser.error(.InvalidTransposition, info: line.value, at: line.lineNumber)
                    }
                }
                else if (key == "title") {
                    self.composition.name = line.value.trimmingCharacters(in: ["\""])
                }
                else if (key == "by") {
                    self.composition.autor = line.value.trimmingCharacters(in: ["\""])
                }
                else if (key == "cc") {
                    self.ccNumbers.merge(parseCC(line.value)) { (x, y) in x }
                }
                else if (key != "info") {
                    parser.error(.unexpectedKeyword, info: line.key, at: line.lineNumber)
                }
            }
        }
        else {
            parser.error(.MissingSection, info: sectionName)
        }
    }
    
    // -----------------------------------------
    // Load the [instruments] section
    // -----------------------------------------
    func loadInstrumentsSection()  {

        let sectionName = "instruments"
        if let section = parser.getSection(name: sectionName)
        {
            for line in section.textLines
            {
                var instrument = MusicalInstrument(name: line.key)

                for keyValue in line.getValues(separator: ",")
                {
                    let array = keyValue.split(separator: "=")
                    if (array.count == 2)
                    {
                        let key = String(array[0]).trimmingCharacters(in: .whitespaces)
                        let value = String(array[1]).trimmingCharacters(in: .whitespaces)
                        
                        if (key == "channel") {
                            instrument.channel = UInt8(toNumber(value) - 1)
                        }
                        else if (key == "octave") {
                            instrument.octave = UInt8(toNumber(value))
                        }
                        else if (key == "velocity") {
                            instrument.velocity = UInt8(toNumber(value))
                        }
                        else if (key != "info") {
                            parser.error(.unexpectedKeyword, info: key, at: line.lineNumber)
                        }
                    }
                    else if (array.count == 1 && array[0] == "sample") {
                        instrument.endpoint = ""
                    }
                    else if (array.count == 1) {
                        instrument.endpoint = String(array[0]).trimmingCharacters(in: .punctuationCharacters)
                    }
                    else {
                        parser.error(.syntaxError, info: keyValue, at: line.lineNumber)
                    }
                }
                
                instruments.append(instrument)
            }
        }
        else {
            parser.error(.MissingSection, info: sectionName)
        }

    }
    
    // -----------------------------------------
    // Load the optional [sequences] section
    // -----------------------------------------
    func loadSequencesSection()  {
        if let section = parser.getSection(name: "sequences") {
            for line in section.textLines {
                sequences[line.key] = line.value
            }
        }
    }
        
    // -------------------------------------------
    // Load the optional [sounds] section
    // -------------------------------------------
    func loadSoundsSection()
    {
        let sectionName = "sounds"
        
        if let section = parser.getSection(name: sectionName)
        {
            for line in section.textLines
            {
                let name = line.key
                var functionText = ""
                var volume = 100
                var step = 6
                var duration = 6
                var msec = 10
                var vdec = 3
                
                for keyValue in line.getValues(separator: ",") {
                    if (keyValue.contains("(") && keyValue.contains(")")) {
                        functionText = String(keyValue)
                    }
                    else {
                        let array = keyValue.split(separator: "=")
                        if (array.count == 2)
                        {
                            let key = String(array[0]).trimmingCharacters(in: .whitespaces)
                            let value = String(array[1]).trimmingCharacters(in: .whitespaces)
                            
                            if (key == "volume") {
                                volume = toNumber(value)
                            }
                            else if (key == "duration") {
                                duration = toNumber(value)
                            }
                            else if (key == "msec") {
                                msec = toNumber(value)
                            }
                            else if (key == "vdec") {
                                vdec = toNumber(value)
                            }
                            else if (key == "step") {
                                step = toNumber(value)
                            }
                            else {
                                parser.error(.unexpectedKeyword, info: key, at: line.lineNumber)
                            }
                        }
                        else {
                            parser.error(.syntaxError, info: keyValue, at: line.lineNumber)
                        }
                    }
                }
                
                var array = parseFunction(text: functionText)
                
                if (array.count >= 2) {
                    let fctName = array.removeFirst()
                    let firstArg = array[0]
                    
                    if (fctName == "sample") {
                        var sample = Sample(name: name)
                        sample.path = firstArg.trimmingCharacters(in: .punctuationCharacters)
                        sample.volume = UInt8(volume)
                        sampleFiles[name] = sample
                    }
                    else if (fctName == "midi") {
                        var midiNote = MidiNote(name: name)
                        midiNote.value = toNumber(firstArg)
                        midiNotes[name] = midiNote
                    }
                    else if (fctName == "arp" || fctName == "strum") {
                        var sequence = [UInt8]()
                        for arg in array {
                            sequence.append(UInt8(toNumber(arg)))
                        }
                        if (fctName == "arp") {
                            let arp = StrumOrArp(sequence: sequence, step: UInt8(step), duration: UInt8(duration))
                            strumOrArps[name] = arp
                        }
                        else if (fctName == "strum") {
                            let strum = StrumOrArp(sequence: sequence, msec: UInt8(msec), vdec: UInt8(vdec))
                            strumOrArps[name] = strum
                        }
                    }
                    else {
                        parser.error(.unexpectedKeyword, info: fctName, at: line.lineNumber)
                    }
                }
                else {
                    parser.error(.syntaxError, info: functionText, at: line.lineNumber)
                }
            }
        }
    }
    
    // -------------------------------------------
    // Load the optional [control] section
    // -------------------------------------------
    func loadControlSection()
    {
        let sectionName = "control"
        
        if let section = parser.getSection(name: sectionName)
        {
            for line in section.textLines {
                
                let target = line.getPath()
                
                if (target.count > 1) {
                    let instrumentName = String(target[0])
                    let messageName = String(target[target.count-1])
                    var messageValue = toNumber(String(line.value))
                    let messageValueIsSigned = line.value.contains("-") || line.value.contains("+")
                    var messageMap : [String:Int] = [:]
                    var sectionName = (composition.sections.count > 0) ? composition.sections[0].name : ""
                    if (target.count > 2) {
                        sectionName = String(target[1])
                    }
                    
                    var measures = composition.getSection(name: sectionName).getMeasures(instrumentName: instrumentName)
                    
                    if (measures.isEmpty) {
                        measures = [Measure()]
                        composition.getSection(name: sectionName).measures[instrumentName] = measures
                    }
                    
                    var measureStart = 1
                    var measureEnd = (messageName == "velocity") ? measures.count : 1
                    if (target.count > 3) {
                        let measures = target[2].split(separator: "..")
                        measureStart = toNumber(String(measures[0]))
                        
                        if (measures.count == 2) {
                            measureEnd = toNumber(String(measures[1]))
                        }
                        else {
                            measureEnd = measureStart
                        }
                    }
                    
                    var messageId = -1
                    if (messageName == "cc") {
                        messageMap = parseCC(line.value)
                        if (messageMap.isEmpty) {
                            parser.error(.ccSyntaxError, info: "", at: line.lineNumber)
                        }
                    }
                    else if (messageName == "program") {
                        let msg = line.getValues(separator: ".")
                        if (msg.count == 2) {
                            messageId = toNumber(String(msg[0]))
                            messageValue = toNumber(String(msg[1]))
                        }
                    }
                    
                    var m = 0
                    for measure in measures {
                        m += 1
                        if (m >= measureStart && m <= measureEnd) {
                            if (messageName == "velocity") {
                                for step in measure.steps {
                                    if (messageValueIsSigned) {
                                        step.velocity += messageValue
                                    }
                                    else {
                                        step.velocity = messageValue
                                    }
                                    if (step.velocity < 0) {
                                        step.velocity = 0
                                    }
                                    else if (step.velocity > 127) {
                                        step.velocity = 127
                                    }
                                }
                            }
                            else {
                                if (measure.steps.count == 0) {
                                    measure.steps.append(Step())
                                }
                                if (messageName == "program") {
                                    measure.steps[0].ccMessages.append(MidiControl(bank: UInt8(messageId), program: UInt8(messageValue)))
                                }
                                else  if (messageName == "cc") {
                                    for cc in messageMap {
                                        messageId = ccNumbers[cc.key] ?? 0
                                        if (messageId != 0) {
                                            measure.steps[0].ccMessages.append(MidiControl(id: UInt8(messageId), value: UInt8(cc.value)))
                                        }
                                        else  {
                                            parser.error(.unexpectedKeyword, info: cc.key, at: line.lineNumber)
                                        }
                                    }
                                }
                                else {
                                    parser.error(.unexpectedKeyword, info: messageName, at: line.lineNumber)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ------------------------------------------
    // Load a musical section
    // -----------------------------------------
    func loadMusicalSection(name: String)
    {
        let sectionName = name

        if let section = parser.getSection(name: sectionName)
        {
            // Make sure the chords are processed first
            section.moveLineFirst(key: "chord")
            
            loadMusicalSection(name: name, section: section)
        }
        else {
            parser.error(.UndefinedSection, info: sectionName, at: parser.getLineNumber(sectionName: "composition", lineKey: "playlist"))
        }
    }
    
    // ----------------------------------
    // Parse and load a musical section
    // ----------------------------------
    func loadMusicalSection(name: String, section: ScriptSection) {

        let musicalSection = MusicalSection(name: name, length: 4)
        
        for line in section.textLines {
            
            let instrumentName = line.key
            var measures: [Measure]  = []
            
            let text = preProcess(line.value, measureCount: musicalSection.getLength())
            var phrases = text.split(separator: "|")
            var measureNumber = 0
            
            let octave = getInstrumentOctave(name: instrumentName)
            
            for phrase in phrases {
                let measure = Measure()
                var measureStepsLength = 0

                measureNumber += 1
                let tokens = parser.tokenise(text: String(phrase))
                var defaultStepLength = getMeasureStepLength(tokens)
                   
                for word in tokens {
                    if (word == "-") {
                        if (measure.steps.count > 0) {
                            let lastStep = measure.steps.last!
                            lastStep.length += defaultStepLength
                            measureStepsLength += defaultStepLength
                        }
                        else if (measures.count > 0) {
                            // Une note qui dure plus d'une mesure
                            let lastStep = measures.last!.steps.last!
                            lastStep.sustain = true
                            
                            let step = lastStep.clone()
                            step.length = defaultStepLength
                            step.sustained = true
                            step.sustain = false
                            measure.steps.append(step)
                            measureStepsLength += step.length
                        }
                    }
                    else if (word == ")") {
                        defaultStepLength *= 2
                    }
                    else if (word == "(") {
                        defaultStepLength /= 2
                    }
                    else if (word == "]") {
                        defaultStepLength *= 3
                    }
                    else if (word == "[") {
                        defaultStepLength /= 3
                    }
                    else {
                        let chord = musicalSection.getChordAt(measureNumber: measureNumber, position: measureStepsLength)
                        let step = parseStep(text: String(word), octave: octave, instrumentName: instrumentName, chord: chord, length: defaultStepLength)
                        measure.steps.append(step)
                        measureStepsLength += step.length
                        
                        if (step.isError()) {
                            parser.error(step.error, info: step.text, at: line.lineNumber)
                        }
                    }
                }
                
                if (tokens.count > 0)
                {
                    measures.append(measure)
                }
            }

            if (musicalSection.measures[instrumentName] == nil) {
                musicalSection.measures[instrumentName] = measures
            }
            else {
                musicalSection.measures[instrumentName]!.append(contentsOf: measures)
            }
        }
        
        composition.sections.append(musicalSection)
    }

    // ---------------------------
    // Get measure step length
    // ---------------------------
    func getMeasureStepLength(_ tokens : [String]) -> Int {
        var timeCount : Double = 0.0
        var timeUnit : Double = 1.0
        
        for token in tokens {
            if (token == "(") {
                timeUnit /= 2.0
            }
            else if (token == ")") {
                timeUnit *= 2.0
            }
            else if (token == "[") {
                timeUnit /= 3.0
            }
            else if (token == "]") {
                timeUnit *= 3.0
            }
            else if (token.hasSuffix("-") && token.count > 1) {
                timeCount += (timeUnit * 1.5)
            }
            else {
                timeCount += timeUnit
            }
        }

        if (timeCount > 0) {
            return composition.stepsPerBeat * composition.beatsPerMeasure / Int(timeCount)
        }
        else {
            return 0
        }
    }
    
    // --------------------------------------------------
    // Parse a musical step, such as "123", "-" or "4"
    // --------------------------------------------------
    func parseStep(text: String, octave: UInt8, instrumentName: String, chord: String, length: Int) -> Step {
        let step = Step()
        var notes = text
        
        step.length = length
        step.velocity = Int(getInstrumentVelocity(name: instrumentName))
    
        if (notes.hasSuffix("-")) {
            // dotted note
            notes = String(notes.dropLast())
            step.length += length/2
        }
        
        let isText = instrumentName.contains("text")
        let isChord = instrumentName.contains("chord")
        let isDrum = (octave == 0 && !isText && !isChord)
        
        for note in notes.split(separator: "/") {
            let note = String(note)

            if let midiNote = midiNotes[note] {
                step.add(midiNote: midiNote.value, text: midiNote.name, isDrum: isDrum)
            }
            else if let sample = sampleFiles[note] {
                step.add(sample: sample.name)
            }
            else if let strumOrArp = strumOrArps[note] {
                step.playing = strumOrArp
            }
            else if (isDrum) {
                for c in note {
                    let note = String(c)
                    step.add(drum: note)
                }
            }
            else if (isText) {
                step.add(text: note)
            }
            else if (isChord) {
                step.add(text: note)
                if (chords.find(name: note) == "" && note != ".") {
                    step.error = .invalidChord
                }
            }
            else {
                var stepNotes = ""
                if (note == "chord") {
                    stepNotes = chords.find(name: chord)
                }
                else if (note.starts(with: "chord(") && note.hasSuffix(")")) {
                    let args = parseFunction(text: note)
                    let n = (args.count == 2) ? toNumber(args[1]) : 0
                    if (n > 0) {
                        stepNotes = chords.find(name: chord, notesCount: n)
                    }
                    else {
                        step.error = .syntaxError
                    }
                }
                else if (note == "root") {
                    stepNotes = chords.find(name: chord, notesCount: -1)
                }
                else {
                    stepNotes = chords.find(name: note)
                }
                if (stepNotes == "") {
                    stepNotes = note
                }
                
                step.add(notes: stepNotes, octave: octave, transposition: composition.transposition)
            }
        }
        
        return step
    }
    
    // --------------------------------------------------
    // Preprocess a music line :
    //  - Do the text replacement of sequences
    //  - Repeat measures (* and ...)
    // --------------------------------------------------
    func preProcess(_ text: String, measureCount: Int) -> String
    {
        var phrases = text.split(separator: "|")
        var result = ""
        var m = 1
        
        // First, process the sequences
        for phrase in phrases {
            if (result != "") {
                result += " | "
            }
            
            var newPhrase = String(phrase)
            let words = phrase.split(separator: "(")
            let id = String(words[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if (sequences[id] != nil) {
                // Found a sequence do the replacement of arg(n) parameters
                newPhrase = sequences[id]!
                
                var n = 0
                for argValue in parseFunction(text: String(phrase)) {
                    let argName = String("arg(\(n))")
                    newPhrase = newPhrase.replacingOccurrences(of: argName, with: argValue)
                    n = n + 1
                }
                
                // Do the replacement of args parameter
                if (words.count == 2) {
                    let args = String(words[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if (args.hasSuffix(")")) {
                        newPhrase = newPhrase.replacingOccurrences(of: "args", with: args.dropLast())
                    }
                }
            }
            
            result += newPhrase
            m += 1
        }
    
        phrases = result.split(separator: "|")
        result = ""
        m = 1
        
        // Now process the measures repetition
        for phrase in phrases {
            if (result != "") {
                result += " | "
            }
            
            var newPhrase = String(phrase)
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
            
            result += newPhrase
            m += 1
        }
        
        return result.trimmingCharacters(in: ["\""])
    }

    // ------------------------------------------------
    // Parse a function, such as "arp(1 2 3)"
    // ------------------------------------------------
    func parseFunction(text: String) -> [String] {
        var result: [String] = []
        
        let args = text.trimmingCharacters(in: .whitespaces).split(separator: "(")
        if (args.count == 2) {
            result.append(String(args[0]))
            let args = args[1].split(separator: ")")
            if (args.count == 1) {
                let args = args[0].split(separator: " ")
                for arg in args {
                    result.append(String(arg).trimmingCharacters(in: .whitespaces))
                }
            }
        }
        
        return result
    }
    
    // ------------------------------------------------
    // Parse a coma separated list of CC name=value
    // ------------------------------------------------
    func parseCC(_ text: String) -> [String : Int] {
        var result: [String : Int] = [:]
        
        for phrase in text.split(separator: ",") {
            let expression = phrase.split(separator: "=")
            if (expression.count == 2) {
                let ccName = String(expression[0]).trimmingCharacters(in: .whitespaces)
                result[ccName] = toCCValue(String(expression[1]))
            }
        }
        
        return result
    }
    
    // ------------------------------
    // Convert a string to a number
    // ------------------------------
    func toNumber(_ text: String) -> Int {
        var result : Int = 0
        let num = Int(text)
        if (num != nil) {
            result = num!
        }

        return result
    }
    
    // ----------------------------------------
    // Convert a string to a CC Value (0-127)
    // ----------------------------------------
    func toCCValue(_ text: String) -> Int {
        var result : Int = 0
        if (text.contains(".")) {
            let num = Float(text)
            if (num != nil) {
                result = ((Int)(num! * 127)) / 10
            }
        }
        else {
            let num = Int(text)
            if (num != nil) {
                result = num!
            }
        }
        
        return result
    }
    
    // -----------------------------------------------
    // A method required by the FileDocument protocol
    // -----------------------------------------------
    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {   

        if (self.documentEdited) {
            self.textDocument = String(richText.characters)
            loadDocument()
        }
        
        let data = Data(richText.utf8)
        return .init(regularFileWithContents: data)
    }
}
