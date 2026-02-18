//
//  SequencerThread.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation
import CoreMIDI
import MIDIKitIO

struct Event {
    var midi: MIDIEvent? = nil
    var strummingDelay = 0.0
    var sampleName: String = ""
}

// ----------------------------------------------------------------------------------
// The sequencer thread class plays the notes of a composition using a thread that
// sends MIDI messages to the MIDI instruments through MIDI channels
// ----------------------------------------------------------------------------------
class SequencerThread: Thread {
    
    var midiManager: MIDIManager
    var midiOut : [UInt8 : MIDIOutputConnection] = [:]
    var document: EmuScriptDocument
    var scrollTo: (Int) -> Void
    var audioPlayers : [String: AudioPlayer] = [:]
    var sequence : [[Event]] = []
    var scriptErroror = ScriptError()
    
    // ----------------------------------------------------------------------------
    // The class initializer that creates the MIDI manager and the MIDI endpoints
    // ----------------------------------------------------------------------------
    init(document: EmuScriptDocument, scrollFunc: @escaping (Int) -> Void)
    {
        self.document = document
        self.scrollTo = scrollFunc

        midiManager = MIDIManager(clientName: "MuseMIDIManager", model: "Muse", manufacturer: "spearson")
        
        do {
            try midiManager.start()
            
            for instrument in document.instruments {
                let outputName = String("MuseOutput") + String(instrument.channel)
                try midiManager.addOutputConnection(to: .none, tag: outputName)
                midiOut[instrument.channel] = midiManager.managedOutputConnections[outputName]!
            }
        }
        catch {
            scriptErroror = ScriptError(code: .midiError, info: "\(error)")
        }
    }

    //------------------------------------------------
    // Build the list of MIDI events to be sequenced
    //------------------------------------------------
    func prepare() -> ScriptError
    {
        if (scriptErroror.isOk())
        {
            for instrument in document.instruments {
                if (instrument.isSampler() == false) {
                    var found = false
                    for endpoint in midiManager.endpoints.inputs {
                        if (endpoint.name == instrument.endpoint) {
                            midiOut[instrument.channel]!.add(inputs: [endpoint])
                            found = true
                        }
                    }
                    if (!found && scriptErroror.isOk()) {
                        scriptErroror = ScriptError(code: .invalidEndpoint, info: instrument.endpoint)
                    }
                }
            }
            
            for section in document.playlist {
                if section.isSelected {
                    let events = getMidiEventsSequence(sectionName: section.name, firstEvents: sequence.popLast())
                    sequence += events
                }
            }
        }
        
        return scriptErroror
    }

    // ------------------------------------------------------------------
    // The background processing function that generate the MIDI events
    // ------------------------------------------------------------------
    override func main()
    {
        let stepDuration = Double(60.0) / Double(document.composition.BPM) / Double(document.composition.stepsPerBeat)
        let time0 = Date.now
        var stepCount = 0
        
        do {
            for events in sequence {
                
                let startTime = Date.now
                
                if (!isCancelled && events.count > 0) {
                    scrollTo(stepCount)
                    //Thread.sleep(forTimeInterval: 0.02)
                }
                
                var strumming = false
                for event in events {
                    if let midiEvent = event.midi {
                        if (!isCancelled || midiEvent.isChannelVoice(ofType: .noteOff)) {
                            if (event.strummingDelay == 0.0) {
                                try midiOut[UInt8(midiEvent.channel!)]!.send(event: midiEvent)
                            }
                            else {
                                strumming = true
                            }
                        }
                    }
                    else if (!isCancelled && event.sampleName != "") {
                        if let audioPlayer = audioPlayers[event.sampleName] {
                            audioPlayer.play()
                        }
                    }
                }
                
                if (strumming && !isCancelled) {
                    var first = true
                    for event in events {
                        if (event.strummingDelay > 0.0) {
                            if let midiEvent = event.midi {
                                if (!first) {
                                    Thread.sleep(forTimeInterval: event.strummingDelay)
                                }
                                first = false
                                try midiOut[UInt8(midiEvent.channel!)]!.send(event: midiEvent)
                            }
                        }
                    }
                }
         
                if (!isCancelled) {
                    let processingDuration = startTime.distance(to: Date.now)
                    Thread.sleep(forTimeInterval: TimeInterval(stepDuration-processingDuration))
                    stepCount += 1
                }
            }
            
            scrollTo(-1)
        }
        catch {
            print("Error while sending Event: \(error)")
        }
        
        let p = time0.distance(to: Date.now)
        print("Song duration: \(p) seconds")
    }
    
