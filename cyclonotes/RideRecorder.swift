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
    @Published var livePoints: [CLLocation] = []
    @Published var distanceMeters: Double = 0

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest

        // 🔧 Foreground-only for MVP to avoid crash
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        distanceMeters = 0
        livePoints.removeAll()
        lastLocation = nil
        state = .recording
        manager.startUpdatingLocation()
    }

    func pause() {
        state = .paused
        manager.stopUpdatingLocation()
    }

    func resume() {
        state = .recording
        manager.startUpdatingLocation()
    }

    func stop() {
        state = .idle
        manager.stopUpdatingLocation()
    }
}

extension RideRecorder: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard state == .recording else { return }
        for loc in locations where loc.horizontalAccuracy >= 0 && loc.timestamp.timeIntervalSinceNow > -30 {
            livePoints.append(loc)
            if let last = lastLocation { distanceMeters += loc.distance(from: last) }
            lastLocation = loc
        }
    }
}
