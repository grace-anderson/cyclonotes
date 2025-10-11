//
//  HistoryView.swift
//  cyclonotes
//
//  Created by Helen Anderson on 24/9/2025.
//

import Foundation
import SwiftUI
import MapKit
import SwiftData
import PhotosUI
import TelemetryDeck
import UIKit

struct HistoryView: View {
    @Query(sort: \Ride.startedAt, order: .reverse) private var rides: [Ride]
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDeleteOffsets: IndexSet? = nil
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(rides) { ride in
                    NavigationLink(value: ride) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                if let icon = activityIcon(for: ride) {
                                    Image(systemName: icon)
                                        .foregroundStyle(.secondary)
                                }
                                Text(displayTitle(for: ride))
                            }
                            .font(.headline)
                            HStack(spacing: 12) {
                                Text(ride.startedAt, style: .date)
                                Text("•")
                                Text(formatDistance(ride.distanceMeters))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: requestDelete)
            }
            .navigationDestination(for: Ride.self) { RideDetailView(ride: $0) }
            .navigationTitle("History")
            .toolbar { EditButton() }
            .alert("Delete this \(deletionNoun())?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let offsets = pendingDeleteOffsets {
                        deleteRides(at: offsets)
                    }
                    pendingDeleteOffsets = nil
                }
                Button("Cancel", role: .cancel) { pendingDeleteOffsets = nil }
            } message: {
                Text("This will permanently remove the \(deletionNoun()) and its notes/photos.")
            }
        }
    }

    private func deleteRides(at offsets: IndexSet) {
        for index in offsets {

            let ride = rides[index]
            modelContext.delete(ride)
        }
        let deletedCount = offsets.count
        let payload = Analytics.merged(with: [
            "deletedCount": String(deletedCount)
        ])
        TelemetryDeck.signal("historyItemDeleted", parameters: payload)
        do { try modelContext.save() } catch { print("Failed to delete ride(s): \(error)") }
    }
    
    private func requestDelete(at offsets: IndexSet) {
        pendingDeleteOffsets = offsets
        showDeleteConfirm = true
    }
    
    private func displayTitle(for ride: Ride) -> String {
        // Titles are saved with the selected activity prefix already (e.g., "Ride on ...")
        return ride.title
    }
    
    private func activityIcon(for ride: Ride) -> String? {
        guard let a = ride.activity?.lowercased() else { return nil }
        switch a {
        case "ride": return "bicycle"
        case "walk": return "figure.walk"
        case "hike": return "figure.hiking"
        case "run":  return "figure.run"
        case "other activity": return "ellipsis.circle"
        default: return nil
        }
    }

    private func deletionNoun() -> String {
        guard let offsets = pendingDeleteOffsets else { return "activity" }
        if offsets.count > 1 { return "activities" }
        if let index = offsets.first, rides.indices.contains(index) {
            let a = rides[index].activity?.lowercased() ?? "activity"
            switch a {
            case "ride": return "ride"
            case "walk": return "walk"
            case "hike": return "hike"
            case "run":  return "run"
            default:      return "activity"
            }
        }
        return "activity"
    }
}

struct RideDetailView: View {
    let ride: Ride
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPhoto: RidePhoto? = nil

    @State private var noteBeingEdited: RideNote? = nil
    @State private var noteToDelete: RideNote? = nil
    @State private var showDeleteConfirm: Bool = false
    
    @State private var showingAddNoteSheet: Bool = false
    @State private var newNoteText: String = ""
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var toastMessage: String? = nil

    @State private var showingShareSheet: Bool = false
    @State private var shareItems: [Any] = []

