//
//  RootView.swift
//  cyclonotes
//
//  Created by Helen Anderson on 24/9/2025.
//

import Foundation
import SwiftUI

struct RootView: View {
    @StateObject private var recorder = RideRecorder()

    var body: some View {
        TabView {
            RecordRideView()
                .tabItem { Label("Record", systemImage: "dot.radiowaves.left.and.right") }
                .environmentObject(recorder)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
        }
        .onAppear { recorder.requestAuthorization() }
    }
}
