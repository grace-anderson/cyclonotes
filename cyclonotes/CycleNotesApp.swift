//
//  CycleNotesApp.swift
//  cyclonotes
//
//  Created by Helen Anderson on 24/9/2025.
//

import Foundation
import SwiftUI
import SwiftData
import TelemetryDeck
import UIKit

@main
struct CycleNotesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
            let config = TelemetryDeck.Config(appID: "3C3CFCEF-E386-4489-8ED0-E043B18C7E4D")
            TelemetryDeck.initialize(config: config)
        }
    
    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(for: [Ride.self, RoutePoint.self, RideNote.self, RidePhoto.self])
    }
}
