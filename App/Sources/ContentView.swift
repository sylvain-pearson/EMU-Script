//
//  ContentView.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import SwiftUI
import Foundation

struct Selection {
    var step : Step?
    var chord : String = ""
    var measure : Int = 0
}


struct ContentView: View {
    
    @Binding var document: EmuScriptDocument
    
    @State var refreshCounter = true
    @State var showError = false
    @State var error = ScriptError()
    @State var scrollPosition = ScrollPosition(edge: .top)
    @State var stepCountProgress = 0
    @State var sequencer : SequencerThread?
    @State var selection = Selection()
    
    @State var showTextEditor : Bool = true
    @State var selectedText = AttributedTextSelection()
    @State var keyPressed : Character?
    @State var progress = -1.0
    @State var scrollByCount = 3
    @State var metronomeUnit = 2
    @State var zoomFactor = 1.0
    
    @FocusState var isTextEditorFocused: Bool
    @State var isTextEditorDisabled = false
    @Environment(\.colorScheme) var colorScheme
    
#if os(macOS)
    @State private var sideBarVisibility = NavigationSplitViewVisibility.doubleColumn
#else
    @State private var sideBarVisibility = NavigationSplitViewVisibility.detailOnly
#endif
    
    let chords = Chords()
    let measureHeight = 190
    let margin = 40
    let stepWidth = 8
    
    // -------------------------------------------------------------------
    // Definition of the main view : a canvas, a side bar and a toolbar
    // -------------------------------------------------------------------
    var body: some View {
        
        NavigationSplitView(columnVisibility: $sideBarVisibility) {
            Sidebar(document: $document, isEditing: $showTextEditor, refresh: refresh)
        }
        detail: {
            ZStack  {
                MusicSheetProgress(document: $document, scrollByCount: $scrollByCount, progress: $progress, zoomFactor: $zoomFactor)
                    .opacity(showTextEditor ? 0 : 0.6)
                    .scaleEffect(zoomFactor, anchor: .topLeading)
                
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    MusicSheetView(document: $document, selection: $selection, refreshCounter: $refreshCounter)
                        .onTapGesture { location in selectStep(at: location) }
                }
                .opacity(showTextEditor ? 0 : 1)
                .scrollPosition($scrollPosition)
                .scaleEffect(zoomFactor, anchor: .topLeading)
                
               HStack {
                    ScriptEditor(document: $document, reload: $document.reloadCounter)
                        .opacity(showTextEditor ? 1 : 0)
                        .focused($isTextEditorFocused)
                        .disabled(isTextEditorDisabled)
                }
            }
            
        }
        .alert(String(localized: "Sequencer Error"), isPresented: $showError) { }  message: {
            Text(error.getMessage())
        }.dialogIcon(Image(systemName: "exclamationmark.circle.fill"))
        
        // Workaround for a SwiftUI bug (the toolbar appearing as light in dark mode)
        .toolbarColorScheme(colorScheme, for: .automatic)

