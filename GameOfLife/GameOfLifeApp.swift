//
//  GameOfLifeApp.swift
//  GameOfLife
//
//  Created by Andreas Atle on 12/13/24.
//

import SwiftUI

@main
struct GameOfLifeApp: App {
    var body: some Scene {
        WindowGroup {
            GameOfLifeView(width: 600, height: 600, gridX: 512, gridY: 512)
        }
    }
}
