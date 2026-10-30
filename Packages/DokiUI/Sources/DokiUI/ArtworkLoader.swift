import Foundation
import UIKit
import ImageIO

/// Artwork-only cache. Playback/progress state is never invalidated by it.
@MainActor
final class ArtworkLoader {
    static let shared = ArtworkLoader()
    private let cache = NSCache<NSURL, UIImage>()
    private var pending: [URL: Task<UIImage, any Error>] = [:]
    private let session: URLSession
    private init() {
        cache.totalCostLimit = 80 * 1024 * 1024
        cache.countLimit = 120
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 0)
        session = URLSession(configuration: config, delegate: ArtworkRedirectPolicy(), delegateQueue: nil)
    }
    func image(at url: URL) async throws -> UIImage {
        if let image = cache.object(forKey: url as NSURL) { return image }
        if let task = pending[url] { return try await task.value }
        let session = session
        let task = Task.detached(priority: .userInitiated) { try await Self.fetch(url, session: session) }
        pending[url] = task
        defer { pending[url] = nil }
        let image = try await task.value
        cache.setObject(image, forKey: url as NSURL, cost: Int(image.size.width * image.size.height) * 4)
        return image
    }
    // Byte streaming and downsampling stay off the main actor while focus moves.
    nonisolated private static func fetch(_ url: URL, session: URLSession) async throws -> UIImage {
        var request = URLRequest(url: url)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.mimeType?.hasPrefix("image/") == true, http.expectedContentLength < 10 * 1024 * 1024 else { throw URLError(.badServerResponse) }
        var data = Data()
        for try await byte in bytes { data.append(byte); if data.count > 10 * 1024 * 1024 { throw URLError(.dataLengthExceedsMaximum) } }
        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600,
            kCGImageSourceCreateThumbnailWithTransform: true
        ] as CFDictionary) else { throw URLError(.cannotDecodeContentData) }
        let image = UIImage(cgImage: cg)
        return image
    }
}
private final class ArtworkRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        // Only metadata's approved Bangumi image origin or the selected Hub.
        // Never follow an image redirect to a new origin or a downgraded scheme.
        let old = response.url
        let new = request.url
        let sameOrigin = old?.host == new?.host && old?.scheme == new?.scheme && old?.port == new?.port
        completionHandler(sameOrigin ? request : nil)
    }
}
