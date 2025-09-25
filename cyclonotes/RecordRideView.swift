import SwiftUI
import MapKit
import PhotosUI
import SwiftData

struct RecordRideView: View {
    @EnvironmentObject private var recorder: RideRecorder
    @Environment(\.modelContext) private var context
    
    @State private var ride: Ride?   // active ride (not saved until Stop)
    
    // Camera-driven Map (iOS 17+)
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631), // placeholder; will update as soon as points arrive
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )
    
    @State private var showingNoteSheet = false
    @State private var noteText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                
                // ===== Map (reduced height so the control panel has room) =====
                Map(position: $cameraPosition) {
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
                .onReceive(recorder.$livePoints) { points in
                    // ⬅️ Keep your behavior: always follow the latest location
                    if let last = points.last {
                        let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        cameraPosition = .region(MKCoordinateRegion(center: last.coordinate, span: span))
                    }
                }
                .frame(height: max(geo.size.height * 0.55, 320)) // ~55% of screen, min 320pt
                
                // ===== Bottom panel (three rows) =====
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Row 1 — Stats
                    HStack(spacing: 12) {
                        StatCard(title: "Distance", value: formatDistance(recorder.distanceMeters))
                            .frame(maxWidth: .infinity)
                        StatCard(title: "Points", value: "\(recorder.livePoints.count)")
                            .frame(maxWidth: .infinity)
                        StatCard(title: "State", value: String(describing: recorder.state).capitalized)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // Row 2 — Primary controls: (left) Start/Pause/Resume  (right) Stop
                    HStack(spacing: 12) {
                        Group {
                            switch recorder.state {
                            case .idle:
                                Button { startRide() } label: {
                                    Label("Start", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.borderedProminent)
                                
                            case .recording:
                                Button { recorder.pause() } label: {
                                    Label("Pause", systemImage: "pause.fill")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.bordered)
                                
                            case .paused:
                                Button { recorder.resume() } label: {
                                    Label("Resume", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        Button(role: .destructive) { stopAndSaveRide() } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .lineLimit(1)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .font(.headline)
                    
                    // Row 3 — Secondary controls: (left) Add Note  (right) Add Photo
                    HStack(spacing: 12) {
                        Button { showingNoteSheet = true } label: {
                            Label("Add Note", systemImage: "note.text")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .lineLimit(1)
                        }
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                            Label("Add Photo", systemImage: "camera")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .lineLimit(1)
                        }
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
                addNote(text: noteText)
                noteText = ""
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            Task { await handlePickedPhoto(item) }
        }
        .navigationTitle("Record Ride")
    }
    
    // MARK: - Actions
    
    private func startRide() {
        ride = Ride(title: "Ride on \(Date.now.formatted(date: .numeric, time: .shortened))")
        recorder.start()
    }
    
    private func stopAndSaveRide() {
        recorder.stop()
        guard let ride else { return }
        
        ride.endedAt = .now
        ride.distanceMeters = recorder.distanceMeters
        
        // Convert livePoints to persisted RoutePoints
        ride.points = recorder.livePoints.map { loc in
            RoutePoint(
                timestamp: loc.timestamp,
                lat: loc.coordinate.latitude,
                lon: loc.coordinate.longitude,
                speedMps: max(0, loc.speed)
            )
        }
        
        context.insert(ride)
        do { try context.save() } catch { print("Failed to save ride: \(error)") }
        self.ride = nil
    }
    
    private func addNote(text: String) {
        guard let ride else { return }
        let coord = recorder.livePoints.last?.coordinate
        let note = RideNote(text: text, lat: coord?.latitude, lon: coord?.longitude)
        ride.notes.append(note)
    }
    
    private func handlePickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                guard let ride else { return }
                let coord = recorder.livePoints.last?.coordinate
                let photo = RidePhoto(imageData: data, lat: coord?.latitude, lon: coord?.longitude)
                ride.photos.append(photo)
            }
        } catch {
            print("Photo load error: \(error)")
        }
    }
}
