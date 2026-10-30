import Foundation
import UIKit
import ImageIO

/// Artwork-only cache. Playback/progress state is never invalidated by it.
@MainActor
final class ArtworkLoader {
    static let shared = ArtworkLoader()
    /// App 注入的图片备用地址：官方和镜像谁先回谁赢，慢的一方被取消。
    static var alternateProvider: (@MainActor @Sendable (URL) -> URL?)?
    private let cache = NSCache<NSURL, UIImage>()
    private var pending: [URL: Task<UIImage, any Error>] = [:]
    private let session: URLSession
    private init() {
        cache.totalCostLimit = 80 * 1024 * 1024
        cache.countLimit = 120
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 0)
        session = URLSession(configuration: config, delegate: ArtworkRedirectPolicy(), delegateQueue: nil)
    }
    func image(at url: URL, alternate: URL? = nil) async throws -> UIImage {
        if let image = cache.object(forKey: url as NSURL) { return image }
        if let task = pending[url] { return try await task.value }
        let session = session
        var candidates = [url]
        if let alternate, alternate != url { candidates.append(alternate) }
        let task = Task.detached(priority: .userInitiated) {
            try await Self.race(candidates, session: session)
        }
        pending[url] = task
        defer { pending[url] = nil }
        let image = try await task.value
        cache.setObject(image, forKey: url as NSURL, cost: Int(image.size.width * image.size.height) * 4)
        return image
    }
    /// 官方和镜像各发一次，先解码成功的赢；慢的一方随 group 取消。
    nonisolated private static func race(_ urls: [URL], session: URLSession) async throws -> UIImage {
        try await withThrowingTaskGroup(of: UIImage.self) { group in
            for url in urls {
                group.addTask { try await fetch(url, session: session) }
            }
            defer { group.cancelAll() }
            var lastError: (any Error)?
            while !group.isEmpty {
                do {
                    if let image = try await group.next() { return image }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    if Task.isCancelled { throw CancellationError() }
                    lastError = error
                }
            }
            throw lastError ?? URLError(.cannotDecodeContentData)
        }
    }
    // Downsampling stays off the main actor while focus moves.
    nonisolated private static func fetch(_ url: URL, session: URLSession) async throws -> UIImage {
        var request = URLRequest(url: url)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        // Read in one shot: the previous byte-by-byte accumulation made a 1 MB
        // poster cost seconds of main-thread-adjacent CPU and looked like a hang.
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.mimeType?.hasPrefix("image/") == true, data.count < 10 * 1024 * 1024 else { throw URLError(.badServerResponse) }
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
