//
//  MusicSheetView.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import Foundation
import SwiftUI

let stepWidth = 8
var viewWidth = 1.0

//------------------------------------------------------------------
// This view displays a cursor on the current beat during playback
//------------------------------------------------------------------
struct MusicSheetProgress : View {
    
    @Binding var document: EmuScriptDocument
    @Binding var scrollByCount: Int
    @Binding var progress : Double
    @Binding var zoomFactor : Double

    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: false) { context, size in
            if (progress >= 0) {
                var path = Path()
                let measureWidth = document.composition.beatsPerMeasure * document.composition.stepsPerBeat * stepWidth
                let width = measureWidth * scrollByCount
                let pos = (Double(width) * progress) + 51 + Double(stepWidth)
                path.addRect(CGRect(x: pos, y: 15, width: 1.5, height: 1000))
                context.fill(path, with: .color(.blue))
            }
        }
        .padding(.vertical, 25)
        .onGeometryChange(for: CGSize.self) { geometry in geometry.size} action: { viewSize in
            viewWidth = viewSize.width
            updateScrollByCount()
        }
        .onChange(of: zoomFactor) { 
            updateScrollByCount()
        }
    }

    func updateScrollByCount() {
        let measureWidth = (document.composition.beatsPerMeasure * document.composition.stepsPerBeat * stepWidth)
        let maxMeasuresInView = Int(viewWidth / Double(measureWidth) / zoomFactor)
        
        if (maxMeasuresInView > 1) {
            scrollByCount = maxMeasuresInView - 1
        }
        else {
            scrollByCount = 1
        }
    }
}

//---------------------------------------
// This view displays the music sheet
//---------------------------------------
struct MusicSheetView : View {
    
    @Binding var document: EmuScriptDocument
    @Binding var selection : Selection
    @Binding var refreshCounter : Bool
    @Binding var zoomFactor : Double
    
