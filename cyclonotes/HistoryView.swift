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

struct HistoryView: View {
    @Query(sort: \Ride.startedAt, order: .reverse) private var rides: [Ride]

    var body: some View {
        NavigationStack {
            List(rides) { ride in
                NavigationLink(value: ride) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ride.title).font(.headline)
                        HStack(spacing: 12) {
                            Text(ride.startedAt, style: .date)
                            Text("•")
                            Text(formatDistance(ride.distanceMeters))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(for: Ride.self) { RideDetailView(ride: $0) }
            .navigationTitle("Ride History")
        }
    }
}

struct RideDetailView: View {
    let ride: Ride
    @Environment(\.modelContext) private var context
    @State private var selectedPhoto: RidePhoto? = nil

    var body: some View {
        ScrollView {
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
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(ride.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedPhoto) { photo in
            let startIndex = ride.photos.firstIndex(where: { $0 === photo }) ?? 0
            PhotoPagerFullscreenView(photos: ride.photos, initialIndex: startIndex) { toDelete, _ in
                if let idx = ride.photos.firstIndex(where: { $0 === toDelete }) {
                    ride.photos.remove(at: idx)
                    do { try context.save() } catch { print("Failed to delete photo: \(error)") }
                }
                // Dismiss the fullscreen by clearing selection
                selectedPhoto = nil
            }
        }
    }
}

private struct PhotoPagerFullscreenView: View {
    let photos: [RidePhoto]
    let initialIndex: Int
    var onDelete: (RidePhoto, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var showConfirmDelete: Bool = false

    init(photos: [RidePhoto], initialIndex: Int, onDelete: @escaping (RidePhoto, Int) -> Void) {
        self.photos = photos
        self.initialIndex = initialIndex
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
            Text("This will permanently remove the photo from this ride.")
        }
    }
}

private struct ZoomableImageView: View {
    let photo: RidePhoto

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

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
                        .gesture(magnificationGesture(ui: ui, containerSize: size))
                        .gesture(panGesture(ui: ui, containerSize: size))
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
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard scale > 1 else { return }
                let translation = value.translation
                var tentative = CGSize(width: lastOffset.width + translation.width, height: lastOffset.height + translation.height)
                tentative = clampedOffset(tentative, ui: ui, containerSize: containerSize)
                offset = tentative
            }
            .onEnded { _ in
                guard scale > 1 else { return }
                lastOffset = offset
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
