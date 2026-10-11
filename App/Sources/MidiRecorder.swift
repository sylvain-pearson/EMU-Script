//
//  KeyboardRecorder.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import CoreMIDI
import MIDIKitIO

struct KeyboardEvent {
    var startTime: Double   // Step position
    var endTime: Double     // Step position
    let note: UInt8         // MIDI note number
}

class MidiRecorder {
    
    private var midiManager: MIDIManager
    public  var receivedEvents : [KeyboardEvent] = []
    private var notesOnTimeMap: [UInt8: Double] = [:]
    private var startTimestamp = mach_absolute_time()
    private var stepTickCount: UInt64 = 0
    
    init() {
        self.midiManager = MIDIManager(clientName: "Emu-Recorder", model: "EMU-Script", manufacturer: "spearson")
    }
    
    func start(startTimestamp : UInt64, stepTickCount: UInt64) {
        self.startTimestamp = startTimestamp
        self.stepTickCount = stepTickCount
        self.receivedEvents.removeAll(keepingCapacity: true)
        self.notesOnTimeMap.removeAll(keepingCapacity: true)
        
        do {
            try midiManager.start()
            
            let enpointCriteria: MIDIEndpointIdentity = .name("MIDI Output")
            
            try midiManager.addInputConnection(to: .outputs(matching: [enpointCriteria]), tag: "EmuMidiListener",
                receiver: .events { /*[weak self]*/ events, timeStamp, source in
                    Task { @MainActor in
                        for event in events {
                            if (event.isChannelVoice(ofType: .noteOn)) {
                                let chrono = Double(timeStamp - self.startTimestamp)
                                let time = chrono / Double(self.stepTickCount)
                                let note = event.midi1RawDataBytes()?.data1 ?? 0
                                self.notesOnTimeMap[note] = time
                            }
                            else if (event.isChannelVoice(ofType: .noteOff))  {
                                let chrono = Double(timeStamp - self.startTimestamp)
                                let endTime = chrono / Double(self.stepTickCount)
                                let note = event.midi1RawDataBytes()?.data1 ?? 0
                                let startTime = self.notesOnTimeMap[note] ?? endTime
                                let event = KeyboardEvent(startTime: startTime, endTime: endTime, note: note)
                                self.receivedEvents.append(event)
                            }
                        }
                    }
                }
            )
        }
        catch {
            print("Keyboard Recorder error: \(error)")
        }
    }
}
