//
//  PlaylistItem.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import UniformTypeIdentifiers

// ----------------------------------------------------------------
// A playlist item identifies a song section
// ----------------------------------------------------------------
struct PlaylistItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var isSelected = true
}
