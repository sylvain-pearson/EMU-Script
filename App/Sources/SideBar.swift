//
//  SideBar.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import SwiftUI
import Foundation

// -----------------------------------------------------
// A playlist item row with a checkbox
// -----------------------------------------------------
struct PlaylistRow: View {
    
    let name: String
    let id : UUID
    @State var isSelected : Bool
    var onChange: (UUID, Bool) -> Void
    var refreshMusicSheet: () -> Void
                        
    var body: some View {
        HStack {
            
            Toggle(isOn: $isSelected) {
                Text(name)
            }
            .onChange(of: isSelected) { oldValue, newValue in
                onChange(id, isSelected)
                refreshMusicSheet()
            }
        }
    }
}

// ---------------------------------------------------------
// A instrument item row with a checkbox and a mute button
// ---------------------------------------------------------
struct InstrumentRow: View {
    
    let name: String
    let id : UUID
    @State var isSelected : Bool
    @State var isMuted : Bool
    var onChange: (UUID, Bool, Bool) -> Void
    var refreshMusicSheet: () -> Void
                        
    var body: some View {
        HStack {
            
            Toggle(isOn: $isSelected) {
                HStack {
                    Text(name)
                    Spacer()
                    Toggle(isOn: $isMuted) {
                        if (isMuted) {
                            Image(systemName: "speaker.slash")
                        }
                        else {
                            Image(systemName: "speaker.wave.2")
                        }
                    }.toggleStyle(.button)
                }
            }
            .onChange(of: isSelected) { oldValue, newValue in
                onChange(id, isSelected, isMuted)
                refreshMusicSheet()
            }
            .onChange(of: isMuted) { oldValue, newValue in
                onChange(id, isSelected, isMuted)
                refreshMusicSheet()
            }
        }
    }
}

// ------------------------------------
// Definition of the side bar view
// ------------------------------------
struct Sidebar: View {

    @Binding var document: EmuScriptDocument
    @Binding var isEditing: Bool
    let refresh: () -> Void
    
    var propertiesTitle : String = ""
    
    var body: some View {
        
        List {
            // The playlist
            Section(header: Text("Playlist").font(.headline)) {
                ForEach (document.playlist) {
                    PlaylistRow(name: $0.name, id: $0.id, isSelected: $0.isSelected,
                                onChange: document.onPlaylistSelection,
                                refreshMusicSheet: refresh)
                }
            }
            // The list on instruments
            Section(header: Text("Instruments").font(.headline)) {
                ForEach (document.instruments) {
                    InstrumentRow(name: $0.name, id: $0.id, isSelected: $0.isSelected, isMuted: $0.isMuted,
                                  onChange: document.onInstrumentSelection,
                                  refreshMusicSheet: refresh)
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 250).listStyle(.sidebar)
#endif
        
#if os(macOS)
        // The Step or documentproperties
        if (document.parser.errors.isEmpty || document.properties.isSelection) {
            VStack(alignment: .leading, spacing: 3) {
                Divider()
                Text(document.properties.text).font(.headline).opacity(0.7)
                ForEach (document.properties.items) { property in
                    Text(String("- ") + property.name + property.separator + property.value)
                }
            }
            .padding(.all, 10)
        }
#endif

    }
}