    // -----------------------------------------------------------------------------------------
    // Translate a Musical Section into a sequence of MIDI events / samples playback
    // -----------------------------------------------------------------------------------------
    func getMidiEventsSequence(sectionName: String, firstEvents: [Event]?) -> [[Event]]
    {
        var events : [[Event]] = []

        // Initialize the lists of events to be returned
        let sectionStepsCount = (document.composition.getSectionLength(name: sectionName) * (document.composition.beatsPerMeasure * document.composition.stepsPerBeat)) + 1
        for i in 0..<sectionStepsCount {
            events.append([])
            events[i] = []
        }
        
        if (firstEvents != nil) {
            events[0] = firstEvents!
        }
        
        for instrument in document.instruments {
            if (instrument.isSelected) {
                let section = document.composition.getSection(name: sectionName)
                if let measures = section.measures[instrument.name] {
                    for n in 0..<measures.count {
                        var t = 0
                        for step in measures[n].steps {
                            
                            let index = (n*(document.composition.beatsPerMeasure * document.composition.stepsPerBeat))+t
        
                            for cc in step.ccMessages {
                                if (cc.isProgramChange) {
                                    let event = Event(midi: .programChange(.init(program: UInt7(cc.value), bank: .bankSelect(UInt14(cc.id)), channel: instrument.channel.toUInt4)))
                                    events[index].append(event)
                                }
                                else {
                                    let event = Event(midi: .cc(UInt7(cc.id), value: .midi1(UInt7(cc.value)), channel: instrument.channel.toUInt4))
                                    events[index].append(event)
                                }
                            }
                            
                            var velocity: UInt7 = 0
                            if (step.velocity > 127) {
                                velocity = 127
                            }
                            else if (step.velocity > 0) {
                                velocity = step.velocity.toUInt7
                            }
                            
                            // Notes ON
                            if (!step.sustained && !step.isError()) {
                                
                                if (step.isArp()) {
                                    // Arpeggio playing style
                                    if let arp = step.playing {
                                        var i = index
                                        var last = index + step.length
                                        if (step.sustain) {
                                            last = index + section.getSustainedNoteDuration(instrumentName: instrument.name, measureNumber: n)
                                        }
                                        last = last - Int(arp.duration)
                                        repeat {
                                            for note in step.getNotesInPlayingOrder() {
                                                if (i < last) {
                                                    var event = Event(midi: .noteOn(note.toUInt7, velocity: .midi1(velocity), channel: instrument.channel.toUInt4))
                                                    events[i].append(event)
                                                    event = Event(midi: .noteOff(note.toUInt7, velocity: .midi1(velocity), channel: instrument.channel.toUInt4))
                                                    events[i + Int(arp.duration)].append(event)
                                                    i = i + Int(arp.step)
                                                }
                                                else {
                                                    break
                                                }
                                            }
                                        } while (i < last)
                                    }
                                }
                                else if (step.isStrum()) {
                                    // Strumming playing style
                                    if let strum = step.playing {
                                        var v = velocity
                                        for note in step.getNotesInPlayingOrder() {
                                            var event = Event(midi: .noteOn(note.toUInt7, velocity: .midi1(UInt7(v)), channel: instrument.channel.toUInt4))
                                            event.strummingDelay = Double(strum.duration) / 1000
                                            events[index].append(event)
                                            let decreaseOfVelocity = Int(v) * Int(strum.vdec) / 100
                                            v = v - UInt7(decreaseOfVelocity)
                                            if (v < 20) {
                                                v = 20
                                            }
                                        }
                                    }
                                }
                                else {
                                    // Normal playing style
                                    for note in step.notes {
                                        let event = Event(midi: .noteOn(note.toUInt7, velocity: .midi1(velocity), channel: instrument.channel.toUInt4))
                                        events[index].append(event)
                                    }
                                }
                                
                                // Samples playing
                                for sampleName in step.samples {
                                    if let sample = document.sampleFiles[sampleName] {
                                        let event = Event(sampleName: sampleName)
                                        events[index].append(event)
                                        createAudioPlayer(id: sample.name, fileName: sample.path, volume: (Int(velocity) * Int(sample.volume))/100)
                                    }
                                }
                            }
                            
                            // Notes OFF
                            if (!step.sustain && !step.isError()) {
                                
                                for note in step.notes {
                                    if (step.isMIDINote()) {
                                        let event = Event(midi: .noteOff(note.toUInt7, velocity: .midi1(velocity), channel: instrument.channel.toUInt4))
                                        
                                        events[index + step.length].append(event)
                                    }
                                }
                            }
                            
                            t += (step.length)
                        }
                    }
                }
            }
        }
        return events
    }
    
    //----------------------------------------------------------------------
    // Create an audio player that always play the same sample file
    // The audio files must be under the user's Music directory:
    //----------------------------------------------------------------------
    func createAudioPlayer(id: String, fileName: String, volume: Int)
    {
        if (audioPlayers[id] == nil) {
            let player = AudioPlayer(fileName: fileName, volume: volume)
            
            if (player.isError() == false) {
                audioPlayers[id] = player
            }
            else if (scriptErroror.isOk()) {
                scriptErroror = ScriptError(code: .fileNotFound, info: fileName)
            }
        }
    }
}
