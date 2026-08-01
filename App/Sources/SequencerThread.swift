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

#if os(macOS)
import IOKit.pwr_mgt
#endif

struct Event {
    var midi: MIDIEvent? = nil
    var timestamp: UInt64
    var trackId: Int
}

// ----------------------------------------------------------------------------------
// The sequencer thread class plays the notes of a composition using a thread that
// sends MIDI messages to the MIDI instruments through MIDI channels
// ----------------------------------------------------------------------------------
class SequencerThread: Thread {
    
    var midiManager: MIDIManager
    var midiOut : [Int : MIDIOutputConnection] = [:]
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
                midiOut[instrument.trackId] = midiManager.managedOutputConnections[outputName]!
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
                var endpointNames = ""
                
                for endpoint in midiManager.endpoints.inputs {
                    if (endpoint.name == instrument.endpoint || endpoint.displayName == instrument.endpoint) {
                        midiOut[instrument.trackId]!.add(inputs: [endpoint])
                        found = true
                    }
                    else {
                        endpointNames += "\n - "
                        endpointNames += endpoint.displayName
                    }
                }
                if (!found && scriptErroror.isOk()) {
                    scriptErroror = ScriptError(code: .invalidEndpoint, info: instrument.endpoint)
                    scriptErroror.details = endpointNames
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
        
#if os(macOS)
        let noSleepId = disableSleep()
#endif
    
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
                    let isMuted = document.isTrackMuted(event.trackId)
                    if (!isCancelled && !isMuted) {
                        let timestamp = startTimeStamp + event.timestamp
                        scheduleMidiEvent(midiEvent, timestamp: timestamp, trackId: event.trackId)
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
        
        midiManager.removeAll()
        
        scrollTo(-1)
        
#if os(macOS)
        enableSleep(id: noSleepId)
#endif
    }
    
    //--------------------------------------------------------------------------
    // Schedule a MIDI Event to be sent at a given time
    // Note: MIDIKit does not expose the event timestamp parameter in its API.
    //       As a workaround, we directly call the Core MIDI function.
    //--------------------------------------------------------------------------
    func scheduleMidiEvent(_ midiEvent: MIDIEvent, timestamp: UInt64, trackId: Int) {
        
        var packet = MIDIPacket()
        packet.timeStamp = timestamp
        packet.length = UInt16(midiEvent.midi1RawBytes().count)
        
        if (packet.length > 2) {
            packet.data.0 = midiEvent.midi1RawStatusByte()!
            packet.data.1 = midiEvent.midi1RawBytes()[1].littleEndian
            packet.data.2 = midiEvent.midi1RawBytes()[2].littleEndian
            
            if (packet.length > 3) { packet.data.3 = midiEvent.midi1RawBytes()[3].littleEndian }
            if (packet.length > 4) { packet.data.4 = midiEvent.midi1RawBytes()[4].littleEndian }
            if (packet.length > 5) { packet.data.5 = midiEvent.midi1RawBytes()[5].littleEndian }
            if (packet.length > 6) { packet.data.6 = midiEvent.midi1RawBytes()[6].littleEndian }
            if (packet.length > 7) { packet.data.7 = midiEvent.midi1RawBytes()[7].littleEndian }
            
            // print(midiEvent.debugDescription)
        }

        var list = MIDIPacketList(numPackets: 1, packet: packet)
        
        if let midiChannel = midiOut[trackId] {
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
            
            let section = document.composition.getSection(name: sectionName)
            if let measures = section.measures[instrument.name] {
                for n in 0..<measures.count {
                    var t = 0
                    for step in measures[n].steps {
                        
                        let index = (n*(document.composition.beatsPerMeasure * document.composition.stepsPerBeat))+t
                        
                        for cc in step.ccMessages {
                            let timestamp = stepTickCount * UInt64(stepCount + index)
                            if (cc.curve != nil) {
                                let ccEvents = createChangeEvents(cc: cc, instrument: instrument, timestamp: timestamp)
                                events[index].append(contentsOf: ccEvents)
                            }
                            else {
                                let event = createChangeEvent(cc: cc, instrument: instrument, timestamp: timestamp)
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
                        if (!step.sustained && !step.isError())
                        {
                            if (step.isArp()) {
                                // Arpeggiated notes
                                var duration = step.length
                                if (step.sustain) {
                                    duration = section.getSustainedNoteDuration(instrumentName: instrument.name, measureNumber: n)
                                }
                                let arpEvents = createArpEvents(step: step, duration: duration, velocity: velocity,
                                                                instrument: instrument, stepCount: stepCount + index)
                                events[index].append(contentsOf: arpEvents)
                            }
                            else if (step.isStrum()) {
                                // Strummed notes
                                let strumEvents = createStrumEvents(step: step, velocity: velocity, instrument: instrument,
                                                                    stepCount: stepCount + index)
                                events[index].append(contentsOf: strumEvents)
                            }
                            else {
                                // Normal playing style
                                for note in step.notes {
                                    let event = Event(
                                        midi: .noteOn(note.toUInt7, velocity: .midi1(velocity), channel: instrument.channel.toUInt4),
                                        timestamp: stepTickCount * UInt64(stepCount + index),
                                        trackId: instrument.trackId
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
                                        timestamp: (stepTickCount * UInt64(stepCount + index + step.length)) - (stepTickCount / 3),
                                        trackId: instrument.trackId
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
        return events
    }
    
    //-------------------------------------------------------
    // Create a Program Change or Control Change MIDI event
    //-------------------------------------------------------
    func createChangeEvent(cc: MidiControl, instrument: MusicalInstrument, timestamp: UInt64) -> Event
    {
        if (cc.isProgramChange) {
            let event = Event(
                midi: .programChange(.init(program: UInt7(cc.value), bank: .bankSelect(UInt14(cc.id)), channel: instrument.channel.toUInt4)),
                timestamp: timestamp,
                trackId: instrument.trackId
            )
            return event
        }
        else {
            let event = Event(
                midi: .cc(UInt7(cc.id), value: .midi1(UInt7(cc.value)), channel: instrument.channel.toUInt4),
                timestamp: timestamp,
                trackId: instrument.trackId
            )
            return event
        }
    }
    
    //-----------------------------------------------------
    // Create a progression of Control Change MIDI events
    //-----------------------------------------------------
    func createChangeEvents(cc: MidiControl, instrument: MusicalInstrument, timestamp: UInt64) -> [Event]
    {
        var events : [Event] = []
        
        if let curve = cc.curve {
            var firstValue = curve.startValue
            var lastValue = curve.endValue
            
            if (curve.startValue > curve.endValue) {
                firstValue = curve.endValue
                lastValue = curve.startValue
            }
            
            var x = firstValue
            while (x <= lastValue) {
                let t = curve.getTimeFor(value: x)
                
                let event = Event(
                    midi: .cc(UInt7(cc.id), value: .midi1(UInt7(x)), channel: instrument.channel.toUInt4),
                    timestamp: timestamp + UInt64(t * Double(stepTickCount)),
                    trackId: instrument.trackId
                )
                events.append(event)
                x += 1
            }
        }
        
        return events
    }
    
    //---------------------------------------
    // Create arpeggiated notes MIDI events
    //---------------------------------------
    func createArpEvents(step: Step, duration: Int, velocity: UInt7, instrument: MusicalInstrument, stepCount: Int) -> [Event] {
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
                                midi: .noteOn(note.toUInt7, velocity: .midi1(velocity), channel: instrument.channel.toUInt4),
                                timestamp: stepTickCount * UInt64(stepCount + i),
                                trackId: instrument.trackId
                            )
                            events.append(event)
                            event = Event(
                                midi: .noteOff(note.toUInt7, velocity: .midi1(velocity), channel: instrument.channel.toUInt4),
                                timestamp: (stepTickCount * UInt64(stepCount + i + Int(arp.duration))) - (stepTickCount / 3),
                                trackId: instrument.trackId
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
    func createStrumEvents(step: Step, velocity: UInt7, instrument: MusicalInstrument, stepCount: Int) -> [Event] {
        var events : [Event] = []
        
        if (step.isStrum()) {
            // Strumming playing style
            if let strum = step.playing {
                var v = velocity
                var noteIndex = 0
                let strumDuration = SequencerThread.millisecondsToTicks(Double(strum.duration))
                
                for note in step.getNotesInPlayingOrder() {
                    let event = Event(
                        midi: .noteOn(note.toUInt7, velocity: .midi1(UInt7(v)), channel: instrument.channel.toUInt4),
                        timestamp: (stepTickCount * UInt64(stepCount)) + (strumDuration * UInt64(noteIndex)),
                        trackId: instrument.trackId
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
#if os(macOS)
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
#endif
}
