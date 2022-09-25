//
//  A_Basic_Audio_UnitApp.swift
//  A Basic Audio Unit
//
//  Created by Aura Audio on 9/25/22.
//

import CoreMIDI
import SwiftUI

@main
class A_Basic_Audio_UnitApp: App {
    @ObservedObject private var hostModel = AudioUnitHostModel()

    required init() {}

    var body: some Scene {
        WindowGroup {
            ContentView(hostModel: hostModel)
        }
    }
}