        // The toolbar
        .toolbar {
#if os(macOS)
            if (document.parser.errors.count > 0) {
                ToolbarItemGroup(placement: .status)  {
                    Button(action: reload) { Label("Text Editor", systemImage: "exclamationmark") } .foregroundStyle(.scriptError).bold()
                    Text(document.parser.getErrorMessage()).padding(.trailing, 10).font(.title3)
                }
            }
#endif
            ToolbarItemGroup  {
                HStack {
#if os(iOS)
                    Button(action: toggleSidebar) { Label("Sidebar", systemImage: "sidebar.left") }
                    Spacer()
#endif
                    if (showTextEditor) {
                        Button(action: toggleTextEditor) { Label("Text Editor", systemImage: "music.note.list") }
                    }
                    else {
                        Button(action: toggleTextEditor) { Label("Text Editor", systemImage: "doc.text") }
                            .foregroundStyle(document.parser.errors.count > 0 ? .scriptError : .primary)
                    }
                    Divider()

                    Button(action: play) { Label("Play", systemImage: "play.fill") }
                        .keyboardShortcut(.defaultAction)
                        .disabled((sequencer != nil && sequencer!.isExecuting))

                    Button(action: stop) { Label("Stop", systemImage: "stop.fill") }
                        .keyboardShortcut(.cancelAction)
                        .disabled(sequencer == nil || sequencer!.isFinished)
                    
                    Menu {
                        Button(action: { zoomFactor = 1 }) {
                            Label("100%", systemImage: zoomFactor == 1 ? "circle.fill" : "circle")
                        }
                        Button(action: { zoomFactor = 1.1 }) {
                            Label("110%", systemImage: zoomFactor == 1.1 ? "circle.fill" : "circle")
                        }
                        Button(action: { zoomFactor = 1.2 }) {
                            Label("120%", systemImage: zoomFactor == 1.2 ? "circle.fill" : "circle")
                        }
                        Button(action: { zoomFactor = 1.3 }) {
                            Label("130%", systemImage: zoomFactor == 1.3 ? "circle.fill" : "circle")
                        }
                    }
                    label: {
                        Label("Zoom", systemImage: "magnifyingglass")
                    }
                    .disabled((sequencer != nil && sequencer!.isExecuting) || showTextEditor)
                    
                    Menu {
                        Button(action: { metronomeUnit = 1 }) {
                            Label("At Every Beat", systemImage: metronomeUnit == 1 ? "circle.fill" : "circle")
                        }
                        Button(action: { metronomeUnit = 2 }) {
                            Label("Half Beat", systemImage: metronomeUnit == 2 ? "circle.fill" : "circle")
                        }
                        Button(action: { metronomeUnit = 3 }) {
                            Label("3 per Beat", systemImage: metronomeUnit == 3 ? "circle.fill" : "circle")
                        }
                        Button(action: { metronomeUnit = 4 }) {
                            Label("4 per Beat", systemImage: metronomeUnit == 4 ? "circle.fill" : "circle")
                        }
                    }
                    label: {
                        Label("Metronome", systemImage: "timer")
                    }
                    .disabled((sequencer != nil && sequencer!.isExecuting) || showTextEditor)
                    
#if os(macOS)
                    Divider()
                    
                    Button(action: scrollLeft) { Label("Scroll Left", systemImage: "chevron.left") }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                        .disabled((sequencer != nil && sequencer!.isExecuting) || (scrollPosition.x != nil && scrollPosition.x == 0) || showTextEditor)
                    
                    Button(action: scrollRight) { Label("Scroll Right", systemImage: "chevron.right") }
                        .keyboardShortcut(.rightArrow, modifiers: [])
                        .disabled((sequencer != nil && sequencer!.isExecuting) || showTextEditor ||
                                  (scrollPosition.x != nil && Int(scrollPosition.x!) > (document.measuresCount-3)*getMeasureWidth()))
#endif
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 1920 * 0.60, minHeight: 1080 * 0.60, alignment: .topLeading)
        
        // App store required size. Hold Option key when doing the capture
        // .frame(minWidth: (2880) / 2, minHeight: (1800 - 104) / 2)
#else
        .frame(alignment: .topLeading)
#endif
    }

    // ---------------------------------
    // Returns the width of a measure
    // ---------------------------------
    func getMeasureWidth() -> Int {
        return document.composition.beatsPerMeasure * document.composition.stepsPerBeat * stepWidth
    }
    
    func toggleSidebar() {
        if (sideBarVisibility == .detailOnly) {
            sideBarVisibility = .doubleColumn
        }
        else {
            sideBarVisibility = .detailOnly
        }
    }
    
    func toggleTextEditor() {
        showTextEditor.toggle()
        onChangeOfTextEditor(showTextEditor)
    }
    
    // -------------------------------------------------------
    // Start playing the composition in a background thread
    // -------------------------------------------------------
    func play() {
        
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
    // Scroll right
    // -------------------------------------------------------
    func scrollRight() {
        var newPosition = 0
        
        if (scrollPosition.x != nil) {
            newPosition = Int(scrollPosition.x!) + (document.composition.beatsPerMeasure * document.composition.stepsPerBeat * self.scrollByCount * self.stepWidth)
        }
        self.scrollPosition.scrollTo(x: CGFloat(newPosition))
    }
    
    // -------------------------------------------------------
    // Scroll left
    // -------------------------------------------------------
    func scrollLeft() {
        var newPosition = 0
        
        if (scrollPosition.x != nil) {
            newPosition = Int(scrollPosition.x!) - (document.composition.beatsPerMeasure * document.composition.stepsPerBeat * self.scrollByCount * self.stepWidth)
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
    
    // -------------------------------------
    // Parse and validate the the document
    // -------------------------------------
    func reload() {
        document.loadDocument()
        refresh()
    }

    // -------------------------------------------------------------
    // Set the focus on the text editor or on the music sheet view
    // -------------------------------------------------------------
    func onChangeOfTextEditor(_ showTextEditor : Bool) {
        if (showTextEditor) {
            clearSelection()
            isTextEditorFocused = true
            isTextEditorDisabled = false
        }
        else {
            refreshCounter.toggle()
            isTextEditorFocused = false
            isTextEditorDisabled = true
        }
    }
    
    // -----------------------------------------------
    // Scroll to a specific position on the staff
    // -----------------------------------------------
    func scroll(position: Int) {
        
        if (position % (12 / metronomeUnit) == 0) {
            let stepsPerMeasure = document.composition.stepsPerBeat * document.composition.beatsPerMeasure
            
            if (position % (stepsPerMeasure * self.scrollByCount) == 0) {
                self.scrollPosition.scrollTo(x: CGFloat(position * self.stepWidth), y: 0)
            }
            
            self.progress = (Double((position % (stepsPerMeasure * self.scrollByCount)))) / Double(stepsPerMeasure * self.scrollByCount)
        }
        else if (position == -1) {
            self.progress = -1
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
                        selection.step = pos.step
                        selection.chord = selection.step!.isText() ? selection.step!.text : ""
                        selection.measure = ((Int(at.x) - margin) / getMeasureWidth()) + 1
                        document.properties =  selection.step!.getProperties()
                        document.properties.isSelection = true
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
        document.properties = document.composition.getProperties()
        document.properties.isSelection = false
        selection.step = nil
        selection.chord = ""
        selection.measure = 0
    }
}
#if os(macOS)
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
#endif

#Preview {
    ContentView(document: .constant(EmuScriptDocument()))
}
