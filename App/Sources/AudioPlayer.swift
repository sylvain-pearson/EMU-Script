//
//  AudioPlayer.swift
//  EmuScript
//
//  Copyright (c) 2026 Sylvain Pearson - Licensed under the MIT license
//  Source code repository: https://github.com/sylvain-pearson/EMU-Script
//

import AVFoundation

// ---------------------------------------------------
// An audio player that can overlap audio playbacks
// ---------------------------------------------------
class AudioPlayer {
    
    private var players: [AVAudioPlayer] = []
    private var currentPlayer: Int = 0
    private var isOk = true

    // -----------------------------------------------------------
    // Initialize the audio player and get prepared for playback
    // -----------------------------------------------------------
    init(fileName: String, volume: Int) {
        let documentsURL = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        let url = documentsURL.appendingPathComponent(fileName)
        
        var volumeInPercent = Float(volume) / 100
        if (volumeInPercent > 1) {
            volumeInPercent = 1
        }
        else if (volumeInPercent < 0){
            volumeInPercent = 0
        }
        
        var n = 3
        while (n > 0) {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.setVolume(volumeInPercent, fadeDuration: 0)
                players.append(player)
                n -= 1
            }
            catch  {
                isOk = false
                n = 0
            }
        }
    }
    
    // -----------------------------------
    // Play the audio file
    // -----------------------------------
    func play() {
        currentPlayer += 1
        if (currentPlayer >= players.count) {
            currentPlayer = 0
        }
        if (players.count > 0) {
            players[currentPlayer].play()
        }
    }
    
    // ----------------------------------------
    // Check if the audio player is in error
    // ----------------------------------------
    func isError() -> Bool {
        return !isOk
    }
}
