import SwiftUI
import PhotosUI

// MARK: - Full section view (for venues)

/// A full section showing a header, horizontal photo strip, and add-photo button.
struct PhotoGridView: View {
    let photos: [Photo]
    let onAdd: (UIImage, Date?) -> Void
    let onDelete: (Photo) -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var fullscreenIndex: Int? = nil

    private var sorted: [Photo] { photos.sorted { $0.createdAt < $1.createdAt } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundStyle(.blue)
                    Text("Photos")
                        .font(.headline)
                }
                Spacer()
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                .onChange(of: pickerItems) { _, items in
                    loadPickerItems(items)
                }
            }

            if sorted.isEmpty {
                Text("No photos yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            } else {
                photoStrip(photos: sorted, size: 110)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { fullscreenIndex != nil },
            set: { if !$0 { fullscreenIndex = nil } }
        )) {
            PhotoFullscreenView(photos: sorted, initialIndex: fullscreenIndex ?? 0, onDelete: onDelete) {
                fullscreenIndex = nil
            }
        }
    }

    @ViewBuilder
    private func photoStrip(photos: [Photo], size: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    PhotoThumbnail(photo: photo, size: size)
                        .onTapGesture { fullscreenIndex = index }
                        .contextMenu {
                            Button(role: .destructive) { onDelete(photo) } label: {
                                Label("Delete Photo", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func loadPickerItems(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let capturedAt = PhotoStorage.capturedAt(from: data)
                    onAdd(image, capturedAt)
                }
            }
            pickerItems = []
        }
    }
}

// MARK: - Compact strip (for waypoints)

/// A compact horizontal photo strip with an inline add-photo button. No header.
struct PhotoStripView: View {
    let photos: [Photo]
    let onAdd: (UIImage, Date?) -> Void
    let onDelete: (Photo) -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var fullscreenIndex: Int? = nil

    private var sorted: [Photo] { photos.sorted { $0.createdAt < $1.createdAt } }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, photo in
                    PhotoThumbnail(photo: photo, size: 80)
                        .onTapGesture { fullscreenIndex = index }
                        .contextMenu {
                            Button(role: .destructive) { onDelete(photo) } label: {
                                Label("Delete Photo", systemImage: "trash")
                            }
                        }
                }

                // Add button as last item in strip
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                }
                .onChange(of: pickerItems) { _, items in
                    loadPickerItems(items)
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { fullscreenIndex != nil },
            set: { if !$0 { fullscreenIndex = nil } }
        )) {
            PhotoFullscreenView(photos: sorted, initialIndex: fullscreenIndex ?? 0, onDelete: onDelete) {
                fullscreenIndex = nil
            }
        }
    }

    private func loadPickerItems(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let capturedAt = PhotoStorage.capturedAt(from: data)
                    onAdd(image, capturedAt)
                }
            }
            pickerItems = []
        }
    }
}

// MARK: - Thumbnail

struct PhotoThumbnail: View {
    let photo: Photo
    let size: CGFloat

    var body: some View {
        Group {
            if let image = PhotoStorage.load(photo.filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Fullscreen viewer

struct PhotoFullscreenView: View {
    let photos: [Photo]
    let initialIndex: Int
    let onDelete: (Photo) -> Void
    let onDismiss: () -> Void

    @State private var currentIndex: Int
    @State private var showDeleteAlert = false

    init(photos: [Photo], initialIndex: Int, onDelete: @escaping (Photo) -> Void, onDismiss: @escaping () -> Void) {
        self.photos = photos
        self.initialIndex = initialIndex
        self.onDelete = onDelete
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: initialIndex)
    }

    private var currentPhoto: Photo? {
        photos.indices.contains(currentIndex) ? photos[currentIndex] : nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    ZoomablePhotoView(photo: photo)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Controls overlay
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Button { showDeleteAlert = true } label: {
                        Image(systemName: "trash")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()
                Spacer()
                if let date = currentPhoto?.capturedAt {
                    Text(date.formatted(date: .long, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 40)
                }
            }
        }
        .alert("Delete Photo?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let photo = currentPhoto {
                    onDelete(photo)
                    onDismiss()
                }
            }
        } message: {
            Text("This photo will be permanently deleted.")
        }
    }
}

// MARK: - Zoomable image

private struct ZoomablePhotoView: View {
    let photo: Photo

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        Group {
            if let image = PhotoStorage.load(photo.filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in scale = lastScale * value }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1 { withAnimation { scale = 1; lastScale = 1 } }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation { scale = scale > 1 ? 1 : 2; lastScale = scale }
                    }
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
