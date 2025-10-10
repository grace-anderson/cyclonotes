//
//  RecordRideView.swift
//  cyclonotes
//
//  Created by Helen Anderson on 24/9/2025.
//

import SwiftUI
import MapKit
import PhotosUI
import SwiftData
import CoreLocation
import TelemetryDeck

private enum ActivityType: String, CaseIterable, Identifiable {
    case ride, walk, hike, run, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ride: return "Ride"
        case .walk: return "Walk"
        case .hike: return "Hike"
        case .run:  return "Run"
        case .other: return "Other Activity"
        }
    }
    var systemImage: String {
        switch self {
        case .ride: return "bicycle"
        case .walk: return "figure.walk"
        case .hike: return "figure.hiking"
        case .run:  return "figure.run"
        case .other: return "ellipsis.circle"
        }
    }
}

// One-shot location for initial centering (doesn't change RideRecorder)
final class OneShotLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last { lastLocation = loc }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("OneShotLocationProvider error: \(error.localizedDescription)")
    }
}

struct ActivityRideView: View {
    @EnvironmentObject private var recorder: ActivityRecorder
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase   // foreground/background

    @State private var ride: Ride?   // active ride (not saved until Stop)
    @State private var rideStartDate: Date? = nil
    @State private var abandonmentSignalled: Bool = false

