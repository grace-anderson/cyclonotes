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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))]) {
                    ForEach(ride.photos) { p in
                        if let ui = UIImage(data: p.imageData) {
                            Image(uiImage: ui)
                                .resizable().scaledToFill()
                                .frame(height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
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
    }
}

