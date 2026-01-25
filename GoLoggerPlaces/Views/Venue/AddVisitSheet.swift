import SwiftUI
import SwiftData

/// Sheet for adding a new visit to a venue
struct AddVisitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let venue: Venue

    @State private var visitDate = Date()
    @State private var visitNote = ""

    var body: some View {
        Form {
            Section("Visit Details") {
                DatePicker("Date", selection: $visitDate, displayedComponents: [.date, .hourAndMinute])

                TextField("Note (optional)", text: $visitNote, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("Add Visit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addVisit()
                }
            }
        }
    }

    private func addVisit() {
        let visit = Visit(
            date: visitDate,
            note: visitNote.isEmpty ? nil : visitNote
        )

        modelContext.insert(visit)
        venue.addVisit(visit)

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AddVisitSheet(venue: Venue(
            latitude: 37.7749,
            longitude: -122.4194,
            label: "Golden Gate Park"
        ))
        .modelContainer(for: [Venue.self, Visit.self], inMemory: true)
    }
}
