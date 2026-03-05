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
    @State var scrollPosition = ScrollPosition(edge: .top)
    @State var stepCountProgress = 0
    @State var selectedStep : Step?
    @State var properties : Properties = Properties()
    @State var sequencer : SequencerThread?
    
    @State var showTextEditor : Bool = false
    @State var selection = AttributedTextSelection()
    @State var keyPressed : Character?
    @State var progress = -1.0
    
    let measureHeight = 190
    let margin = 40
    
    // -------------------------------------------------------------------
    // Definition of the main view : a canvas, a side bar and a toolbar
    // -------------------------------------------------------------------
    var body: some View {
        
        NavigationSplitView {
            Sidebar(document: $document, refreshCanvas: refresh, properties: properties)
        }
        detail: {
            ZStack {
                MusicSheetProgress(document: $document, progress: $progress).opacity(showTextEditor ? 0 : 0.5)

                ScrollView(.horizontal, showsIndicators: true) {
                        MusicSheetView(document: $document, selectedStep: $selectedStep, properties: $properties, refreshCounter: $refreshCounter)
                            .onTapGesture { location in selectStep(at: location) }
                }
                .opacity(showTextEditor ? 0 : 1).scrollPosition($scrollPosition)
                
                ScriptEditor(document: $document, reload: $document.reloadCounter).opacity(showTextEditor ? 1 : 0)
            }
        }
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
                        .disabled((sequencer != nil && sequencer!.isExecuting))
                    
                    Divider()
                    
                    Button(action: play) { Label("Play", systemImage: "play.fill") }
                        .keyboardShortcut(.defaultAction)
                        .disabled((sequencer != nil && sequencer!.isExecuting) || showTextEditor)

                    Button(action: stop) { Label("Stop", systemImage: "stop.fill") }
                        .keyboardShortcut(.cancelAction)
                        .disabled(sequencer == nil || sequencer!.isFinished || showTextEditor)
                    
                    Divider()
                    
                    Button(action: scrollLeft) { Label("Scroll Left", systemImage: "chevron.left") }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                        .disabled((sequencer != nil && sequencer!.isExecuting) || (scrollPosition.x != nil && scrollPosition.x == 0) || showTextEditor)
                    
                    Button(action: scrollRight) { Label("Scroll Right", systemImage: "chevron.right") }
                        .keyboardShortcut(.rightArrow, modifiers: [])
                        .disabled((sequencer != nil && sequencer!.isExecuting) || showTextEditor ||
                                  (scrollPosition.x != nil && Int(scrollPosition.x!) > (document.measuresCount-3)*getMeasureWidth()))
                }
            }
        }.frame(minWidth: 1200, minHeight: 600)
    }

    // ---------------------------------
    // Returns the width of a measure
    // ---------------------------------
    func getMeasureWidth() -> Int {
        return document.composition.beatsPerMeasure * document.composition.stepsPerBeat * 10
    }
    
    // -------------------------------------------------------
    // Start playing the composition in a background thread
    // -------------------------------------------------------
    func play() {
        scroll(position: 0)
        
        sequencer = SequencerThread(document: document, scrollFunc: self.scroll)

        if (sequencer != nil) {
            error = sequencer!.prepare()
            if (error.isErr()) {
                showError = true
            }
            else {
                sequencer!.start()
            }
        }
    }
    
    // -------------------------------------------------------
    // Stop playing the composition
    // -------------------------------------------------------
    func stop() {
        if (sequencer != nil) {
            sequencer!.cancel()
        }
    }
    
    // -------------------------------------------------------
    // Scroll right by 3 measures
    // -------------------------------------------------------
    func scrollRight() {
        var newPosition = 0
        
        if (scrollPosition.x != nil) {
            newPosition = Int(scrollPosition.x!) + (document.composition.beatsPerMeasure * document.composition.stepsPerBeat * 3 * 10)
        }
        self.scrollPosition.scrollTo(x: CGFloat(newPosition))
    }
    
    // -------------------------------------------------------
    // Scroll left by 3 measures
    // -------------------------------------------------------
    func scrollLeft() {
        var newPosition = 0
        
        if (scrollPosition.x != nil) {
            newPosition = Int(scrollPosition.x!) - (document.composition.beatsPerMeasure * document.composition.stepsPerBeat * 3 * 10)
            if (newPosition < 0) {
                newPosition = 0
            }
        }
        self.scrollPosition.scrollTo(x: CGFloat(newPosition))
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
        
        let stepsPerMeasure = document.composition.stepsPerBeat * document.composition.beatsPerMeasure
        
        if (position % (stepsPerMeasure * 3) == 0) {
            self.scrollPosition.scrollTo(x: CGFloat(position*10))
        }
        
        self.progress = (Double((position % (stepsPerMeasure * 3)))) / Double(stepsPerMeasure * 3)
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
