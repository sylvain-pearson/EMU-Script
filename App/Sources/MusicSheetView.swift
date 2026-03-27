//
//  MusicSheetView.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation
import SwiftUI

//------------------------------------------------------------------
// This view displays a cursor on the current beat during playback
//------------------------------------------------------------------
struct MusicSheetProgress : View {
    
    @Binding var document: EmuScriptDocument
    @Binding var progress : Double
    
    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: false) { context, size in
            if (progress >= 0) {
                var path = Path()
                let width = document.composition.beatsPerMeasure * document.composition.stepsPerBeat * 10 * 3
                let pos = (Double(width) * progress) + 50
                path.addRect(CGRect(x: pos+5, y: 195, width: 40, height: 5))
                context.fill(path, with: .color(.blue))
            }
        }.padding(.vertical, 25)
    }
}

//---------------------------------------
// This view displays the music sheet
//---------------------------------------
struct MusicSheetView : View {
    
    @Binding var document: EmuScriptDocument
    @Binding var selectedStep : Step?
    @Binding var properties : Properties
    @Binding var refreshCounter : Bool
    
    let measureHeight = 190
    let margin = 50
    
    var body: some View { 
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: false) { context, size in
            draw(context: context, size: size)
        }
        .frame(width: (Double(getMeasureWidth()) * Double(document.measuresCount+2)) + Double(margin*2))
    }
    
    // ---------------------------------
    // Returns the width of a measure
    // ---------------------------------
    func getMeasureWidth() -> Int {
        return document.composition.beatsPerMeasure * document.composition.stepsPerBeat * 10
    }
    
    // ------------------------------------------------------
    // Draw the staffs and notes of the composition
    // ------------------------------------------------------
    func draw(context: GraphicsContext, size: CGSize) {

        var x = margin
        var measureNumber = 1
        let measureWidth = getMeasureWidth()
        
        document.positions.removeAll()
        
        if (properties.items.isEmpty) {
            properties = document.composition.getProperties()
        }
        
        for item in document.playlist {
            let sectionLength = document.composition.getSectionLength(name: item.name)
            let width = sectionLength * measureWidth
            
            if (item.isSelected) {
                var y = margin
                var lyricsDone = false
                var instrumentNumber = 1
                
                for n in 0..<document.instruments.count  {
                    if (document.instruments[n].isSelected) {
                        
                        let isDrum = document.instruments[n].isDrum()
                        let isSampler = document.instruments[n].isSampler()
                        instrumentNumber += 1
                        
                        if (isDrum || isSampler) {
                            drawInstrumentName(context: context, name: document.instruments[n].name, x0: x, y0: y-50)
                            drawCompactStaff(context: context, x0: x, y0: y-20, width: width)
                        }
                        else {
                            drawInstrumentName(context: context, name: document.instruments[n].name, x0: x, y0: y)
                            drawStaff(context: context, x0: x, y0: y, width: width)
                        }
                        
                        
                        let instrumentName = document.instruments[n].name
                        if let measures = document.composition.getSection(name: item.name).measures[instrumentName] {
                            drawNotes(context: context, x0: x, y0: y-50, measures: measures, measureNumber: measureNumber, isCompact: isDrum || isSampler)
                        }
                        
                        if (lyricsDone == false && !isDrum) {
                            // Draw lyrics
                            lyricsDone = true
                            if let measures = document.composition.getSection(name: item.name).measures["text"] {
                                drawLyrics(context: context, x0: x, y0: y+measureHeight+4, measures: measures)
                            }
                        }
                        
                        if (isDrum || isSampler) {
                            y += (measureHeight/2)
                        }
                        else {
                            y += measureHeight + (margin/2)
                        }
                    }
                }
                
                if let measures = document.composition.getSection(name: item.name).measures["chord"] {
                    drawChords(context: context, x0: x, y0: y-5, measures: measures)
                }
                
                drawMeasureNumbers(context: context, x0: x, width: width, sectionName: item.name, measureNumber: &measureNumber)
                
                x = x + width
            }
        }
    }

    // ----------------------------------------------------------------------------
    // Draw a staff having 4 horizontal lines and one vertical line per measure
    // ----------------------------------------------------------------------------
    func drawStaff(context: GraphicsContext, x0: Int, y0: Int, width: Int) {

        let beatsPerMeasure = document.composition.beatsPerMeasure
        let measureWidth = getMeasureWidth()
        
        let y1 = y0 + measureHeight - (3 * 10) - 50      // low C
        let y2 = y0 + measureHeight - (6 * 10) - 50      // low F
        let y3 = y0 + measureHeight - (10 * 10) - 50     // high C
        let y4 = y0 + measureHeight - (13 * 10) - 50     // high F
        
        for y in [y1, y2, y3, y4] {
            var path = Path()
            path.move(to: CGPoint(x: x0, y: y))
            path.addLine(to: CGPoint(x: width+x0, y: y))
            context.stroke(path, with: .color(.gray), lineWidth: 1)
        }
        
        var x = x0
        while (x <= x0 + width)
        {
            var path = Path()
            path.move(to: CGPoint(x: x, y: y1 + 22))
            path.addLine(to: CGPoint(x: x, y: y1))
            context.stroke(path, with: .color(.gray), lineWidth: 1)

            x = x + (measureWidth / beatsPerMeasure)
        }
        
        x = x0
        while (x <= x0 + width)
        {
            var path = Path()
            path.move(to: CGPoint(x: x, y: y1 + 22))
            path.addLine(to: CGPoint(x: x, y: y4 - 22))
            context.stroke(path, with: .color(.gray), lineWidth: 1)
            
            x = x + measureWidth
        }
    }
    
    // -----------------------------------------------------------------------------------------------
    // Draw a staff for drum and sampler, having 1 horizontal line and one vertical line per measure
    // -----------------------------------------------------------------------------------------------
    func drawCompactStaff(context: GraphicsContext, x0: Int, y0: Int, width: Int) {
   
        let beatsPerMeasure = document.composition.beatsPerMeasure
        let measureWidth = getMeasureWidth()
        
        var path = Path()
        path.move(to: CGPoint(x: x0, y: y0))
        path.addLine(to: CGPoint(x: width+x0, y: y0))
        context.stroke(path, with: .color(.gray), lineWidth: 1)
               
        var x = x0
        while (x <= x0 + width)
        {
            var path = Path()
            path.move(to: CGPoint(x: x, y: y0))
            path.addLine(to: CGPoint(x: x, y: y0 + margin + 10))
            context.stroke(path, with: .color(.gray), lineWidth: 1)
            x = x + measureWidth
        }
        
        x = x0
        while (x <= x0 + width)
        {
            var path = Path()
            path.move(to: CGPoint(x: x, y: y0 + 18))
            path.addLine(to: CGPoint(x: x, y: y0))
            context.stroke(path, with: .color(.gray), lineWidth: 1)

            x = x + (measureWidth / beatsPerMeasure)
        }
    }
    
    // --------------------------------------------
    // Draw the staff's instrument name vertically
    // --------------------------------------------
    func drawInstrumentName(context: GraphicsContext, name: String, x0: Int, y0: Int) {
        if (x0 < 100) {
            let dy = 16
            var y = y0 + ((measureHeight - margin - 5 - (name.count * dy)) / 2)
            for letter in name {
                context.draw(Text(String(letter)).font(.title3), at: CGPoint(x: x0-20, y: y), anchor: .center)
                y += dy
            }
        }
    }
    
    // -------------------------------------------------------
    // Draw the measure numbers and the section names
    // -------------------------------------------------------
    func drawMeasureNumbers(context: GraphicsContext, x0: Int, width: Int, sectionName: String, measureNumber: inout Int) {

        var x = x0
        let measureWidth = getMeasureWidth()
        
        while (x <= x0 + width)
        {
            if (x == x0) {
                context.draw(Text(sectionName).font(.title3), at: CGPoint(x: x-4, y: 10), anchor: .leading)
                measureNumber = measureNumber + 1
            }
            else if (x + measureWidth <= x0 + width) {
                context.draw(Text(String(measureNumber)).font(.title3), at: CGPoint(x: x-4, y: 10), anchor: .leading)
                measureNumber = measureNumber + 1
            }
            
            x = x + measureWidth
        }
    }
    
    // ----------------------------------------------
    // Draw the notes of a musical sections
    // ----------------------------------------------
    func drawNotes(context: GraphicsContext, x0: Int, y0: Int, measures: [Measure], measureNumber: Int, isCompact: Bool) {
        
        let beatsPerMeasure = document.composition.beatsPerMeasure
        let stepsPerBeat = document.composition.stepsPerBeat
        let measureWidth = getMeasureWidth()
        let dx = Float(measureWidth) / Float(beatsPerMeasure * stepsPerBeat)
        var x = Float(x0)
        var m = measureNumber - 1
        
        for measure in measures {
            
            var stepCount = 0
            for step in measure.steps {
                
                if (!step.isSilence()) {
                    drawStep(context: context, x: x, y0: y0, step: step, stepCount: stepCount, measureCount: m, isCompact: isCompact)
                }
                
                x = x + (Float(step.length) * dx)
                stepCount += step.length
            }
            m += 1
        }
    }
    
    //---------------------------------
    // Draw a note, interval or chord
    //---------------------------------
    func drawStep(context: GraphicsContext, x: Float, y0: Int, step: Step, stepCount: Int, measureCount: Int, isCompact: Bool)
    {
        let beatsPerMeasure = document.composition.beatsPerMeasure
        let stepsPerBeat = document.composition.stepsPerBeat
        let measureWidth = getMeasureWidth()
        let dx = Float(measureWidth) / Float(beatsPerMeasure * stepsPerBeat)
        
        var path = Path()
        var y = y0
        
        if (isCompact) {
            y = y + (measureHeight / 2) - 24
        }
        else if (step.positions.count > 0) {
            y = y + measureHeight - (step.positions[0] * 10) - 4
        }
        
        let width = Int(Float(step.length) * dx)
        var fillColor = Color(.black)
        
        if (step.isError()) {
            fillColor = Color(cgColor: .init(gray: 0.1, alpha: 0.5))
        }
        else if (step.octave == 0 && step.isSynth() == false) {
            fillColor = Color(cgColor: .init(gray: 0.5, alpha: 0.5))
        }
        else {
            var gradiant : Int = step.notes[0] + Int(document.composition.transposition) - 43
            if (gradiant < 0) {
                gradiant = 0
            }
            if (gradiant > 36) {
                gradiant = 36
            }
            fillColor = Color(hue: Double(gradiant) / 36 * 0.16, saturation: 1, brightness: 0.95)
        }

        path = Path()
        if (selectedStep != nil && step.isEqual(selectedStep!)) {
            path.addRect(CGRect(x: Int(x+4), y: y+1, width: width-8, height: 6))
        }
        else {
            path.addRect(CGRect(x: Int(x+4), y: y+2, width: width-8, height: 4))
        }
                   
        context.fill(path, with: .color(fillColor))
        
        var noteWidth = step.length + 2
        if (noteWidth > 24) {
            noteWidth = 24
        }
        
        if (!step.sustained )
        {
            if (step.isSynth() && step.positions.count > 0) {
                for n in 1...step.positions.count {
                    let y1 = y0 + measureHeight - (step.positions[n-1] * 10) - 4
                    
                    if (noteWidth < 9) {
                        path = Path()
                        path.addArc(center: CGPoint(x: Int(x+10), y: y1+4), radius: 6, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
                        context.fill(path, with: .color(.black))
                                
                        if (step.isSharp(pos: n-1, transposition: document.composition.transposition)) {
                            path = Path()
                            path.addArc(center: CGPoint(x: Int(x+10), y: y1+4), radius: 4, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
                            context.fill(path, with: .color(.white))
                        }
                    }
                    else {
                        path = Path()
                        let roundCorner = CGSize(width: 5, height: 5)
                        let rect = CGRect(x: Int(x+4), y: y1-2, width: noteWidth, height: 12)
                        path.addRoundedRect(in: rect, cornerSize: roundCorner)
                        context.fill(path, with: .color(.black))
                        
                        if (step.isSharp(pos: n-1, transposition: document.composition.transposition)) {
                            path = Path()
                            let rect = CGRect(x: Int(x+6), y: y1, width: noteWidth-4, height: 8)
                            path.addRoundedRect(in: rect, cornerSize: roundCorner)
                            
                            context.fill(path, with: .color(.white))
                        }
                    }
                    
                    // Draw a dashed line beteen notes of an interval
                    if (n > 1 && y - y1 > 15) {
                        
                        var dx = 10
                        if (noteWidth > 12) {
                            dx = 4 + (noteWidth/2)
                        }
                        path = Path()
                        path.move(to: CGPoint(x: Int(x)+dx, y: y-3))
                        path.addLine(to: CGPoint(x: Int(x)+dx, y: y1+10))
                        context.stroke(path, with: .color(fillColor), style: .init(lineWidth: 4, dash: [6, 4]))
                    }
                    y = y1
                }
            }
            else {  // drum or sample
                if (noteWidth < 9) {
                    path = Path()
                    path.addArc(center: CGPoint(x: Int(x+10), y: y+4), radius: 6, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
                    context.fill(path, with: .color(.black))
                }
                else {
                    var path = Path()
                    let roundCorner = CGSize(width: 5, height: 5)
                    let rect = CGRect(x: Int(x+4), y: y-2, width: noteWidth, height: 12)
                    path.addRoundedRect(in: rect, cornerSize: roundCorner)
                    context.fill(path, with: .color(.black))
                }
            }
        }
        
        document.positions.append(NotePosition(x: Int(x), y: y0+margin, width: width, height: measureHeight-margin, step: step))
        
        if (!step.isSilence() && !step.sustained && !step.isSynth()) {
            let xOffset = noteWidth + 3
            context.draw(Text(step.text).font(.title3).foregroundStyle(.black), at: CGPoint(x: Int(x)+xOffset, y: y-10), anchor: .leading)
        }
    }
    
    
    // -----------------------------------------
    // Draw the lyrics of a musical sections
    // -----------------------------------------
    func drawLyrics(context: GraphicsContext, x0: Int, y0: Int, measures: [Measure]) {
        
        let beatsPerMeasure = document.composition.beatsPerMeasure
        let stepsPerBeat = document.composition.stepsPerBeat
        let measureWidth = getMeasureWidth()
        let dx = Float(measureWidth) / Float(beatsPerMeasure * stepsPerBeat)
        var x = Float(x0)
     
        for measure in measures {
            
            var stepCount = 0
            for step in measure.steps {
                if (step.isText()) {
                    let y = y0 - 40
                    if (!step.sustained) {
                        context.draw(Text(step.text).font(.title3).foregroundStyle(.black), at: CGPoint(x: Int(x+6), y: y), anchor: .leading)
                    }
                }
                x = x + (Float(step.length) * dx)
                stepCount += step.length
            }
        }
    }

    // ---------------------------------------------------
    // Draw the chords progression of a musical sections
    // ---------------------------------------------------
    func drawChords(context: GraphicsContext, x0: Int, y0: Int, measures: [Measure]) {
        
        let beatsPerMeasure = document.composition.beatsPerMeasure
        let stepsPerBeat = document.composition.stepsPerBeat
        let measureWidth = getMeasureWidth()
        let dx = Float(measureWidth) / Float(beatsPerMeasure * stepsPerBeat)
        var x = Float(x0)
     
        for measure in measures {
            
            var stepCount = 0
            for step in measure.steps {

                let width = Float(step.length) * dx
                let text = step.text
                
                if (step.isText()) {
                    let y = y0
                    context.draw(Text(text).font(.title2).foregroundStyle(.black), at: CGPoint(x: Int(x+(width/2)), y: y+15), anchor: .center)
                }
                
                var path = Path()
                path.move(to: CGPoint(x: Int(x+4), y: y0-10))
                path.addLine(to: CGPoint(x: Int(x+4), y: y0))
                path.addLine(to: CGPoint(x: Int(x+width-4), y: y0))
                path.addLine(to: CGPoint(x: Int(x+width-4), y: y0-10))
                context.stroke(path, with: .color(.gray), lineWidth: 1)
                
                x = x + width
                stepCount += step.length
            }
        }
    }
}
