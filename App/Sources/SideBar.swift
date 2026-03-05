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
    var refresh: () -> Void
                        
    var body: some View {
        HStack {
            Toggle(isOn: $isSelected) {
                Text(name)
            }
            .onChange(of: isSelected) { oldValue, newValue in
                onChange(id, isSelected)
                refresh()
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
    var refresh: () -> Void
                        
    var body: some View {
        HStack {
               
            Toggle(isOn: $isSelected) {
                Text(name)
            }
            .onChange(of: isSelected) { oldValue, newValue in
                onChange(id, isSelected, isMuted)
                isMuted = !isSelected
                refresh()
            }
            .onChange(of: isMuted) { oldValue, newValue in
                onChange(id, isSelected, isMuted)
                refresh()
            }

            Spacer()
            
            Toggle(isOn: $isMuted) {
                if (isMuted) {
                    Text("M")
                }
                else {
                    Text("M").foregroundColor(.gray)
                }
            }.toggleStyle(.button).frame(width: 25)
        }
    }
}

// ------------------------------------
// Definition of the side bar view
// ------------------------------------
struct Sidebar: View {

    @Binding var document: EmuScriptDocument
    let refreshCanvas: () -> Void
    var properties : Properties
    
    var propertiesTitle : String = ""
    
    var body: some View {
        
        List {
            // The playlist
            Section(header: Text("Playlist").font(.headline)) {
                ForEach (document.playlist) {
                    PlaylistRow(name: $0.name, id: $0.id, isSelected: $0.isSelected, onChange: document.onPlaylistSelection, refresh: refreshCanvas)
                }
            }
            // The list on instruments
            Section(header: Text("Instruments").font(.headline)) {
                ForEach (document.instruments) {
                    InstrumentRow(name: $0.name, id: $0.id, isSelected: $0.isSelected, isMuted: $0.isMuted, onChange: document.onInstrumentSelection, refresh: refreshCanvas)
                }
            }
        }.frame(minWidth: 250).listStyle(.sidebar)
        
        // The Step properties
        if (document.parser.errors.isEmpty || properties.isSelection) {
            VStack(alignment: .leading, spacing: 3) {
                Divider()
                Text(properties.text).font(.headline).opacity(0.7)
                ForEach (properties.items) { property in
                    Text(String("- ") + property.name + property.separator + property.value)
                }
            }.padding(.all, 10)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text("Error" + (document.parser.errors.count==1 ? "" : "s")).font(.headline)
                ForEach (document.parser.errors.prefix(5)) { error in
                    Divider()
                    Text("- " + error.getMessageAndLineNumber())
                }
            }.padding(.all, 10)
        }
    }
}
