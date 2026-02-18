//
//  ContentView.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import SwiftUI
import AppKit
import Foundation

struct ContentView: View {
    
    @Binding var document: EmuScriptDocument
    
    @State var refreshCounter = true
    @State var showError = false
    @State var error = ScriptError()
    @State var scrollPosition: Int?
    @State var stepCountProgress = -1
    @State var selectedStep : Step?
    @State var beatsPerMeasure = 4
    @State var measureWidth = 26*12
    @State var stepsPerBeat = 4
    @State var properties : Properties = Properties()
    @State var thread : SequencerThread?
    
    @State var showTextEditor : Bool = false
    @State var selection = AttributedTextSelection()
    @State var keyPressed : Character?
    
    let measureHeight = 190
    let margin = 40
    
    // -------------------------------------------------------------------
    // Definition of the main view : a canvas, a side bar and a toolbar
    // -------------------------------------------------------------------
    var body: some View {
        
        NavigationSplitView {
            Sidebar(document: $document.wrappedValue, refreshCanvas: refresh, properties: properties)
        }
        detail: {
            ZStack {
                TextEditor(text: $document.richText, selection: $selection).font(.system(size: 16)).monospaced()
                    .onKeyPress(action: { press in
                        keyPressed = press.characters.first
                        return .ignored
                    })
                    .onChange(of: document.richText) { oldValue, newValue in
                        if (keyPressed != nil) {
                            document.onUpdate(newValue, reload: keyPressed! == "\r")
                            keyPressed = nil
                        }
                    }.opacity(showTextEditor ? 1 : 0)

                ScrollView(.horizontal, showsIndicators: true) {
                    ZStack(alignment: .leading) {
                        HStack(spacing:0) {
                            ForEach(0..<100) { index in
                                Rectangle().stroke(Color.clear, lineWidth: 1.0).frame(width: CGFloat(getMeasureWidth())).id(index)
                            }
                        }
                        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: false) { context, size in
                            draw(context: context, size: size)
                        }
                        .frame(width: (Double(measureWidth) * Double(document.measuresCount)) + Double(margin*2))
                        .onTapGesture { location in
                            selectStep(at: location)
                        }
                    }
                }.opacity(showTextEditor ? 0 : 1)
            }
        }
        .scrollPosition(id: $scrollPosition, anchor: .leading)
        .alert(String(localized: "Runtime Error"), isPresented: $showError) { }  message: {
            Text(error.getMessage())
        }.dialogIcon(Image(systemName: "exclamationmark.circle.fill"))
        
