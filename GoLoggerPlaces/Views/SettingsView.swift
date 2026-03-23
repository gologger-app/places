import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingExportActivity = false
    @State private var exportURL: URL?
    @State private var showingImportPicker = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isMigrating = false
    @State private var showMigrationButton = true
    @State private var unitSystem: UnitSystem = Config.unitSystem
    @State private var isGeneratingSampleData = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Unit System", selection: $unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.name).tag(system)
                        }
                    }
                    .onChange(of: unitSystem) { oldValue, newValue in
                        Config.unitSystem = newValue
                    }
                } header: {
                    Text("Units")
                } footer: {
                    Text("Choose how speeds, distances, and altitudes are displayed throughout the app.")
                }

                Section {
                    Button(action: exportData) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.blue)
                            Text("Export Data")
                            Spacer()
                            if isExporting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isExporting || isImporting)

                    Button(action: { showingImportPicker = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(.green)
                            Text("Import Data")
                            Spacer()
                            if isImporting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isExporting || isImporting)
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Export creates a folder with all your venues, trails, and photos. Save it to Files to import it back later.")
                }

                Section {
                    NavigationLink(destination: StatisticsView()) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(.purple)
                            Text("Statistics")
                        }
                    }

                    if showMigrationButton {
                        Button(action: migrateTrailCache) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.orange)
                                Text("Update Trail Cache")
                                Spacer()
                                if isMigrating {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isMigrating)
                    }
                } header: {
                    Text("Data")
                } footer: {
                    if showMigrationButton {
                        Text("Update cached trail statistics for better performance. Only needs to be run once for existing trails.")
                    }
                }

                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }

                #if DEBUG
                Section {
                    Button(action: generateSampleData) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundStyle(.pink)
                            Text("Generate Screenshot Data")
                            Spacer()
                            if isGeneratingSampleData {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isGeneratingSampleData)
                } header: {
                    Text("Debug")
                } footer: {
                    Text("Clears existing data and generates sample data for App Store screenshots.")
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExportActivity) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.folder, .json],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Export

    private func exportData() {
        isExporting = true

        Task {
            do {
                let manager = ImportExportManager(modelContext: modelContext)
                let url = try manager.exportData()
                await MainActor.run {
                    exportURL = url
                    showingExportActivity = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Export Failed"
                    alertMessage = "Could not export data: \(error.localizedDescription)"
                    showingAlert = true
                    isExporting = false
                }
            }
        }
    }

    // MARK: - Import

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importData(from: url)
        case .failure(let error):
            alertTitle = "Import Failed"
            alertMessage = "Could not access file: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func importData(from url: URL) {
        isImporting = true

        Task { @MainActor in
            do {
                print("🔍 Starting import from: \(url.lastPathComponent)")
                print("   Full path: \(url.path)")
                print("   File exists: \(FileManager.default.fileExists(atPath: url.path))")
                print("   Is readable: \(FileManager.default.isReadableFile(atPath: url.path))")

                // Access the security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    print("❌ Failed to access security-scoped resource")
                    throw NSError(domain: "SettingsView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access file '\(url.lastPathComponent)'"])
                }
                defer {
                    print("🔓 Stopping security-scoped resource access")
                    url.stopAccessingSecurityScopedResource()
                }

                print("✅ Security-scoped resource accessed")

                let manager = ImportExportManager(modelContext: modelContext)
                try manager.importData(from: url)

                print("✅ Import completed successfully")

                alertTitle = "Import Successful"
                alertMessage = "Your data has been imported successfully."
                showingAlert = true
                isImporting = false
            } catch {
                print("❌ Import failed: \(error)")
                print("   Error domain: \((error as NSError).domain)")
                print("   Error code: \((error as NSError).code)")

                alertTitle = "Import Failed"

                // Show more detailed error message if available
                let nsError = error as NSError
                if let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                    alertMessage = "\(error.localizedDescription)\n\n\(failureReason)"
                } else {
                    alertMessage = error.localizedDescription
                }

                showingAlert = true
                isImporting = false
            }
        }
    }

    // MARK: - Sample Data Generation

    #if DEBUG
    private func generateSampleData() {
        isGeneratingSampleData = true

        Task {
            await MainActor.run {
                SampleDataGenerator.generateSampleData(modelContext: modelContext)
                alertTitle = "Sample Data Generated"
                alertMessage = "Sample collections, venues, and trails have been created for screenshots."
                showingAlert = true
                isGeneratingSampleData = false
            }
        }
    }
    #endif

    // MARK: - Migration

    private func migrateTrailCache() {
        isMigrating = true

        Task {
            do {
                let descriptor = FetchDescriptor<Trail>()
                let trails = try modelContext.fetch(descriptor)

                var updatedCount = 0
                for trail in trails {
                    // Only update if cache is empty (not already migrated)
                    if trail.cachedTotalDistance == nil || trail.cachedPointCount == 0 {
                        trail.updateCache()
                        updatedCount += 1
                    }
                }

                try modelContext.save()

                await MainActor.run {
                    alertTitle = "Migration Complete"
                    alertMessage = "Successfully updated cache for \(updatedCount) trail(s)."
                    showingAlert = true
                    isMigrating = false
                    showMigrationButton = false  // Hide button after successful migration
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Migration Failed"
                    alertMessage = "Could not update trail cache: \(error.localizedDescription)"
                    showingAlert = true
                    isMigrating = false
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Collection.self, Venue.self, Trail.self, TrailPoint.self], inMemory: true)
}