    let xMargin = 50
    var measureHeights : [String: Double] = [:]
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: false) { context, size in
            draw(context: context, size: size)
        }
        .frame(width: (Double(getMeasureWidth()) * Double(document.getSelectedMeasuresCount() + 4) * max(zoomFactor,1)) + Double(xMargin * 2),
               height: MusicSheetView.getViewHeight(document: document) * max(zoomFactor, 1))
    }
    
    // ---------------------------------
    // Returns the width of a measure
    // ---------------------------------
    func getMeasureWidth() -> Int {
        return document.composition.beatsPerMeasure * document.composition.stepsPerBeat * stepWidth
    }
    
    // ---------------------------------
    // Calculate the view height
    // ---------------------------------
    static func getViewHeight(document: EmuScriptDocument) -> Double {
        var height = 0
        var n = 0
        
        for instrument in document.instruments {
            if (instrument.isSelected) {
                let range = document.composition.getInstrumentRange(instrumentName: instrument.name)
                var octaveRange = 0
                
                if (range.0 < 5) {
                    // 3 octaves staff
                    octaveRange = 3
                }
                else if (range.1 > 13) {
                    // 2 octaves staff
                    octaveRange = 2
                }
                else {
                    // 1 octave staff
                    octaveRange = 1
                }
                
                let noteRange = (octaveRange * 7) + 2
                height += (noteRange * 10)
                height += 30
                
                document.instruments[n].octaveRange = octaveRange
            }
            n += 1
        }
        
        return Double(height)
    }
    
    // ------------------------------------------------------
    // Draw the staffs and notes of the composition
    // ------------------------------------------------------
    func draw(context: GraphicsContext, size: CGSize) {

        var x = xMargin
        var measureNumber = 1
        let measureWidth = getMeasureWidth()
        
        document.positions.removeAll()
        
        for item in document.playlist {
            let sectionLength = document.composition.getSectionLength(name: item.name)
            let width = sectionLength * measureWidth
            
            if (item.isSelected) {
                var y = 30
                var lyricsDone = false
                var instrumentNumber = 1
                
                for n in 0..<document.instruments.count  {
                    if (document.instruments[n].isSelected) {
                        
                        let isDrum = document.instruments[n].isDrum()
                        instrumentNumber += 1
                        
                        let octaveRange = document.instruments[n].octaveRange
                        let noteRange = (octaveRange * 7) + 2
                        let staffHeight = noteRange * 10
                        
                        drawInstrumentName(context: context, name: document.instruments[n].name, x0: x, y0: y, y1: y + staffHeight)
                        y = y + staffHeight
                        
                        if (isDrum) {
                            
                            drawCompactStaff(context: context, x0: x, y0: y, width: width)
                        }
                        else {
                            drawStaff(context: context, x0: x, y0: y, width: width, octaveRange: document.instruments[n].octaveRange)
                        }
                        
                        let instrumentName = document.instruments[n].name
                        if let measures = document.composition.getSection(name: item.name).measures[instrumentName] {
                            var y0  = y
                            if (octaveRange < 3 && isDrum == false) {
                                y0 = y0 + 70
                            }
                            drawNotes(context: context, x0: x, y0: y0, measures: measures, measureNumber: measureNumber, isCompact: isDrum)
                        }
                        
                        if (lyricsDone == false && !isDrum) {
                            // Draw lyrics
                            lyricsDone = true
                            if let measures = document.composition.getSection(name: item.name).measures["text"] {
                                drawLyrics(context: context, x0: x, y0: y, measures: measures)
                                y = y + 15
                            }
                        }
                        
                        y = y + 10
                    }
                }
                
                if let measures = document.composition.getSection(name: item.name).measures["chord"] {
                    drawChords(context: context, x0: x, y0: y+10, measures: measures)
                }
                
                drawMeasureNumbers(context: context, x0: x, width: width, sectionName: item.name, measureNumber: &measureNumber)
                
                x = x + width
            }
        }
    }

    // ----------------------------------------
    // Draw a staff having 1, 2 or 3 octaves
    // ----------------------------------------
    func drawStaff(context: GraphicsContext, x0: Int, y0: Int, width: Int, octaveRange: Int) {
        
        let beatsPerMeasure = document.composition.beatsPerMeasure
        let measureWidth = getMeasureWidth()
        let noteHeight = 10
        let octaveHeight = 7 * noteHeight
        
        var n = 0
        while (n < octaveRange) {
            
            let y1 = y0 - (n * octaveHeight) - 20      // C
            let y2 = y1 - 20                           // E
            let y3 = y2 - 20                           // G
            
            // Draw the vertical lines
            for y in [y1, y2, y3] {
                var path = Path()
                path.move(to: CGPoint(x: x0, y: y))
                path.addLine(to: CGPoint(x: width+x0, y: y))
                context.stroke(path, with: .color(.gray), lineWidth: 1)
            }
            
            // Draw the beat indicators
            var x = x0
            while (x <= x0 + width)
            {
                var path = Path()
                path.move(to: CGPoint(x: x, y: y2+6))
                path.addLine(to: CGPoint(x: x, y: y2-6))
                context.stroke(path, with: .color(.gray), lineWidth: 1)
                x = x + (measureWidth / beatsPerMeasure)
            }
            
            n += 1
        }
        
        // Draw the vertical lines
        var x = x0
        let top = y0 - (octaveRange * octaveHeight) + 10
        let bottom = y0 - 20
        while (x <= x0 + width)
        {
            var path = Path()
            path.move(to: CGPoint(x: x, y: top))
            path.addLine(to: CGPoint(x: x, y: bottom))
            context.stroke(path, with: .color(.gray), lineWidth: 1)

            x = x + measureWidth
        }
    }
    
    // -------------------------------------------------------
    // Draw a compact staff having just one horizontal line
    // -------------------------------------------------------
    func drawCompactStaff(context: GraphicsContext, x0: Int, y0: Int, width: Int) {
   
        let beatsPerMeasure = document.composition.beatsPerMeasure
        let measureWidth = getMeasureWidth()
        let y = y0 - 41
        
        var path = Path()
        path.move(to: CGPoint(x: x0, y: y))
        path.addLine(to: CGPoint(x: width+x0, y: y))
        context.stroke(path, with: .color(.gray), lineWidth: 1)
               
        var x = x0
        while (x <= x0 + width)
        {
            var path = Path()
            path.move(to: CGPoint(x: x, y: y - 20))
            path.addLine(to: CGPoint(x: x, y: y + 20))
            context.stroke(path, with: .color(.gray), lineWidth: 1)
            x = x + measureWidth
        }
        
        x = x0
        while (x <= x0 + width)
        {
            var path = Path()
            path.move(to: CGPoint(x: x, y: y - 6))
            path.addLine(to: CGPoint(x: x, y: y + 6))
            context.stroke(path, with: .color(.gray), lineWidth: 1)

            x = x + (measureWidth / beatsPerMeasure)
        }
    }
    
    // --------------------------------------------
    // Draw the staff's instrument name vertically
    // --------------------------------------------
    func drawInstrumentName(context: GraphicsContext, name: String, x0: Int, y0: Int, y1: Int) {
        if (x0 < 100) {
            let dy = 16
            let height = y1 - y0
            var y = y1 - (height/2) - (name.count * dy/2) + 12
            for letter in name {
                context.draw(Text(String(letter)).font(.system(size: 14)), at: CGPoint(x: x0-22, y: y), anchor: .center)
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
                context.draw(Text(sectionName).font(.system(size: 16)), at: CGPoint(x: x-4, y: 20), anchor: .leading)
                measureNumber = measureNumber + 1
            }
            else if (x + measureWidth <= x0 + width) {
                context.draw(Text(String(measureNumber)).font(.system(size: 16)), at: CGPoint(x: x-4, y: 20), anchor: .leading)
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
        var m = measureNumber
        
        for measure in measures {
            
            var stepCount = 0
            for step in measure.steps {
                
                if (!step.isSilence()) {
                    drawStep(context: context, x: x, y0: y0, step: step, stepCount: stepCount, measureNumber: m, isCompact: isCompact)
                }
                
                x = x + (Float(step.length) * dx)
                stepCount += step.length
            }
            m += 1
        }
    }
    
    //------------------------------------------------------
    // Get the vertical offset to be used for a sharp note
    //------------------------------------------------------
    func getSharpNoteOffset(_ step: Step, _ pos: Int) -> Int {
        
        var sharpNoteOffset = -4
        if (step.isSharp(pos: pos)) {
            sharpNoteOffset = -9
        }
        
        return sharpNoteOffset
    }
        
    //---------------------------------
    // Draw a note, interval or chord
    //---------------------------------
    func drawStep(context: GraphicsContext, x: Float, y0: Int, step: Step, stepCount: Int, measureNumber: Int, isCompact: Bool)
    {
        let beatsPerMeasure = document.composition.beatsPerMeasure
        let stepsPerBeat = document.composition.stepsPerBeat
        let measureWidth = getMeasureWidth()
        let dx = Float(measureWidth) / Float(beatsPerMeasure * stepsPerBeat)
        
        var path = Path()
        var y = y0
        
        if (isCompact) {
            y = y - 45
        }
        else if (step.positions.count > 0) {
            y = y - ((step.positions[0]+2) * 10) + getSharpNoteOffset(step, 0)
        }
        
        let width = Int(Float(step.length) * dx)
        var fillColor = Color.primary
        
        if (step.isError()) {
            fillColor = Color(cgColor: .init(gray: 0.1, alpha: 0.5))
        }
        else if (step.octave == 0 && step.isSynth() == false) {
            fillColor = .black //Color(cgColor: .init(gray: 0.7, alpha: 1))
        }
        else {
            var gradiant : Int = step.notes[0] + Int(document.composition.transposition) - 43
            if (gradiant < 0) {
                gradiant = 0
            }
            if (gradiant > 36) {
                gradiant = 36
            }
            fillColor = Color(hue: Double(gradiant) / 36 * 0.16, saturation: 1, brightness: colorScheme == .light ? 0.95 : 0.75)
        }

        var lineWidth = 4
        if (selection.step != nil && step.isEqual(selection.step!)) {
            lineWidth += 2
        }
        
        path = Path()
        path.move(to: CGPoint(x: Int(x+5), y: y+4))
        path.addLine(to: CGPoint(x: Int(x)+width-4, y: y+4))
        context.stroke(path, with: .color(fillColor), lineWidth: CGFloat(lineWidth))
        
        // Store first note position
        document.positions.append(NotePosition(x: Int(x), y: y-14, width: width, height: 20, step: step))
        
        var noteWidth = step.length + 2
        if (noteWidth > 24) {
            noteWidth = 24
        }
        
        if (!step.sustained )
        {
            if (step.isSynth() && step.positions.count > 0) {
                for n in 1...step.positions.count {
                    let y1 = y0 - ((step.positions[n-1]+2) * 10) + getSharpNoteOffset(step, n-1)
                    let isSharp = step.isSharp(pos: n-1)
                    let isChordSelection = step.isChordNote(pos: n-1, chordName: selection.chord) && measureNumber == selection.measure
                    
                    if (noteWidth < 9) {
                        path = Path()
                        path.addArc(center: CGPoint(x: Int(x+10), y: y1+4), radius: 5, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
                        context.fill(path, with: .color(.musicSheetNote))
                                
                        if (isSharp || isChordSelection) {
                            path = Path()
                            path.addArc(center: CGPoint(x: Int(x+10), y: y1+4), radius: 3, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
                            context.fill(path, with: isChordSelection ? .color(.green) : .color(fillColor))
                            
                            if (isChordSelection) {
                                context.fill(path, with: .color(.accentColor))
                            }
                            else {
                                context.fill(path, with: .color(.musicSheetSharpNote))
                            }
                        }
                    }
                    else {
                        path = Path()
                        let roundCorner = CGSize(width: 5, height: 5)
                        let rect = CGRect(x: Int(x+4), y: y1-1, width: noteWidth, height: 10)
                        path.addRoundedRect(in: rect, cornerSize: roundCorner)
                        context.fill(path, with: .color(.musicSheetNote))
                        
                        if (isSharp || isChordSelection) {
                            path = Path()
                            let rect = CGRect(x: Int(x+6), y: y1+1, width: noteWidth-4, height: 6)
                            path.addRoundedRect(in: rect, cornerSize: roundCorner)
                            
                            if (isChordSelection) {
                                context.fill(path, with: .color(.accentColor))
                            }
                            else {
                                context.fill(path, with: .color(.musicSheetSharpNote))
                            }
                        }
                    }
                    
                    // Draw a dashed line beteen notes of an interval
                    if (n > 1 && y - y1 > 10) {
                        var dx = 10
                        if (noteWidth > 12) {
                            dx = 4 + (noteWidth/2)
                        }
                        path = Path()
                        path.move(to: CGPoint(x: Int(x)+dx, y: y-2))
                        path.addLine(to: CGPoint(x: Int(x)+dx, y: y1+9))
                        context.stroke(path, with: .color(fillColor), style: .init(lineWidth: 2.5, dash: [8, 2]))
                    }
                    y = y1
                }
            }
        }
  
        if (!step.isSilence() && !step.sustained && !step.isSynth()) {
            let xOffset = 5 // noteWidth + 3
            context.draw(Text(step.text).font(.system(size: 16)).monospaced().foregroundStyle(.primary), at: CGPoint(x: Int(x)+xOffset, y: y-8), anchor: .leading)
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
                    let y = y0 + 15
                    let offset = (Float(step.length > stepsPerBeat ? stepsPerBeat : step.length) * dx) / 2
                    
                    if (!step.sustained) {
                        context.draw(Text(step.text).font(.system(size: 14)).foregroundStyle(.primary), at: CGPoint(x: Int(x+offset), y: y), anchor: .center)
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
    
                if (step.isText()) {
                    let y = y0
                    var text = Text(step.text).font(.system(size: 14)).monospaced().foregroundStyle(.primary)
                        
                    
                    if (selection.step != nil && step.isEqual(selection.step!)) {
                        text = text.bold()
                    }
                    
                    context.draw(text, at: CGPoint(x: Int(x+(width/2)), y: y+15), anchor: .center)
                }
                
                var path = Path()
                path.move(to: CGPoint(x: Int(x+4), y: y0-10))
                path.addLine(to: CGPoint(x: Int(x+4), y: y0))
                path.addLine(to: CGPoint(x: Int(x+width-4), y: y0))
                path.addLine(to: CGPoint(x: Int(x+width-4), y: y0-10))
                context.stroke(path, with: .color(.gray), lineWidth: 1)
                
                document.positions.append(NotePosition(x: Int(x), y: y0-10, width: Int(width), height: 50, step: step))
                
                x = x + width
                stepCount += step.length
                
            }
        }
    }
}
