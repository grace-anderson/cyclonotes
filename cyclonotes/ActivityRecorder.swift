//
//  RideRecorder.swift
//  cyclonotes
//
//  Created by Helen Anderson on 24/9/2025.
//

import Foundation
import CoreLocation
import UIKit

@MainActor
final class ActivityRecorder: NSObject, ObservableObject {
    enum State { case idle, recording, paused }

    @Published var state: State = .idle
    @Published var livePoints: [CLLocation] = []  // when idle/paused: 1 element (latest); when recording: full trail
    @Published var distanceMeters: Double = 0

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?

    private var isInBackground: Bool = false

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = false
    }

    // Call this from RootView.onAppear()
    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()

        // 🔧 Safety net: if already authorized, start updates immediately
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func start() {
        distanceMeters = 0
        // Preserve the latest known location (from idle/paused) as the starting point
        if let latest = livePoints.last {
            livePoints = [latest]
            lastLocation = latest
        } else {
            livePoints.removeAll()
            lastLocation = nil
        }
        state = .recording
        manager.startUpdatingLocation() // safe if already running
        if isInBackground {
            setBackgroundMode(active: true)
        } else {
            setBackgroundMode(active: false)
        }
    }

    func pause() {
        state = .paused
        // Keep updates running so we can still center/follow while paused
        manager.startUpdatingLocation()
        if isInBackground {
            setBackgroundMode(active: true)
        } else {
            setBackgroundMode(active: false)
        }
    }

    func resume() {
        state = .recording
        manager.startUpdatingLocation()
        if isInBackground {
            setBackgroundMode(active: true)
        } else {
            setBackgroundMode(active: false)
        }
    }

    func stop() {
        state = .idle
        endDeferredUpdatesIfNeeded()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        // Keep updates running so the map reflects current device location
        manager.startUpdatingLocation()
    }

    func setBackgroundMode(active: Bool) {
        isInBackground = active
        if state == .idle {
            // Do not run background updates when idle
            manager.allowsBackgroundLocationUpdates = false
            manager.pausesLocationUpdatesAutomatically = true
            return
        }
        if active {
            // Background low-power configuration
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.distanceFilter = 75
            manager.pausesLocationUpdatesAutomatically = true
            beginDeferredUpdatesIfPossible()
        } else {
            // Foreground configuration
            endDeferredUpdatesIfNeeded()
            manager.showsBackgroundLocationIndicator = false
            manager.allowsBackgroundLocationUpdates = false
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.distanceFilter = 10
            manager.pausesLocationUpdatesAutomatically = false
        }
        // Restart updates to apply configuration safely
        manager.startUpdatingLocation()
    }

    private func beginDeferredUpdatesIfPossible() {
        // Deprecated on iOS 13+: no-op
    }

    private func endDeferredUpdatesIfNeeded() {
        // Deprecated on iOS 13+: no-op
    }
}

extension ActivityRecorder: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                // Start updates so we get the current location even before a ride starts.
                manager.startUpdatingLocation()
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy >= 0 else { return }

        Task { @MainActor in
            switch state {
            case .recording:
                // Append to trail and accumulate distance
                if let last = lastLocation { distanceMeters += loc.distance(from: last) }
                livePoints.append(loc)
                lastLocation = loc

            case .idle, .paused:
                // Keep exactly one point (latest) so the map can center/follow
                livePoints = [loc]
                lastLocation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Optional: log errors for debugging
        print("Location error: \(error.localizedDescription)")
    }
}
