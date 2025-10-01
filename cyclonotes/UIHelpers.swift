//
//  UIHelpers.swift
//  cyclonotes
//
//  Created by Helen Anderson on 24/9/2025.
//

import Foundation
import SwiftUI

struct StatCard: View {
    let title: String
    let value: String

    /// Alignment of the content inside the card (controls where the title sits).
    var contentAlignment: HorizontalAlignment = .leading
    /// Alignment of the value text inside the card.
    var valueAlignment: Alignment = .leading

    init(
        title: String,
        value: String,
        contentAlignment: HorizontalAlignment = .leading,
        valueAlignment: Alignment = .leading
    ) {
        self.title = title
        self.value = value
        self.contentAlignment = contentAlignment
        self.valueAlignment = valueAlignment
    }

    var body: some View {
        VStack(alignment: contentAlignment, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Make the value line fill available width so alignment applies
            Text(value)
                .font(.title2).bold()
                .frame(maxWidth: .infinity, alignment: valueAlignment)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View { Text(title).font(.headline).padding(.horizontal) }
}
