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
        VStack(spacing: 0) {

            Map(position: $cameraPosition) {
                let coords = recorder.livePoints.map { $0.coordinate }

                // Route polyline
                if coords.count > 1 {
                    MapPolyline(coordinates: coords)
                }

                // Start marker
                if let start = coords.first {
                    Marker("Start", systemImage: "circle.fill", coordinate: start)
                        .tint(.green)
                }

                // End marker (latest point)
                if let end = coords.last {
                    Marker("End", systemImage: "mappin.circle.fill", coordinate: end)
                        .tint(.red)
                }
            }
            .onReceive(recorder.$livePoints) { points in
                // Follow latest location while recording
                if let last = points.last {
                    let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    cameraPosition = .region(MKCoordinateRegion(center: last.coordinate, span: span))
                }
            }
            .frame(maxHeight: .infinity)

            // Stats row
            HStack {
                StatCard(title: "Distance", value: formatDistance(recorder.distanceMeters))
                StatCard(title: "Points", value: "\(recorder.livePoints.count)")
                StatCard(title: "State", value: String(describing: recorder.state).capitalized)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Controls row
            HStack(spacing: 12) {
                switch recorder.state {
                case .idle:
                    Button { startRide() } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                case .recording:
                    Button { recorder.pause() } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)

                    Button { showingNoteSheet = true } label: {
                        Label("Add Note", systemImage: "note.text")
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        Label("Add Photo", systemImage: "camera")
                    }

                    Button(role: .destructive) { stopAndSaveRide() } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)

                case .paused:
                    Button { recorder.resume() } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) { stopAndSaveRide() } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
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
