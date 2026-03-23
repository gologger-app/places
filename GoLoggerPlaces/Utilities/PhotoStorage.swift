import UIKit
import Foundation
import ImageIO

enum PhotoStorage {
    static let maxPhotoBytes = 512_000

    private static var photosDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Saves a UIImage as a compressed JPEG and returns the generated filename.
    static func save(_ image: UIImage) throws -> String {
        guard let data = compress(image, maxBytes: maxPhotoBytes) else {
            throw PhotoStorageError.compressionFailed
        }
        let filename = UUID().uuidString + ".jpg"
        try data.write(to: url(for: filename))
        return filename
    }

    /// Loads a photo by filename.
    static func load(_ filename: String) -> UIImage? {
        guard let data = try? Data(contentsOf: url(for: filename)) else { return nil }
        return UIImage(data: data)
    }

    /// Deletes a photo file.
    static func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    /// Returns the on-disk URL for a given filename.
    static func url(for filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    /// Copies photos with the given filenames into a destination directory (for export).
    static func copyPhotos(filenames: [String], to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for filename in filenames {
            let src = url(for: filename)
            guard FileManager.default.fileExists(atPath: src.path) else { continue }
            let dst = directory.appendingPathComponent(filename)
            try FileManager.default.copyItem(at: src, to: dst)
        }
    }

    /// Copies all .jpg files from a source directory into the app's photos directory (for import).
    static func importPhotos(from directory: URL) throws {
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        try fm.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        for file in files where file.pathExtension.lowercased() == "jpg" {
            let dst = photosDirectory.appendingPathComponent(file.lastPathComponent)
            if !fm.fileExists(atPath: dst.path) {
                try fm.copyItem(at: file, to: dst)
            }
        }
    }

    // MARK: - EXIF

    /// Extracts the original capture datetime from JPEG/HEIC EXIF metadata.
    /// Returns nil if the metadata is absent or unparseable.
    static func capturedAt(from data: Data) -> Date? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
            let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }

    // MARK: - Compression

    /// Compresses a UIImage to JPEG within the given byte limit.
    /// Tries decreasing quality levels first; if still too large, scales down the image as well.
    static func compress(_ image: UIImage, maxBytes: Int = maxPhotoBytes) -> Data? {
        let qualitySteps: [CGFloat] = [0.8, 0.6, 0.4, 0.2, 0.1, 0.05]
        for quality in qualitySteps {
            if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
        }
        // Compression alone wasn't enough — scale the image down proportionally and retry
        guard let oversizedData = image.jpegData(compressionQuality: 0.5) else { return nil }
        let scaleFactor = sqrt(Double(maxBytes) / Double(oversizedData.count))
        let newSize = CGSize(
            width: (image.size.width * scaleFactor).rounded(),
            height: (image.size.height * scaleFactor).rounded()
        )
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return scaled.jpegData(compressionQuality: 0.5)
    }

    enum PhotoStorageError: LocalizedError {
        case compressionFailed
        var errorDescription: String? { "Failed to compress image for storage." }
    }
}