    var body: some View {
        ScrollView {
            // Control row under the title
            HStack(spacing: 16) {
                // Add Note button
                Button { showingAddNoteSheet = true } label: {
                    Image(systemName: "note.text")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("Add Note")

                // Add Photo button (moved from toolbar)
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "camera")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("Add Photo")

                Spacer()

                // Share button
                Button { Task { await shareRide() } } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("Share")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            if let r = ride.coordinateBounds {
                Map(initialPosition: .region(r)) {
                    let coords = ride.points.map {
                        CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                    }

                    // Route polyline
                    if coords.count > 1 {
                        MapPolyline(coordinates: coords)
                    }

                    // Start & End markers
                    if let start = coords.first {
                        Marker("Start", systemImage: "circle.fill", coordinate: start)
                            .tint(.green)
                    }
                    if let end = coords.last {
                        Marker("End", systemImage: "mappin.circle.fill", coordinate: end)
                            .tint(.red)
                    }
                }
                .frame(height: 220)
            }

            HStack(spacing: 16) {
                StatCard(title: "Distance", value: formatDistance(ride.distanceMeters), valueFont: .title3)
                    .frame(maxWidth: .infinity)
                StatCard(title: "Duration", value: formatDuration(ride.duration), valueFont: .title3)
                    .frame(maxWidth: .infinity)
                StatCard(title: "Average", value: formatSpeed(ride.avgSpeedMps), valueFont: .title3)
                    .frame(maxWidth: .infinity)
            }
            .padding()

            if !ride.photos.isEmpty {
                SectionHeader("Photos")
                ZStack {
                    // Grid background becomes the visible 1pt separators
                    Rectangle().fill(.separator)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 3) {
                        ForEach(ride.photos) { p in
                            if let ui = UIImage(data: p.imageData) {
                                ZStack {
                                    // Cell background so the separator shows between items
                                    Color(.systemBackground)
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                }
                                .frame(height: 110)
                                .clipped()
                                .contentShape(Rectangle())
                                .onTapGesture { selectedPhoto = p }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            if !ride.notes.isEmpty {
                SectionHeader("Notes")
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(ride.notes) { n in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(n.text).font(.body)
                            HStack(spacing: 8) {
                                Text(n.timestamp, style: .time)
                                if let lat = n.lat, let lon = n.lon {
                                    Text("@ \(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))")
                                }
                            }
                            .foregroundStyle(.secondary)
                            HStack {
                                Spacer()
                                Button(role: .destructive) {
                                    noteToDelete = n
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                        .onTapGesture { noteBeingEdited = n }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") {
                                noteBeingEdited = n
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                noteToDelete = n
                                showDeleteConfirm = true
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                noteToDelete = n
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(displayTitle(ride))
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let toastMessage {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                        Text(toastMessage)
                            .font(.body.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 480)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 6)
                    .padding(.bottom, 16)
                    Spacer()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: toastMessage)
            }
        }
        .sheet(item: $noteBeingEdited) { note in
            EditNoteSheet(note: note) { updatedText in
                // Persist the change
                note.text = updatedText
                do { try modelContext.save() } catch { print("Failed to save edited note: \(error)") }
            }
        }
        .sheet(isPresented: $showingAddNoteSheet) {
            NoteSheet(noteText: $newNoteText) {
                let note = RideNote(text: newNoteText)
                ride.notes.append(note)
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to save new note: \(error)")
                    let ns = error as NSError
                    let payload = Analytics.merged(with: [
                        "rideId": ride.id.uuidString,
                        "activity": ride.activity ?? "Unknown",
                        "distanceMeters": String(format: "%.2f", ride.distanceMeters),
                        "error": ns.localizedDescription,
                        "errorDomain": ns.domain,
                        "errorCode": String(ns.code)
                    ])
                    TelemetryDeck.signal("savedRideNoteAddFailed", parameters: payload)
                }
                let payloadNote = Analytics.merged(with: [
                    "rideId": ride.id.uuidString,
                    "activity": ride.activity ?? "Unknown",
                    "distanceMeters": String(format: "%.2f", ride.distanceMeters),
                    "notesCount": String(ride.notes.count)
                ])
                TelemetryDeck.signal("savedRideNoteAdded", parameters: payloadNote)
                newNoteText = ""
                withAnimation { toastMessage = "Your note is saved" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { toastMessage = nil }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheetView(items: shareItems) { _ in
                showingShareSheet = false
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        let photo = RidePhoto(imageData: data)
                        ride.photos.append(photo)
                        do {
                            try modelContext.save()
                        } catch {
                            print("Failed to save new photo: \(error)")
                            let ns = error as NSError
                            let payload = Analytics.merged(with: [
                                "rideId": ride.id.uuidString,
                                "activity": ride.activity ?? "Unknown",
                                "distanceMeters": String(format: "%.2f", ride.distanceMeters),
                                "error": ns.localizedDescription,
                                "errorDomain": ns.domain,
                                "errorCode": String(ns.code)
                            ])
                            TelemetryDeck.signal("savedRidePhotoAddFailed", parameters: payload)
                        }
                    }
                    else {
                        let payload = Analytics.merged(with: [
                            "rideId": ride.id.uuidString,
                            "activity": ride.activity ?? "Unknown",
                            "distanceMeters": String(format: "%.2f", ride.distanceMeters),
                            "error": "noData"
                        ])
                        TelemetryDeck.signal("savedRidePhotoAddFailed", parameters: payload)
                    }
                } catch {
                    print("Photo load error: \(error)")
                    let ns = error as NSError
                    let payload = Analytics.merged(with: [
                        "rideId": ride.id.uuidString,
                        "activity": ride.activity ?? "Unknown",
                        "distanceMeters": String(format: "%.2f", ride.distanceMeters),
                        "error": ns.localizedDescription,
                        "errorDomain": ns.domain,
                        "errorCode": String(ns.code)
                    ])
                    TelemetryDeck.signal("savedRidePhotoAddFailed", parameters: payload)
                }
                // Reset selection so the picker can be used again immediately
                await MainActor.run { pickerItem = nil }
            }
        }
        .onAppear {
            let iso = ISO8601DateFormatter().string(from: ride.startedAt)
            let payload = Analytics.merged(with: [
                "rideId": ride.id.uuidString,
                "activity": ride.activity ?? "Unknown",
                "distanceMeters": String(format: "%.2f", ride.distanceMeters),
                "startedAt": iso
            ])
            TelemetryDeck.signal("activityDetailViewed", parameters: payload)
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            let startIndex = ride.photos.firstIndex(where: { $0 === photo }) ?? 0
            PhotoPagerFullscreenView(photos: ride.photos, initialIndex: startIndex) { toDelete, _ in
                if let idx = ride.photos.firstIndex(where: { $0 === toDelete }) {
                    ride.photos.remove(at: idx)
                    do { try modelContext.save() } catch { print("Failed to delete photo: \(error)") }
                }
                // Dismiss the fullscreen by clearing selection
                selectedPhoto = nil
            }
        }
        .alert("Delete this note?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let target = noteToDelete, let idx = ride.notes.firstIndex(where: { $0 === target }) {
                    ride.notes.remove(at: idx)
                    do { try modelContext.save() } catch { print("Failed to delete note: \(error)") }
                }
                noteToDelete = nil
            }
            Button("Cancel", role: .cancel) { noteToDelete = nil }
        } message: {
            Text("This will permanently remove the note from this activity.")
        }
    }

    private func displayTitle(_ ride: Ride) -> String {
        ride.title
    }

    private func shareRide() async {
        let payload = Analytics.merged(with: [
            "rideId": ride.id.uuidString,
            "photosCount": String(ride.photos.count),
            "notesCount": String(ride.notes.count)
        ])
        TelemetryDeck.signal("rideShareTapped", parameters: payload)
        
        if let image = await generateShareImage() {
            await MainActor.run {
                shareItems = [image]
                showingShareSheet = true
            }
        }
    }

    private func generateShareImage() async -> UIImage? {
        let targetWidth: CGFloat = 1080
        let margin: CGFloat = 40
        let spacing: CGFloat = 16
        let title = ride.title
        let distance = formatDistance(ride.distanceMeters)
        let duration = formatDuration(ride.duration)
        let avg = formatSpeed(ride.avgSpeedMps)

        // Build map snapshot (optional height 540)
        let mapHeight: CGFloat = 540
        let mapImage = await snapshotMapImage(size: CGSize(width: targetWidth - 2*margin, height: mapHeight))

        // Prepare photos (cap 12)
        let uiPhotos: [UIImage] = ride.photos.compactMap { UIImage(data: $0.imageData) }
        let capped = Array(uiPhotos.prefix(12))
        let remaining = max(0, uiPhotos.count - capped.count)

        // Prepare notes strings
        let notes = ride.notes

        // Compute dynamic heights
        let titleFont = UIFont.systemFont(ofSize: 44, weight: .semibold)
        let statFont = UIFont.systemFont(ofSize: 34, weight: .regular)
        let smallFont = UIFont.systemFont(ofSize: 30, weight: .regular)

        let titleHeight = title.height(constrainedToWidth: targetWidth - 2*margin, font: titleFont, maxLines: 1)
        let statsBlockHeight: CGFloat = 44 // row labels rendered inline

        // Photos grid sizing
        let columns: CGFloat = 3
        let gridSpacing: CGFloat = 8
        let cellW = ((targetWidth - 2*margin) - gridSpacing * (columns - 1)) / columns
        let rows = ceil(CGFloat(capped.count) / columns)
        let photosHeight = rows > 0 ? rows * cellW + max(0, rows - 1) * gridSpacing : 0

        // Notes height (simple stacked text)
        var notesHeight: CGFloat = 0
        for n in notes {
            let body = n.text
            notesHeight += body.height(constrainedToWidth: targetWidth - 2*margin, font: smallFont, maxLines: 0) + 6
            var meta = DateFormatter.localizedString(from: n.timestamp, dateStyle: .none, timeStyle: .short)
            if let lat = n.lat, let lon = n.lon { meta += "  @ " + String(format: "%.4f, %.4f", lat, lon) }
            notesHeight += meta.height(constrainedToWidth: targetWidth - 2*margin, font: UIFont.systemFont(ofSize: 26), maxLines: 1) + 12
        }

        // Total height
        let totalHeight = margin + titleHeight + spacing + statsBlockHeight + spacing + (mapImage != nil ? mapHeight : 0) + spacing + photosHeight + (remaining > 0 ? 40 : 0) + spacing + notesHeight + margin

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetWidth, height: totalHeight), format: format)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor.systemBackground.setFill()
            cg.fill(CGRect(x: 0, y: 0, width: targetWidth, height: totalHeight))

            var y = margin
            // Title
            title.draw(in: CGRect(x: margin, y: y, width: targetWidth - 2*margin, height: titleHeight), withFont: titleFont, color: .label, maxLines: 1)
            y += titleHeight + spacing

            // Stats line
            let stats = "Distance: \(distance)    Duration: \(duration)    Average: \(avg)"
            stats.draw(in: CGRect(x: margin, y: y, width: targetWidth - 2*margin, height: statsBlockHeight), withFont: statFont, color: .secondaryLabel, maxLines: 1)
            y += statsBlockHeight + spacing

            // Map snapshot
            if let mapImage {
                mapImage.draw(in: CGRect(x: margin, y: y, width: targetWidth - 2*margin, height: mapHeight))
                y += mapHeight + spacing
            }

            // Photos grid
            for (idx, ui) in capped.enumerated() {
                let row = floor(CGFloat(idx) / columns)
                let col = CGFloat(idx).truncatingRemainder(dividingBy: columns)
                let x = margin + col * (cellW + gridSpacing)
                let rect = CGRect(x: x, y: y + row * (cellW + gridSpacing), width: cellW, height: cellW)
                ui.draw(in: rect)
            }
            if capped.count > 0 { y += photosHeight + (remaining > 0 ? 0 : spacing) }
            if remaining > 0 {
                let more = "+ \(remaining) more"
                more.draw(in: CGRect(x: margin, y: y + 8, width: targetWidth - 2*margin, height: 32), withFont: UIFont.systemFont(ofSize: 28, weight: .semibold), color: .secondaryLabel, maxLines: 1)
                y += 40 + spacing
            } else if capped.count > 0 {
                y += spacing
            }

            // Notes
            for n in notes {
                let body = n.text
                let bodyH = body.height(constrainedToWidth: targetWidth - 2*margin, font: smallFont, maxLines: 0)
                body.draw(in: CGRect(x: margin, y: y, width: targetWidth - 2*margin, height: bodyH), withFont: smallFont, color: .label, maxLines: 0)
                y += bodyH + 6
                var meta = DateFormatter.localizedString(from: n.timestamp, dateStyle: .none, timeStyle: .short)
                if let lat = n.lat, let lon = n.lon { meta += "  @ " + String(format: "%.4f, %.4f", lat, lon) }
                let metaFont = UIFont.systemFont(ofSize: 26)
                let metaH = meta.height(constrainedToWidth: targetWidth - 2*margin, font: metaFont, maxLines: 1)
                meta.draw(in: CGRect(x: margin, y: y, width: targetWidth - 2*margin, height: metaH), withFont: metaFont, color: .secondaryLabel, maxLines: 1)
                y += metaH + 12
            }
        }
        return image
    }

    private func snapshotMapImage(size: CGSize) async -> UIImage? {
        guard let region = ride.coordinateBounds else { return nil }
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = 1
        let snapshotter = MKMapSnapshotter(options: options)
        do {
            let snapshot = try await snapshotter.start()
            // Draw route polyline onto snapshot
            let base = snapshot.image
            let renderer = UIGraphicsImageRenderer(size: base.size)
            let image = renderer.image { ctx in
                base.draw(at: .zero)
                let cg = ctx.cgContext
                cg.setStrokeColor(UIColor.systemBlue.cgColor)
                cg.setLineWidth(4)
                cg.setLineJoin(.round)
                cg.setLineCap(.round)
                let coords = ride.points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                guard coords.count > 1 else { return }
                let path = UIBezierPath()
                for (i, c) in coords.enumerated() {
                    let p = snapshot.point(for: c)
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                cg.addPath(path.cgPath)
                cg.strokePath()
            }
            return image
        } catch {
            print("Map snapshot error: \(error)")
            return nil
        }
    }
}

private struct PhotoPagerFullscreenView: View {
    let photos: [RidePhoto]
    var onDelete: (RidePhoto, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var showConfirmDelete: Bool = false

    init(photos: [RidePhoto], initialIndex: Int, onDelete: @escaping (RidePhoto, Int) -> Void) {
        self.photos = photos
        self.onDelete = onDelete
        _index = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if photos.indices.contains(index) {
                TabView(selection: $index) {
                    ForEach(photos.indices, id: \.self) { i in
                        ZoomableImageView(photo: photos[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page)
                .background(Color.black)
                .ignoresSafeArea()
            }

            HStack {
                Button(action: { showConfirmDelete = true }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.red)
                        .shadow(radius: 4)
                        .padding(16)
                }
                .accessibilityLabel("Delete photo")
                .accessibilityAddTraits(.isButton)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                        .padding(16)
                }
                .accessibilityLabel("Close photo")
                .accessibilityAddTraits(.isButton)
            }

            VStack {
                Spacer()
                Text("\(index + 1) of \(photos.count)")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.bottom, 24)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .alert("Delete this photo?", isPresented: $showConfirmDelete) {
            Button("Delete", role: .destructive) {
                if photos.indices.contains(index) {
                    onDelete(photos[index], index)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the photo from this activity.")
        }
    }
}

private struct ZoomableImageView: View {
    let photo: RidePhoto

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var allowPager: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Group {
                if let ui = UIImage(data: photo.imageData) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .contentShape(Rectangle())
                        .simultaneousGesture(magnificationGesture(ui: ui, containerSize: size))
                        .gesture(panGesture(ui: ui, containerSize: size), including: (scale > 1 && !allowPager) ? .all : .none)
                        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: scale)
                        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: offset)
                        .background(Color.black)
                        .clipped()
                } else {
                    Color.black
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { // double-tap to zoom toggle
                if scale > 1 { resetZoom() } else { zoomIn() }
            }
        }
        .ignoresSafeArea()
    }

    private func magnificationGesture(ui: UIImage, containerSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = clamp(lastScale * value, min: 1.0, max: 4.0)
                scale = newScale
                // Clamp offset to bounds for the new scale
                clampOffsetForCurrentState(ui: ui, containerSize: containerSize)
            }
            .onEnded { _ in
                lastScale = scale
                if scale == 1 { // reset pan when fully zoomed out
                    offset = .zero
                    lastOffset = .zero
                } else {
                    clampOffsetForCurrentState(ui: ui, containerSize: containerSize)
                    lastOffset = offset
                }
            }
    }

    private func panGesture(ui: UIImage, containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard scale > 1 else { return }
                let translation = value.translation
                let tentative = CGSize(width: lastOffset.width + translation.width, height: lastOffset.height + translation.height)
                let clamped = clampedOffset(tentative, ui: ui, containerSize: containerSize)
                offset = clamped
                
                // Edge handoff: if at a horizontal bound and dragging further outward, allow pager
                let bounds = panBounds(ui: ui, containerSize: containerSize)
                let maxX = bounds.width
                if maxX > 0 {
                    let epsilon: CGFloat = 0.5
                    let atLeft = clamped.width <= -maxX + epsilon
                    let atRight = clamped.width >= maxX - epsilon
                    let dx = translation.width
                    if (atLeft && dx < 0) || (atRight && dx > 0) {
                        allowPager = true
                    } else {
                        allowPager = false
                    }
                }
            }
            .onEnded { _ in
                guard scale > 1 else { return }
                lastOffset = offset
                allowPager = false
            }
    }

    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }

