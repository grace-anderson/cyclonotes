//
//  CycleNotesApp.swift
//  cyclonotes
//
//  Created by Helen Anderson on 24/9/2025.
//

import Foundation
import SwiftUI
import SwiftData

@main
struct CycleNotesApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(for: [Ride.self, RoutePoint.self, RideNote.self, RidePhoto.self])
    }
}