    // Camera-driven Map (iOS 17+)
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631), // placeholder; updated by one-shot
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )

    // Follow/zoom state
    @State private var isFollowing: Bool = true
    @State private var lastMapInteractionAt: Date? = nil
    private let followTimeoutSeconds: TimeInterval = 12
    private let followTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let abandonThresholdSeconds: TimeInterval = 180 // 3 minutes

    // Initial centering
    @StateObject private var oneShotLocator = OneShotLocationProvider()
    @State private var didCenterOnLaunch = false

    @State private var showingNoteSheet = false
    @State private var noteText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    
    @State private var selectedActivity: ActivityType? = nil

    // Toast
    @State private var toastMessage: String? = nil

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {

                // ===== Map (reduced height so the control panel has room) =====
                Map(position: $cameraPosition, interactionModes: .all) {
                    let coords = recorder.livePoints.map { $0.coordinate }

                    if coords.count > 1 {
                        MapPolyline(coordinates: coords)
                    }
                    if let start = coords.first {
                        Marker("Start", systemImage: "circle.fill", coordinate: start)
                            .tint(.green)
                    }
                    if let end = coords.last {
                        Marker("End", systemImage: "mappin.circle.fill", coordinate: end)
                            .tint(.red)
                    }
                }
                // Follow rider only when following + recording
                .onReceive(recorder.$livePoints) { points in
                    guard isFollowing, recorder.state == .recording, let last = points.last else { return }
                    let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    cameraPosition = .region(MKCoordinateRegion(center: last.coordinate, span: span))
                }
                // One-shot centering at launch/foreground (even when idle)
                .onReceive(oneShotLocator.$lastLocation) { loc in
                    guard !didCenterOnLaunch, let loc else { return }
                    didCenterOnLaunch = true
                    let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    cameraPosition = .region(MKCoordinateRegion(center: loc.coordinate, span: span))
                }
                .onAppear { oneShotLocator.request() }
                // Detect user pan/zoom -> exit Follow
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0).onChanged { _ in
                        if isFollowing { isFollowing = false }
                        lastMapInteractionAt = .now
                    }
                )
                .simultaneousGesture(
                    MagnificationGesture().onChanged { _ in
                        if isFollowing { isFollowing = false }
                        lastMapInteractionAt = .now
                    }
                )
                // Follow pill overlay (top-right)
                .overlay(alignment: .topTrailing) {
                    if !isFollowing {
                        Button {
                            isFollowing = true
                            // Recenter immediately to the latest known point (recording or idle)
                            if let last = recorder.livePoints.last {
                                let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                cameraPosition = .region(MKCoordinateRegion(center: last.coordinate, span: span))
                            } else if let loc = oneShotLocator.lastLocation {
                                let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                cameraPosition = .region(MKCoordinateRegion(center: loc.coordinate, span: span))
                            }
                        } label: {
                            Label("Follow", systemImage: "location.fill")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(.thinMaterial, in: Capsule())
                        }
                        .padding(12)
                        .shadow(radius: 2)
                    }
                }
                .overlay(alignment: .bottom) {
                    if let toastMessage {
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .imageScale(.medium)
                                Text(toastMessage)
                                    .font(.footnote.weight(.semibold))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(radius: 4)
                            Spacer()
                        }
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: toastMessage)
                    }
                }
                // Optional auto-return to Follow while recording
                .onReceive(followTimer) { _ in
                    guard recorder.state == .recording, !isFollowing,
                          let lastTouch = lastMapInteractionAt else { return }
                    if Date().timeIntervalSince(lastTouch) >= followTimeoutSeconds {
                        isFollowing = true
                        if let last = recorder.livePoints.last {
                            let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                            cameraPosition = .region(MKCoordinateRegion(center: last.coordinate, span: span))
                        }
                    }
                }
                .frame(height: max(geo.size.height * 0.55, 320))

                // ===== Bottom panel (three rows) =====
                VStack(alignment: .leading, spacing: 16) {

                    // Row 1 — Stats (Distance left, State right)
                    HStack(spacing: 12) {
                        // Left card: anchors left, grows to the right; left-aligned text
                        StatCard(
                            title: "Distance",
                            value: formatDistance(recorder.distanceMeters),
                            contentAlignment: .leading,
                            valueAlignment: .leading
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Right card: anchors right, grows to the left; right-aligned text
                        StatCard(
                            title: "State",
                            value: String(describing: recorder.state).capitalized,
                            contentAlignment: .trailing,
                            valueAlignment: .trailing
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    // Row 1.5 — Activity selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ActivityType.allCases) { activity in
                                ActivityChip(
                                    activity: activity,
                                    selected: selectedActivity == activity,
                                    enabled: true
                                ) {
                                    if recorder.state == .idle {
                                        selectedActivity = activity
                                    } else {
                                        withAnimation { toastMessage = "Stop recording to change activity" }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            withAnimation { toastMessage = nil }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .accessibilityLabel("Choose activity type")

                    // Row 2 — Primary controls
                    HStack(spacing: 12) {
                        Group {
                            switch recorder.state {
                            case .idle:
                                Button { startRide() } label: {
                                    Label("Start", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(selectedActivity == nil)

                            case .recording:
                                Button { recorder.pause() } label: {
                                    Label("Pause", systemImage: "pause.fill")
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.bordered)

                            case .paused:
                                Button { recorder.resume() } label: {
                                    Label("Resume", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        Button(role: .destructive) { stopAndSaveRide() } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .lineLimit(1)
                        }
                        .buttonStyle(.borderedProminent)
                        // ✅ Disable Stop when not recording/paused (i.e., when idle)
                        .disabled(recorder.state == .idle)
                    }
                    .font(.headline)

                    // Row 3 — Secondary controls
                    HStack(spacing: 12) {
                        let isInactive = (recorder.state == .idle)

                        Button { showingNoteSheet = true } label: {
                            Label("Add Note", systemImage: "note.text")
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .lineLimit(1)
                        }
                        // Disable + visually dim when idle
                        .disabled(isInactive)
                        .opacity(isInactive ? 0.45 : 1.0)

                        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                            Label("Add Photo", systemImage: "camera")
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .lineLimit(1)
                        }
                        // Disable + visually dim when idle
                        .disabled(isInactive)
                        .opacity(isInactive ? 0.45 : 1.0)
                    }
                    .font(.headline)

                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        // Sheets & handlers
        .sheet(isPresented: $showingNoteSheet) {
            NoteSheet(noteText: $noteText) {
                addNote(text: $noteText.wrappedValue)
                noteText = ""
                withAnimation { toastMessage = "Your note is saved with your activity" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { toastMessage = nil }
                }
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            Task { await handlePickedPhoto(item) }
        }
        // ScenePhase: re-trigger one-shot centering on foreground
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                didCenterOnLaunch = false
                oneShotLocator.request()
            } else if newPhase == .inactive || newPhase == .background {
                // Potential abandonment: user left the app during an active recording soon after starting
                if recorder.state != .idle, let start = rideStartDate, abandonmentSignalled == false {
                    let duration = Date().timeIntervalSince(start)
                    if duration < abandonThresholdSeconds {
                        let activity = selectedActivityString() ?? "Unknown"
                        let distance = recorder.distanceMeters
                        let payload = Analytics.merged(with: [
                            "activity": activity,
                            "distanceMeters": String(format: "%.2f", distance),
                            "durationSeconds": String(format: "%.2f", duration),
                            "state": String(describing: recorder.state),
                            "thresholdSeconds": String(format: "%.0f", abandonThresholdSeconds)
                        ])
                        TelemetryDeck.signal("recordingAbandoned", parameters: payload)
                        abandonmentSignalled = true
                    }
                }
            }
        }
        .navigationTitle("Record Ride")
    }

    // MARK: - Actions

    private func startRide() {
        let activity = selectedActivityString() ?? "Unknown"
        let iso = ISO8601DateFormatter().string(from: Date())
        let payload = Analytics.merged(with: [
            "activity": activity,
            "timestamp": iso
        ])
        TelemetryDeck.signal("recordTapped", parameters: payload)
        rideStartDate = Date()
        abandonmentSignalled = false
        let activityPrefix = activityTitlePrefix()
        let title = "\(activityPrefix) on \(Date.now.formatted(date: .numeric, time: .shortened))"
        ride = Ride(title: title, activity: selectedActivityString())
        recorder.start()
    }

    private func stopAndSaveRide() {
        let activity = selectedActivityString() ?? "Unknown"
        let distance = recorder.distanceMeters
        let duration: TimeInterval = {
            if let start = rideStartDate { return Date().timeIntervalSince(start) }
            return 0
        }()
        let avgSpeed = duration > 0 ? distance / duration : 0
        let pointsCount = recorder.livePoints.count
        let notesCount = ride?.notes.count ?? 0
        let photosCount = ride?.photos.count ?? 0

        let payload = Analytics.merged(with: [
            "activity": activity,
            "distanceMeters": String(format: "%.2f", distance),
            "durationSeconds": String(format: "%.2f", duration),
            "avgSpeedMps": String(format: "%.3f", avgSpeed),
            "pointsCount": String(pointsCount),
            "notesCount": String(notesCount),
            "photosCount": String(photosCount)
        ])
        TelemetryDeck.signal("stopTapped", parameters: payload)
        abandonmentSignalled = false
        recorder.stop()
        isFollowing = false // let the user inspect freely
        guard let ride else { return }

        // Capture metrics before resetting
        ride.endedAt = .now
        ride.distanceMeters = recorder.distanceMeters
        ride.points = recorder.livePoints.map { loc in
            RoutePoint(timestamp: loc.timestamp,
                       lat: loc.coordinate.latitude,
                       lon: loc.coordinate.longitude,
                       speedMps: max(0, loc.speed))
        }
        context.insert(ride)
        do { try context.save() } catch { print("Failed to save ride: \(error)") }
        self.ride = nil
        rideStartDate = nil

        // ✅ Reset distance AFTER saving so the card shows "0 m"
        recorder.distanceMeters = 0

        selectedActivity = nil

        withAnimation { toastMessage = "Go to History to see your saved activity" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toastMessage = nil }
        }
    }

    private func addNote(text: String) {
        guard let ride else {
            let payload = Analytics.merged(with: [
                "error": "noActiveRide",
                "activity": selectedActivityString() ?? "Unknown",
                "distanceMeters": String(format: "%.2f", recorder.distanceMeters)
            ])
            TelemetryDeck.signal("noteAddFailed", parameters: payload)
            return
        }
        let coord = recorder.livePoints.last?.coordinate
        let note = RideNote(text: text, lat: coord?.latitude, lon: coord?.longitude)
        ride.notes.append(note)
        
        let activity = selectedActivityString() ?? "Unknown"
        let distance = recorder.distanceMeters
        let notesCount = ride.notes.count
        let hasCoordinate = (recorder.livePoints.last?.coordinate != nil)
        let notePayload = Analytics.merged(with: [
            "activity": activity,
            "distanceMeters": String(format: "%.2f", distance),
            "notesCount": String(notesCount),
            "hasCoordinate": hasCoordinate ? "true" : "false"
        ])
        TelemetryDeck.signal("noteAdded", parameters: notePayload)
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                guard let ride else {
                    let payload = Analytics.merged(with: [
                        "error": "noActiveRide",
                        "activity": selectedActivityString() ?? "Unknown",
                        "distanceMeters": String(format: "%.2f", recorder.distanceMeters)
                    ])
                    TelemetryDeck.signal("photoAddFailed", parameters: payload)
                    return
                }
                let coord = recorder.livePoints.last?.coordinate
                let photo = RidePhoto(imageData: data, lat: coord?.latitude, lon: coord?.longitude)
                ride.photos.append(photo)
                
                let activity = selectedActivityString() ?? "Unknown"
                let distance = recorder.distanceMeters
                let photosCount = ride.photos.count
                let hasCoordinate = (recorder.livePoints.last?.coordinate != nil)
                let photoPayload = Analytics.merged(with: [
                    "activity": activity,
                    "distanceMeters": String(format: "%.2f", distance),
                    "photosCount": String(photosCount),
                    "hasCoordinate": hasCoordinate ? "true" : "false"
                ])
                TelemetryDeck.signal("photoAdded", parameters: photoPayload)
                
                withAnimation { toastMessage = "Your photo is saved with your activity" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { toastMessage = nil }
                }
            }
            else {
                let payload = Analytics.merged(with: [
                    "error": "noData",
                    "activity": selectedActivityString() ?? "Unknown",
                    "distanceMeters": String(format: "%.2f", recorder.distanceMeters)
                ])
                TelemetryDeck.signal("photoAddFailed", parameters: payload)
            }
        } catch {
            print("Photo load error: \(error)")
            let ns = error as NSError
            let payload = Analytics.merged(with: [
                "error": ns.localizedDescription,
                "errorDomain": ns.domain,
                "errorCode": String(ns.code),
                "activity": selectedActivityString() ?? "Unknown",
                "distanceMeters": String(format: "%.2f", recorder.distanceMeters)
            ])
            TelemetryDeck.signal("photoAddFailed", parameters: payload)
        }
    }
    
    private func activityTitlePrefix() -> String {
        switch selectedActivity {
        case .ride?: return "Ride"
        case .walk?: return "Walk"
        case .hike?: return "Hike"
        case .run?:  return "Run"
        case .other?: return "Other activity"
        case nil: return "Activity"
        }
    }
    
    private func selectedActivityString() -> String? {
        switch selectedActivity {
        case .ride?: return "Ride"
        case .walk?: return "Walk"
        case .hike?: return "Hike"
        case .run?:  return "Run"
        case .other?: return "Other activity"
        case nil: return nil
        }
    }
}

private struct ActivityChip: View {
    let activity: ActivityType
    let selected: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        let label = HStack(spacing: 6) {
            Image(systemName: activity.systemImage)
            Text(activity.title)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)

        if selected {
            Button(action: action) { label }
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!enabled)
                .opacity(enabled ? 1.0 : 0.45)
        } else {
            Button(action: action) { label }
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .controlSize(.small)
                .buttonStyle(.bordered)
                .tint(.secondary)
                .disabled(!enabled)
                .opacity(enabled ? 1.0 : 0.45)
        }
    }
}