    private func zoomIn() {
        scale = 2.0
        lastScale = 2.0
    }

    private func clampOffsetForCurrentState(ui: UIImage, containerSize: CGSize) {
        offset = clampedOffset(offset, ui: ui, containerSize: containerSize)
    }

    private func clampedOffset(_ proposed: CGSize, ui: UIImage, containerSize: CGSize) -> CGSize {
        let bounds = panBounds(ui: ui, containerSize: containerSize)
        let clampedX = Swift.max(-bounds.width, Swift.min(bounds.width, proposed.width))
        let clampedY = Swift.max(-bounds.height, Swift.min(bounds.height, proposed.height))
        return CGSize(width: clampedX, height: clampedY)
    }

    private func panBounds(ui: UIImage, containerSize: CGSize) -> CGSize {
        // Compute fitted size for the image within the container (before zoom)
        let imageSize = ui.size
        let fitScale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let fittedWidth = imageSize.width * fitScale
        let fittedHeight = imageSize.height * fitScale

        // Size after current zoom scale
        let contentWidth = fittedWidth * scale
        let contentHeight = fittedHeight * scale

        // Max pan allowed so edges align with container edges (no excessive blank space)
        let maxX = max(0, (contentWidth - containerSize.width) / 2)
        let maxY = max(0, (contentHeight - containerSize.height) / 2)
        return CGSize(width: maxX, height: maxY)
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
}

private struct EditNoteSheet: View {
    let note: RideNote
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    private let maxChars = 500

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Edit Note").font(.title2).bold()
                TextField("Update your note… (max 500 characters)", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4, reservesSpace: true)
                    .onChange(of: text) { _, newValue in
                        if newValue.count > maxChars {
                            text = String(newValue.prefix(maxChars))
                        }
                    }
                HStack {
                    Spacer()
                    let count = text.count
                    let warning = Double(count) / Double(maxChars) >= 0.9
                    Text("\(count)/\(maxChars)")
                        .font(.footnote)
                        .foregroundStyle(count >= maxChars ? .red : (warning ? .orange : .secondary))
                }
                Spacer()
            }
            .padding()
            .onAppear { text = note.text }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > maxChars)
                }
            }
        }
    }
}

private extension String {
    func height(constrainedToWidth width: CGFloat, font: UIFont, maxLines: Int) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph
        ]
        var rect = (self as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attr, context: nil)
        if maxLines > 0 {
            let lineHeight = font.lineHeight
            rect.size.height = min(rect.size.height, CGFloat(maxLines) * lineHeight)
        }
        return ceil(rect.size.height)
    }

    func draw(in rect: CGRect, withFont font: UIFont, color: UIColor, maxLines: Int) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = maxLines == 1 ? .byTruncatingTail : .byWordWrapping
        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        (self as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attr, context: nil)
    }
}

