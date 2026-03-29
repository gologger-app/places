import SwiftUI
import SwiftData
import MapKit
import PhotosUI

struct WaypointAddSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let trail: Trail

    @State private var label = ""
    @State private var visitTime = Date()
    @State private var usePhotoLocation = false

    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var pickedData: Data?
    @State private var exifTime: Date?
    @State private var exifCoordinate: CLLocationCoordinate2D?

    // Nearest trail point to the current visitTime
    private var nearestPoint: TrailPoint? {
        trail.points.min(by: {
            abs($0.timestamp.timeIntervalSince(visitTime)) < abs($1.timestamp.timeIntervalSince(visitTime))
        })
    }

    private var effectiveCoordinate: CLLocationCoordinate2D? {
        if usePhotoLocation, let c = exifCoordinate { return c }
        guard let p = nearestPoint else { return nil }
        return CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude)
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty && effectiveCoordinate != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection

                Section("Name") {
                    TextField("e.g. Summit, Viewpoint…", text: $label)
                }

                Section("Visit Time") {
                    DatePicker("", selection: $visitTime, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                locationSection
            }
            .navigationTitle("Add Waypoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: pickerItem) { _, item in loadPhoto(item) }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        Section("Photo (Optional)") {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                if let image = pickedImage {
                    HStack(spacing: 12) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Photo selected")
                                .foregroundStyle(.primary)
                            Text("Tap to change")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    Label("Add Photo", systemImage: "photo.badge.plus")
                }
            }

            if let exifTime {
                Button {
                    visitTime = exifTime
                } label: {
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use photo time")
                                .foregroundStyle(.primary)
                            Text(exifTime.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }

            if exifCoordinate != nil {
                Toggle(isOn: $usePhotoLocation) {
                    Label("Use photo location", systemImage: "location.fill")
                }
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        Section("Location") {
            if let coord = effectiveCoordinate {
                HStack(spacing: 6) {
                    Image(systemName: usePhotoLocation ? "location.fill" : "scope")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(usePhotoLocation ? "From photo GPS" : "Nearest trail point")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Map(position: .constant(.region(MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: 400,
                    longitudinalMeters: 400
                )))) {
                    Marker("", coordinate: coord)
                        .tint(.blue)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .allowsHitTesting(false)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } else {
                Text("No trail points found. Add a photo with GPS data to set a location.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let time = PhotoStorage.capturedAt(from: data)
                let location = PhotoStorage.location(from: data)
                await MainActor.run {
                    pickedData = data
                    pickedImage = image
                    exifTime = time
                    exifCoordinate = location
                    if let t = time { visitTime = t }
                    usePhotoLocation = location != nil
                }
            }
        }
    }

    private func save() {
        guard let coord = effectiveCoordinate,
              !label.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let waypoint = WayPoint(
            label: label.trimmingCharacters(in: .whitespaces),
            latitude: coord.latitude,
            longitude: coord.longitude,
            altitude: nearestPoint?.altitude,
            visitTime: visitTime
        )
        modelContext.insert(waypoint)
        trail.waypoints.append(waypoint)
        waypoint.trail = trail

        if let image = pickedImage {
            if let filename = try? PhotoStorage.save(image) {
                let photo = Photo(filename: filename, capturedAt: exifTime)
                modelContext.insert(photo)
                waypoint.photos.append(photo)
                photo.waypoint = waypoint
            }
        }

        try? modelContext.save()
        dismiss()
    }
}
