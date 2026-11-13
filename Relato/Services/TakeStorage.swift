import AVFoundation
import Foundation
import Photos
import UIKit

/// Recorded takes live in Documents/Takes. Only file names are persisted, because the app
/// container path changes between installs and restores.
enum TakeStorage {
    static var directory: URL {
        URL.documentsDirectory.appending(path: "Takes", directoryHint: .isDirectory)
    }

    static func url(for fileName: String) -> URL {
        directory.appending(path: fileName, directoryHint: .notDirectory)
    }

    static func makeRecordingURL() throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return url(for: "take-\(UUID().uuidString).mov")
    }

    static func exists(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName).path(percentEncoded: false))
    }

    static func delete(fileName: String) {
        guard !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    static func duration(of url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        guard let time = try? await asset.load(.duration), time.isNumeric else { return nil }
        let seconds = time.seconds
        return seconds.isFinite ? seconds : nil
    }
}

enum PhotoLibrarySaver {
    enum SaveError: LocalizedError {
        case denied
        case missingFile

        var errorDescription: String? {
            switch self {
            case .denied: "Relato no tiene permiso para guardar en Fotos. Puedes activarlo en Ajustes › Relato › Fotos."
            case .missingFile: "No se encontró el archivo de la toma."
            }
        }
    }

    static func saveVideo(at url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { throw SaveError.missingFile }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.denied }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
        }
    }
}

/// Memory-bounded cache of take thumbnails. Generation happens off the main thread.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 60
        return cache
    }()

    func cached(_ fileName: String) -> UIImage? {
        cache.object(forKey: fileName as NSString)
    }

    func thumbnail(for fileName: String) async -> UIImage? {
        if let hit = cached(fileName) { return hit }
        let url = TakeStorage.url(for: fileName)
        guard let image = await Self.generate(url: url) else { return nil }
        cache.setObject(image, forKey: fileName as NSString)
        return image
    }

    nonisolated private static func generate(url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 360, height: 360)
        guard let result = try? await generator.image(at: CMTime(seconds: 0.4, preferredTimescale: 600)) else { return nil }
        return UIImage(cgImage: result.image)
    }
}
