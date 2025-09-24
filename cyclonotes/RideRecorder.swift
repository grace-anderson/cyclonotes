//
//  RideRecorder.swift
//  cyclonotes
//
//  Created by Helen Anderson on 24/9/2025.
//

import Foundation
import CoreLocation

final class RideRecorder: NSObject, ObservableObject {
    enum State { case idle, recording, paused }

    @Published var state: State = .idle
    @Published var livePoints: [CLLocation] = []  // when idle/paused: 1 element (latest); when recording: full trail
    @Published var distanceMeters: Double = 0

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest

        // Foreground-only for MVP (no background entitlement required)
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
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
        livePoints.removeAll()
        lastLocation = nil
        state = .recording
        manager.startUpdatingLocation() // safe if already running
    }
    
    func pause() {
        state = .paused
        // Keep updates running so we can still center/follow while paused
        manager.startUpdatingLocation()
    }
    
    func resume() {
        state = .recording
        manager.startUpdatingLocation()
    }

    func stop() {
        state = .idle
        // Keep updates running so the map reflects current device location
        manager.startUpdatingLocation()
    }
}

extension RideRecorder: CLLocationManagerDelegate {

    // iOS 14+: gets called whenever auth changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Start updates so we get the current location even before a ride starts.
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy >= 0 else { return }

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

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Optional: log errors for debugging
        print("Location error: \(error.localizedDescription)")
    }
}
