//
//  RootView.swift
//  cyclonotes
//
//  Created by Helen Anderson on 24/9/2025.
//

import Foundation
import SwiftUI
import TelemetryDeck
import CoreLocation

struct RootView: View {
    @StateObject private var recorder = ActivityRecorder()
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding: Bool = false
    @State private var selectedTab: Int = 0
    @State private var showOnboarding: Bool = false
    @State private var didSendLaunchSignal: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
            ActivityRideView()
                .tabItem { Label("Record", systemImage: "dot.radiowaves.left.and.right") }
                .environmentObject(recorder)
                .tag(0)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(1)
        }
        .onAppear {
            // Request authorization and log failures if any
            recorder.requestAuthorization()
            // If your RideRecorder exposes an authorization status, you can check and signal here. As a fallback, check CoreLocation authorization for a coarse signal.
            let status = CLLocationManager().authorizationStatus
            switch status {
            case .denied, .restricted:
                TelemetryDeck.signal("authorizationFailed", parameters: Analytics.merged(with: ["permission": "location", "status": "deniedOrRestricted"]))
            case .notDetermined:
                // Still not determined after request; surface as a soft failure
                TelemetryDeck.signal("authorizationFailed", parameters: Analytics.merged(with: ["permission": "location", "status": "notDetermined"]))
            default:
                break
            }
            showOnboarding = !didCompleteOnboarding
            if !didSendLaunchSignal {
                let payload = Analytics.standardPayload
                if showOnboarding {
                    TelemetryDeck.signal("appLaunchedOnboarding", parameters: payload)
                } else {
                    TelemetryDeck.signal("appLaunchedNoOnboarding", parameters: payload)
                }
                didSendLaunchSignal = true
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 1 { // History tab
                TelemetryDeck.signal("historyTapped", parameters: Analytics.standardPayload)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(onFinished: {
                didCompleteOnboarding = true
                selectedTab = 0
                showOnboarding = false
                TelemetryDeck.signal("onboardingCompleted", parameters: Analytics.standardPayload)
            })
        }
    }
}
