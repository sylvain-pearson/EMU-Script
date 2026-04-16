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
import IOKit.pwr_mgt

struct Event {
    var midi: MIDIEvent? = nil
    var timestamp: UInt64
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
    var sequence : [[Event]] = []
    var scriptErroror = ScriptError()
    var stepDuration : Double
    var stepTickCount: UInt64
    
    // ----------------------------------------------------------------------------
    // The class initializer that creates the MIDI manager and the MIDI endpoints
    // ----------------------------------------------------------------------------
    init(document: EmuScriptDocument, scrollFunc: @escaping (Int) -> Void)
    {
        self.document = document
        self.scrollTo = scrollFunc

        self.stepDuration = Double(60.0) / Double(document.composition.BPM) / Double(document.composition.stepsPerBeat)
        self.stepTickCount =  SequencerThread.millisecondsToTicks(self.stepDuration * 1000)
        
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

            for section in document.playlist {
                if section.isSelected {
                    let events = getMidiEventsSequence(sectionName: section.name, firstEvents: sequence.last, stepCount: sequence.count)
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
        let stepsAhead = 12
        let noSleepId = disableSleep()
    
        let startTimeStamp = mach_absolute_time() + (stepTickCount * UInt64(stepsAhead))
        let startTime = Date.now + (stepDuration * Double(stepsAhead))
        var stepCount = 0
        
        // The playback is delayed by 12 steps (1 beat)
        // The Kernel handle the MIDI events delivery
        
        for events in sequence {
            
            // Scrolling is done one step ahead of playback
            if (stepCount >= stepsAhead - 1) {
                scrollTo(stepCount-stepsAhead+1)
            }
            
            for event in events {
                if let midiEvent = event.midi {
                    if (!isCancelled) {
                        let timestamp = startTimeStamp + event.timestamp
                        scheduleMidiEvent(midiEvent, timestamp: timestamp)
                    }
                }
            }
     
            if (!isCancelled) {
                stepCount += 1
                let endSleepTime = startTime + TimeInterval(Double(stepCount-stepsAhead) * stepDuration)
                Thread.sleep(until: endSleepTime)
            }
            else {
                break
            }
        }
        
        let duration = String(format: "%.2f", startTime.distance(to: Date.now))
        print("Playback duration: \(duration) seconds")
        
        scrollTo(-1)
        enableSleep(id: noSleepId)
    }
    
    //--------------------------------------------------------------------------
    // Schedule a MIDI Event to be sent at a given time
    // Note: MIDIKit does not expose the event timestamp parameter in its API.
    //       As a workaround, we directly call the Core MIDI function.
    //--------------------------------------------------------------------------
    func scheduleMidiEvent(_ midiEvent: MIDIEvent, timestamp: UInt64) {
        
        var packet = MIDIPacket()
        packet.timeStamp = timestamp
        packet.length = 3
        packet.data.0 = midiEvent.midi1RawStatusByte()!
        packet.data.1 = midiEvent.midi1RawDataBytes()?.data1?.littleEndian ?? 0
        packet.data.2 = midiEvent.midi1RawDataBytes()?.data2?.littleEndian ?? 0

        var list = MIDIPacketList(numPackets: 1, packet: packet)
        
        if let midiChannel = midiOut[UInt8(midiEvent.channel!)] {
            
            let outputPortRef = midiChannel.coreMIDIOutputPortRef?.littleEndian ?? 0
            
            if (midiChannel.endpoints.count > 0) {
                let enpoint = midiChannel.endpoints[0]
                let endpointRef = enpoint.coreMIDIObjectRef.littleEndian
                MIDISend(outputPortRef, endpointRef, &list)
            }
        }
    }
    
    // ------------------------------------------------------------
    // Translate a Musical Section into a sequence of MIDI events
    // ------------------------------------------------------------
    func getMidiEventsSequence(sectionName: String, firstEvents: [Event]?, stepCount: Int) -> [[Event]]
    {
        var events : [[Event]] = []

        // Initialize the lists of events to be returned
        let sectionStepsCount = (document.composition.getSectionLength(name: sectionName) * (document.composition.beatsPerMeasure * document.composition.stepsPerBeat))
        for i in 0..<sectionStepsCount {
            events.append([])
            events[i] = []
        }
        
        if (firstEvents != nil) {
            events[0] = firstEvents!
        }
        
        for instrument in document.instruments {
            if (!instrument.isMuted) {
                let section = document.composition.getSection(name: sectionName)
                if let measures = section.measures[instrument.name] {
                    for n in 0..<measures.count {
                        var t = 0
                        for step in measures[n].steps {
                            
                            let index = (n*(document.composition.beatsPerMeasure * document.composition.stepsPerBeat))+t
                            
                            for cc in step.ccMessages {
                                let timestamp = stepTickCount * UInt64(stepCount + index)
                                let event = createChangeEvent(cc: cc, channel: instrument.channel, timestamp: timestamp)
                                events[index].append(event)
                            }
                            
                            var velocity: UInt7 = 0
                            if (step.velocity > 127) {
                                velocity = 127
                            }
                            else if (step.velocity > 0) {
                                velocity = step.velocity.toUInt7
                            }
                            
                            // Notes ON
                            if (!step.sustained && !step.isError())
                            {
                                if (step.isArp()) {
                                    // Arpeggiated notes
                                    var duration = step.length
                                    if (step.sustain) {
                                        duration = section.getSustainedNoteDuration(instrumentName: instrument.name, measureNumber: n)
                                    }
                                    let arpEvents = createArpEvents(step: step, duration: duration, velocity: velocity, channel: instrument.channel, stepCount: stepCount + index)
                                    events[index].append(contentsOf: arpEvents)
                                }
                                else if (step.isStrum()) {
                                    // Strummed notes
                                    let strumEvents = createStrumEvents(step: step, velocity: velocity, channel: instrument.channel, stepCount: stepCount + index)
                                    events[index].append(contentsOf: strumEvents)
                                }
                                else {
                                    // Normal playing style
                                    for note in step.notes {
                                        let event = Event(
                                            midi: .noteOn(note.toUInt7, velocity: .midi1(velocity), channel: instrument.channel.toUInt4),
                                            timestamp: stepTickCount * UInt64(stepCount + index)
                                        )
                                        events[index].append(event)
                                    }
                                }
                            }
                            
                            if (!step.sustain && !step.isError()) {
                                // Turn the note off
                                for note in step.notes {
                                    if (step.isMIDINote()) {
                                        let event = Event(
                                            midi: .noteOff(note.toUInt7, velocity: .midi1(velocity), channel: instrument.channel.toUInt4),
                                            timestamp: (stepTickCount * UInt64(stepCount + index + step.length)) - (stepTickCount / 3)
                                        )
                                        
                                        events[index].append(event)
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
    
    //-------------------------------------------------------
    // Create a Program Change or Control Change MIDI event
    //-------------------------------------------------------
    func createChangeEvent(cc: MidiControl, channel: UInt8, timestamp: UInt64) -> Event
    {
        if (cc.isProgramChange) {
            let event = Event(
                midi: .programChange(.init(program: UInt7(cc.value), bank: .bankSelect(UInt14(cc.id)), channel: channel.toUInt4)),
                timestamp: timestamp
            )
            return event
        }
        else {
            let event = Event(
                midi: .cc(UInt7(cc.id), value: .midi1(UInt7(cc.value)), channel: channel.toUInt4),
                timestamp: timestamp
            )
            return event
        }
    }
    
    //---------------------------------------
    // Create arpeggiated notes MIDI events
    //---------------------------------------
    func createArpEvents(step: Step, duration: Int, velocity: UInt7, channel: UInt8, stepCount: Int) -> [Event] {
        var events : [Event] = []
        
        if (step.isArp()) {
            // Arpeggio playing style
            if let arp = step.playing {
                var i = 0
                var last = duration
                last = last - Int(arp.duration)
                repeat {
                    for note in step.getNotesInPlayingOrder() {
                        if (i < last) {
                            var event = Event(
                                midi: .noteOn(note.toUInt7, velocity: .midi1(velocity), channel: channel.toUInt4),
                                timestamp: stepTickCount * UInt64(stepCount + i)
                            )
                            events.append(event)
                            event = Event(
                                midi: .noteOff(note.toUInt7, velocity: .midi1(velocity), channel: channel.toUInt4),
                                timestamp: (stepTickCount * UInt64(stepCount + i + Int(arp.duration))) - (stepTickCount / 3)
                            )
                            events.append(event)
                            i = i + Int(arp.step)
                        }
                        else {
                            break
                        }
                    }
                } while (i < last)
            }
        }

        return events
    }
    
    //------------------------------------
    // Create strummed notes MIDI events
    //------------------------------------
    func createStrumEvents(step: Step, velocity: UInt7, channel: UInt8, stepCount: Int) -> [Event] {
        var events : [Event] = []
        
        if (step.isStrum()) {
            // Strumming playing style
            if let strum = step.playing {
                var v = velocity
                var noteIndex = 0
                let strumDuration = SequencerThread.millisecondsToTicks(Double(strum.duration))
                
                for note in step.getNotesInPlayingOrder() {
                    let event = Event(
                        midi: .noteOn(note.toUInt7, velocity: .midi1(UInt7(v)), channel: channel.toUInt4),
                        timestamp: (stepTickCount * UInt64(stepCount)) + (strumDuration * UInt64(noteIndex))
                    )
                    
                    events.append(event)
                    let decreaseOfVelocity = Int(v) * Int(strum.vdec) / 100
                    v = v - UInt7(decreaseOfVelocity)
                    if (v < 20) {
                        v = 20
                    }
                    noteIndex += 1
                }
            }
        }
        
        return events
    }
    
    //-----------------------------------------------
    // Conversion of milliseconds to clock ticks
    //  - On M1 Mac and later, 1 ms = 240000 ticks
    //  - On Intel based Mac, 1 ms = 1 tick
    //-----------------------------------------------
    static func millisecondsToTicks(_ milliseconds: Double) -> UInt64
    {
        var clockInfo = mach_timebase_info()
        mach_timebase_info(&clockInfo)

        let nanoseconds = milliseconds * 1000000
        return UInt64(nanoseconds * Double(clockInfo.denom) / Double(clockInfo.numer))
    }
    
    //--------------------------------------------------
    // Prevents display sleep to occur during playback
    //--------------------------------------------------
    func disableSleep() -> IOPMAssertionID
    {
        var assertionID: IOPMAssertionID = 0
        let reasonForActivity = "EMU-Script sequencer active" as CFString
        
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reasonForActivity,
            &assertionID
        )
        
        if success != kIOReturnSuccess {
            print("Failed to disable sleep")
        }
        
        return assertionID
    }
    
    //---------------------------------
    // Restore display sleep feature
    //---------------------------------
    func enableSleep(id: IOPMAssertionID) {
        if (id != 0) {
            let success = IOPMAssertionRelease(id)
            if success != kIOReturnSuccess {
                print("Failed to enable sleep")
            }
        }
    }
}
