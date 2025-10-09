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
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false
    @State private var selectedTab: Int = 0
    @State private var showOnboarding: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
            RecordRideView()
                .tabItem { Label("Record", systemImage: "dot.radiowaves.left.and.right") }
                .environmentObject(recorder)
                .tag(0)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(1)
        }
        .onAppear {
            recorder.requestAuthorization()
            showOnboarding = !didCompleteOnboarding
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onFinished: {
                didCompleteOnboarding = true
                selectedTab = 0
                showOnboarding = false
            })
        }
    }
}
