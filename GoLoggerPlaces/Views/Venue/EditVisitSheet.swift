import SwiftUI
import SwiftData

/// Sheet for editing an existing visit
struct EditVisitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let visit: Visit

    @State private var visitDate: Date
    @State private var visitNote: String

    init(visit: Visit) {
        self.visit = visit
        _visitDate = State(initialValue: visit.date)
        _visitNote = State(initialValue: visit.note ?? "")
    }

    var body: some View {
        Form {
            Section("Visit Details") {
                DatePicker("Date", selection: $visitDate, displayedComponents: [.date, .hourAndMinute])

                TextField("Note (optional)", text: $visitNote, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("Edit Visit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveVisit()
                }
            }
        }
    }

    private func saveVisit() {
        visit.date = visitDate
        visit.note = visitNote.isEmpty ? nil : visitNote

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        EditVisitSheet(visit: Visit(
            date: Date(),
            note: "Great visit!"
        ))
        .modelContainer(for: [Visit.self], inMemory: true)
    }
}
