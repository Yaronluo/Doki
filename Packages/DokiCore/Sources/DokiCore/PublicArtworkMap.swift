import Foundation

/// Public data only. No application credential is read or sent to this map or CDN.
public struct MappedArtwork: Sendable, Hashable {
    public let subjectID: Int
    public let mediaType: String
    public let mediaID: Int
    public let backdropPath: String?
    public let logoPath: String?
    public let logoAspect: Double?
    public let manual: Bool
    public var backdropURL: URL? { backdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") } }
    public var logoURL: URL? { logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") } }
}

public enum ArtworkMapParser {
    public static func imagePath(_ value: String) -> String? {
        guard value.range(of: #"^/[A-Za-z0-9_-]+\.(jpg|png|webp)$"#, options: .regularExpression) != nil else { return nil }
        return value
    }
    public static func parse(_ text: String) throws -> [Int: MappedArtwork] {
        guard text.hasPrefix("# bangumi-tmdb-map v1"), text.utf8.count <= 16 * 1024 * 1024 else { throw CatalogError.unavailable }
        var result: [Int: MappedArtwork] = [:]
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 5, let subjectID = Int(columns[0]), subjectID > 0 else { continue }
            let ref = columns[1].split(separator: "/")
            // Confirmed absence is retained; it is not a cue to guess another season.
            if ref.isEmpty, columns[4] == "manual" {
                result[subjectID] = MappedArtwork(subjectID: subjectID, mediaType: "tv", mediaID: 0, backdropPath: nil, logoPath: nil, logoAspect: nil, manual: true)
                continue
            }
            guard ref.count == 2, ["tv", "movie", "collection"].contains(String(ref[0])), let mediaID = Int(ref[1]), mediaID > 0 else { continue }
            var logos: [String: (String, Double)] = [:]; var original = "ja"
            if columns.count > 6 {
                for token in columns[6].split(separator: " ") {
                    let pair = token.split(separator: "=", maxSplits: 1)
                    guard pair.count == 2 else { continue }
                    if pair[0] == "o" { original = String(pair[1]); continue }
                    let value = pair[1].split(separator: ":")
                    if value.count == 2, let path = imagePath(String(value[0])), let ratio = Double(value[1]), ratio.isFinite, (0.2...15).contains(ratio) { logos[String(pair[0])] = (path, ratio) }
                }
            }
            let logo = logos["zh"] ?? logos[original] ?? logos["en"]
            result[subjectID] = MappedArtwork(subjectID: subjectID, mediaType: String(ref[0]), mediaID: mediaID, backdropPath: imagePath(columns[2]), logoPath: logo?.0, logoAspect: logo?.1, manual: columns[4] == "manual")
        }
        guard !result.isEmpty else { throw CatalogError.unavailable }
        return result
    }
}

public actor PublicArtworkMap {
    public static let shared = PublicArtworkMap()
    private var entries: [Int: MappedArtwork] = [:]
    private var checkedAt: Date = .distantPast
    private var pending: Task<[Int: MappedArtwork], any Error>?
    private let cacheURL: URL
    private let session: URLSession
    public init() {
        cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("doki-public-artwork-v1.tsv")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 18
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        session = URLSession(configuration: config, delegate: MapRedirectPolicy(), delegateQueue: nil)
    }
    public func lookup(_ id: Int) async -> MappedArtwork? {
        if entries.isEmpty, let data = try? Data(contentsOf: cacheURL), let text = String(data: data, encoding: .utf8), let disk = try? ArtworkMapParser.parse(text) {
            entries = disk
            checkedAt = (try? cacheURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        if Date().timeIntervalSince(checkedAt) < 6 * 3600 { return entries[id] }
        if let pending { return (try? await pending.value)?[id] ?? entries[id] }
        let session = session; let cacheURL = cacheURL
        let task = Task.detached(priority: .utility) {
            let url = URL(string: "https://raw.githubusercontent.com/GrahamZen/bangumi-tmdb-map/main/map/bgm-tmdb.tsv")!
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count <= 16 * 1024 * 1024,
                  let text = String(data: data, encoding: .utf8) else { throw CatalogError.unavailable }
            let parsed = try ArtworkMapParser.parse(text)
            try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: cacheURL, options: .atomic)
            return parsed
        }
        pending = task
        do { entries = try await task.value; checkedAt = .now }
        catch { checkedAt = Date().addingTimeInterval(-6 * 3600 + 60) } // bounded retry, retain a usable map
        pending = nil
        return entries[id]
    }
}
private final class MapRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}