        // The toolbar
        .toolbar {
            ToolbarItemGroup {
                HStack {
                    
                    Toggle(isOn: $showTextEditor){ Label("Text Editor", systemImage: "doc.text") }
                        .onChange(of: showTextEditor) {
                            if (showTextEditor) { clearSelection() }
                        }
                        .disabled((thread != nil && thread!.isExecuting))
                    
                    Divider()
                    
                    Button(action: play) { Label("Play", systemImage: "play.fill") }
                        .keyboardShortcut(.defaultAction)
                        .disabled((thread != nil && thread!.isExecuting) || showTextEditor)

                    Button(action: stop) { Label("Stop", systemImage: "stop.fill") }
                        .keyboardShortcut(.cancelAction)
                        .disabled(thread == nil || thread!.isFinished || showTextEditor)
                    
                    Divider()
                    
                    Button(action: scrollLeft) { Label("Scroll Left", systemImage: "chevron.left") }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                        .disabled((thread != nil && thread!.isExecuting) || scrollPosition == nil || scrollPosition! == 0 || showTextEditor)
                    
                    Button(action: scrollRight) { Label("Scroll Right", systemImage: "chevron.right") }
                        .keyboardShortcut(.rightArrow, modifiers: [])
                        .disabled((thread != nil && thread!.isExecuting) || (scrollPosition != nil && scrollPosition! > document.measuresCount-3) || showTextEditor)
                }
            }
        }.frame(minWidth: 1200, minHeight: 600)
    }

    // ---------------------------------
    // Returns the width oif a measure
    // ---------------------------------
    func getMeasureWidth() -> Int {
        return document.composition.beatsPerMeasure * document.composition.stepsPerBeat * 10
    }
    
    // -------------------------------------------------------
    // Start playing the composition in a background thread
    // -------------------------------------------------------
    func play() {
        scrollPosition = 0
        thread = SequencerThread(document: document, scrollFunc: self.scroll)

        if (thread != nil) {
            error = thread!.prepare()
            if (error.isErr()) {
                showError = true
            }
            else {
                thread!.start()
            }
        }
    }
    
    // -------------------------------------------------------
    // Stop playing the composition
    // -------------------------------------------------------
    func stop() {
        if (thread != nil) {
            thread!.cancel()
        }
    }
    
    // -------------------------------------------------------
    // Scroll right by 3 measures
    // -------------------------------------------------------
    func scrollRight() {
        if (scrollPosition == nil) {
            scrollPosition = 0
        }
        scrollPosition! += 3
        if (scrollPosition! >= document.measuresCount) {
            scrollPosition = document.measuresCount - 2
        }
    }
    
    // -------------------------------------------------------
    // Scroll left by 3 measures
    // -------------------------------------------------------
    func scrollLeft() {
        if (scrollPosition == nil) {
            scrollPosition = 0
        }
        scrollPosition! -= 3
        if (scrollPosition! < 0) {
            scrollPosition = 0
        }
    }
    
    // ---------------------------------
    // Force a refresh of the view
    // ---------------------------------
    func refresh() {
        error = ScriptError()
        refreshCounter.toggle()
    }

    // -----------------------------------------------
    // Scroll to a specific position on the staff
    // -----------------------------------------------
    func scroll(position: Int) {
        stepCountProgress = position
        let newPos = position/(beatsPerMeasure * stepsPerBeat)
        if (scrollPosition == nil || newPos > scrollPosition! + 1) {
            scrollPosition = newPos
        }
    }
    
    // -------------------------------------------------------------------------------------------
    // This function is called when the user clicks on the canvas.
    // When the user clicks on a step, the properties of the step are displayed in the side bar
    // -------------------------------------------------------------------------------------------
    func selectStep(at: CGPoint) {
        for item in document.playlist {
            if (item.isSelected) {
                for pos in document.positions {

                    if (Int(at.x) > pos.x - 10 && Int(at.x) < pos.x + pos.width && Int(at.y) > pos.y - 10 && Int(at.y) < pos.y + pos.height) {
                        selectedStep = pos.step
                        properties =  selectedStep!.getProperties(transposition: document.composition.transposition)
                        properties.isSelection = true
                        break
                    }
                    else {
                        clearSelection()
                    }
                }
            }
        }
    }
    
    //-------------------------------------
    // Clears the currently selected step
    //-------------------------------------
    func clearSelection() {
        properties = document.composition.getProperties()
        properties.isSelection = false
        selectedStep = nil
    }
    
    // ------------------------------------------------------
    // Draw the staffs and notes of the composition
    // ------------------------------------------------------
    func draw(context: GraphicsContext, size: CGSize) {

        var x = margin
        var measureNumber = 1
      
        beatsPerMeasure = document.composition.beatsPerMeasure
        stepsPerBeat = document.composition.stepsPerBeat
        measureWidth = getMeasureWidth()
        
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
                
                let m = stepCountProgress / beatsPerMeasure / stepsPerBeat
                let n = measureNumber
                let drawSection = (m <= 0) || (m >= n-1 && m <= n + sectionLength) || (m+3 >= n-1 && m+3 <= n + sectionLength)
                
                if (drawSection) {
                    
                    for n in 0..<document.instruments.count  {
                        // Partitions of first two instruments are always visible
                        if ((document.instruments[n].isSelected || instrumentNumber < 3)) {
                            
                            let isDrum = document.instruments[n].isDrum()
                            let isSampler = document.instruments[n].isSampler()
                            instrumentNumber += 1
                            
                            if (isDrum || isSampler) {
                                drawCompactStaff(context: context, x0: x, y0: y-20, width: width)
                            }
                            else {
                                drawStaff(context: context, x0: x, y0: y, width: width, octave: document.instruments[n].octave)
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
                }
                
                drawMeasureNumbers(context: context, x0: x, width: width, sectionName: item.name, measureNumber: &measureNumber)
                
                x = x + width
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // Draw a staff having 4 horizontal lines and one vertical line per measure
    // ----------------------------------------------------------------------------
    func drawStaff(context: GraphicsContext, x0: Int, y0: Int, width: Int, octave: UInt8) {

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
    
    // -------------------------------------------------------
    // Draw the measure numbers and the section names
    // -------------------------------------------------------
    func drawMeasureNumbers(context: GraphicsContext, x0: Int, width: Int, sectionName: String, measureNumber: inout Int) {

        var x = x0

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
        
        let dx = Float(measureWidth) / Float(beatsPerMeasure * stepsPerBeat)
        var x = Float(x0)
        var m = measureNumber - 1
        
        let playedMeasure = stepCountProgress / beatsPerMeasure / stepsPerBeat
        
        for measure in measures {
            
            let drawMeasure = (playedMeasure <= 0) || (m >= playedMeasure-1 && m < playedMeasure + 4)
            
            var stepCount = 0
            for step in measure.steps {
                
                if (!step.isSilence() && drawMeasure) {
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
        
        if ((measureCount * beatsPerMeasure * stepsPerBeat) + stepCount > stepCountProgress)
        {
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
extension NSTextView {
    // HACK to work-around the smart quote issue
    open override var frame: CGRect {
        didSet {
            self.isAutomaticQuoteSubstitutionEnabled = false
            self.isAutomaticDashSubstitutionEnabled = false
            self.isAutomaticTextReplacementEnabled = false
            self.isAutomaticTextCompletionEnabled = false
            self.isAutomaticSpellingCorrectionEnabled = false
            self.isAutomaticDataDetectionEnabled = false
            self.isAutomaticLinkDetectionEnabled = false
            self.smartInsertDeleteEnabled = false
            self.isGrammarCheckingEnabled = false
            self.isContinuousSpellCheckingEnabled = false
        }
    }
}

#Preview {
    ContentView(document: .constant(EmuScriptDocument()))
}
