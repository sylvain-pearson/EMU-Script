//
//  ContentView.swift
//  EmuScript
//
//  Created by Sylvain Pearson on 2026-01-07.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: EmuScriptDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(EmuScriptDocument()))
}
