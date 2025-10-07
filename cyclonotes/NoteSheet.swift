//
//  NoteSheet.swift
//  cyclonotes
//
//  Created by Helen Anderson on 24/9/2025.
//

import Foundation
import SwiftUI

struct NoteSheet: View {
    @Binding var noteText: String
    private let maxChars = 500
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Add Note").font(.title2).bold()
                TextField("Type your note… (max 500 characters)", text: $noteText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4, reservesSpace: true)
                    .onChange(of: noteText) { _, newValue in
                        if newValue.count > maxChars {
                            noteText = String(newValue.prefix(maxChars))
                        }
                    }
                HStack {
                    Spacer()
                    let count = noteText.count
                    let warning = Double(count) / Double(maxChars) >= 0.9
                    Text("\(count)/\(maxChars)")
                        .font(.footnote)
                        .foregroundStyle(count >= maxChars ? .red : (warning ? .orange : .secondary))
                }
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(); dismiss() }
                        .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || noteText.count > maxChars)
                }
            }
        }
    }
}
