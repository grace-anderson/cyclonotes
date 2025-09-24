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
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Add Note").font(.title2).bold()
                TextField("Type your note…", text: $noteText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4, reservesSpace: true)
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(); dismiss() }
                        .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
