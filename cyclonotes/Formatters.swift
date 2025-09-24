//
//  Formatters.swift
//  cyclonotes
//
//  Created by Helen Anderson on 24/9/2025.
//

import Foundation

func formatDistance(_ meters: Double) -> String {
    if meters < 1000 { return String(format: "%.0f m", meters) }
    return String(format: "%.2f km", meters / 1000)
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let s = Int(seconds)
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
}

func formatSpeed(_ mps: Double) -> String {
    let kph = mps * 3.6
    return String(format: "%.1f km/h", kph)
}
