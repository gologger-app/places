import SwiftUI
import SwiftData

struct TravelModePicker: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TravelMode.sortOrder) private var modes: [TravelMode]
    @Binding var selectedMode: TravelMode?

    @State private var showAddAlert = false
    @State private var newModeName = ""

    var body: some View {
        NavigationStack {
            List {
                // None / unset option
                Button {
                    selectedMode = nil
                    dismiss()
                } label: {
                    row(icon: "minus.circle", name: "None", color: .secondary, isSelected: selectedMode == nil)
                }

                ForEach(modes) { mode in
                    Button {
                        selectedMode = mode
                        dismiss()
                    } label: {
                        row(icon: mode.icon, name: mode.name, color: .blue, isSelected: selectedMode?.id == mode.id)
                    }
                    .swipeActions(edge: .trailing) {
                        if !mode.isBuiltIn {
                            Button(role: .destructive) {
                                if selectedMode?.id == mode.id { selectedMode = nil }
                                modelContext.delete(mode)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Button {
                    newModeName = ""
                    showAddAlert = true
                } label: {
                    Label("New Travel Mode…", systemImage: "plus")
                        .foregroundStyle(.blue)
                }
            }
            .navigationTitle("Travel Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("New Travel Mode", isPresented: $showAddAlert) {
                TextField("Name", text: $newModeName)
                    .autocorrectionDisabled()
                Button("Add") { addCustomMode() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for your custom travel mode.")
            }
        }
    }

    private func row(icon: String, name: String, color: Color, isSelected: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(name)
                .foregroundStyle(.primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
    }

    private func addCustomMode() {
        let name = newModeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let mode = TravelMode(name: name, icon: "figure.run", isBuiltIn: false, sortOrder: 999)
        modelContext.insert(mode)
        try? modelContext.save()
        selectedMode = mode
        dismiss()
    }
}
