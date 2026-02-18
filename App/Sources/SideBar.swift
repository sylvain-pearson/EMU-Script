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
// A view with a check box and some text displayed
// -----------------------------------------------------
struct CheckboxRow: View {
    
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
            .toggleStyle(.checkbox)
        }
    }
}


// ------------------------------------
// Definition of the side bar view
// ------------------------------------
struct Sidebar: View {

    var document: EmuScriptDocument
    let refreshCanvas: () -> Void
    var properties : Properties
    
    var propertiesTitle : String = ""
    
    var body: some View {
        
        List {
            // The playlist
            Section(header: Text("Playlist").font(.headline)) {
                ForEach (document.playlist) {
                    CheckboxRow(name: $0.name, id: $0.id, isSelected: $0.isSelected, onChange: document.onPlaylistSelection, refresh: refreshCanvas)
                }
            }
            // The list on instruments
            Section(header: Text("Instruments").font(.headline)) {
                ForEach (document.instruments) {
                    CheckboxRow(name: $0.name, id: $0.id, isSelected: $0.isSelected, onChange: document.onInstrumentSelection, refresh: refreshCanvas)
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
