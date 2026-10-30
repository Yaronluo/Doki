import Foundation

/// Public Bangumi reads work without credentials. When a Hub is configured it
/// owns metadata egress and optional TMDB; secrets never enter this client.
public actor CatalogClient {
    private let session: URLSession
    private let hub: URL?
    public init(hubURL: URL? = nil) {
        hub = hubURL
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 18
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        session = URLSession(configuration: config, delegate: CatalogRedirectPolicy(), delegateQueue: nil)
    }
    private func request<T: Decodable & Sendable>(_ type: T.Type, direct: String, proxy: String, body: Data? = nil) async throws -> T {
        let url = hub.map { $0.appendingPathComponent(proxy) } ?? URL(string: "https://api.bgm.tv\(direct)")!
        // Query strings must remain queries when constructing a Hub URL.
        let target: URL
        if let hub { target = URL(string: hub.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + proxy)! } else { target = url }
        var req = URLRequest(url: target)
        req.setValue("Doki/0.2 (personal tvOS catalog; https://github.com/bangumi/api)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { req.httpMethod = "POST"; req.httpBody = body; req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: req)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count < 8 * 1024 * 1024 else { throw CatalogError.unavailable }
        return try JSONDecoder().decode(type, from: data)
    }
    public func home() async throws -> CatalogHome {
        if hub != nil { return try await request(CatalogHome.self, direct: "", proxy: "v1/home") }
        async let days = request([CatalogDay].self, direct: "/calendar", proxy: "")
        let date = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "Asia/Shanghai")!, from: .now)
        let month = ((date.month ?? 1) - 1) / 3 * 3 + 1
        async let picks = request(CatalogPage.self, direct: "/v0/subjects?type=2&sort=rank&year=\(date.year ?? 2026)&month=\(month)&limit=24&offset=0", proxy: "")
        return try await CatalogHome(calendar: days, picks: picks)
    }
    /// Bangumi defines heat as collection count, independent of score/rank.
    public func popular() async throws -> CatalogPage {
        let body = try JSONSerialization.data(withJSONObject: ["keyword": "", "sort": "heat", "filter": ["type": [2], "nsfw": false]])
        return try await request(CatalogPage.self, direct: "/v0/search/subjects?limit=12&offset=0", proxy: "v1/popular", body: hub == nil ? body : nil)
    }
    public func subject(_ id: Int) async throws -> CatalogSubject {
        try await request(CatalogSubject.self, direct: "/v0/subjects/\(id)", proxy: "v1/subjects/\(id)")
    }
    public func episodes(_ id: Int) async throws -> [CatalogEpisode] {
        var result: [CatalogEpisode] = []; var offset = 0
        // Respect actual page size/total; never silently present 100 as the full list.
        while offset < 10000 {
            let page = try await request(CatalogEpisodePage.self, direct: "/v0/episodes?subject_id=\(id)&type=0&limit=100&offset=\(offset)", proxy: "v1/subjects/\(id)/episodes?offset=\(offset)")
            result += page.data
            offset += page.data.count
            if page.data.isEmpty || offset >= page.total { break }
        }
        var seen = Set<Int>()
        return result.filter { seen.insert($0.id).inserted }.sorted { $0.sort < $1.sort }
    }
    public func search(_ query: String, offset: Int = 0) async throws -> CatalogPage {
        let data = try JSONSerialization.data(withJSONObject: hub == nil
            ? ["keyword": query, "sort": "match", "filter": ["type": [2], "nsfw": false]]
            : ["keyword": query, "offset": offset])
        return try await request(CatalogPage.self, direct: "/v0/search/subjects?limit=24&offset=\(offset)", proxy: "v1/search", body: data)
    }
    public func credits(_ id: Int, characters: Bool) async throws -> [CatalogCredit] {
        let kind = characters ? "characters" : "persons"
        return try await request([CatalogCredit].self, direct: "/v0/subjects/\(id)/\(kind)", proxy: "v1/subjects/\(id)/\(kind)")
    }
    public func artwork(_ id: Int) async throws -> CatalogArtwork {
        guard hub != nil else { return CatalogArtwork(state: "notConfigured", candidates: [], selected: nil) }
        return try await request(CatalogArtwork.self, direct: "", proxy: "v1/subjects/\(id)/artwork")
    }
}

public enum CatalogError: LocalizedError { case unavailable
    public var errorDescription: String? { "暂时无法读取番剧资料，请检查网络后重试。" }
}
private final class CatalogRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
public struct CatalogHome: Decodable, Sendable {
    public let calendar: [CatalogDay]
    public let picks: CatalogPage
    public init(calendar: [CatalogDay], picks: CatalogPage) { self.calendar = calendar; self.picks = picks }
}
public struct CatalogDay: Decodable, Sendable {
    public struct Weekday: Decodable, Sendable { public let id: Int }
    public let weekday: Weekday
    public let items: [CatalogSubject]
    public var appleWeekday: Int { weekday.id % 7 + 1 }
}
public struct CatalogPage: Decodable, Sendable {
    public let total: Int
    public let data: [CatalogSubject]
}
public struct CatalogSubject: Decodable, Sendable {
    public struct Images: Decodable, Sendable { public let large: String?; public let common: String?; public let medium: String? }
    public struct Rating: Decodable, Sendable { public let score: Double?; public let rank: Int?; public let total: Int?; public let count: [String: Int]? }
    public struct Collection: Decodable, Sendable { public let doing: Int?; public let wish: Int?; public let collect: Int? }
    public struct Tag: Decodable, Sendable { public let name: String }
    public let id: Int
    public let type: Int?
    public let name: String
    public let name_cn: String?
    public let summary: String?
    public let date: String?
    public let air_date: String?
    public let platform: String?
    public let eps: Int?
    public let total_episodes: Int?
    public let images: Images?
    public let rating: Rating?
    public let collection: Collection?
    public let tags: [Tag]?
    public let nsfw: Bool?

    public func subject(weekday: Int = 0, fallback: Subject? = nil) -> Subject {
        let airDate = date ?? air_date ?? ""
        var result = Subject(id: "bgm-\(id)", bgmSubjectId: id, title: name_cn?.isEmpty == false ? name_cn! : name,
            originalTitle: name, tagline: [airDate, platform].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
            synopsis: summary?.isEmpty == false ? summary! : fallback?.synopsis ?? "暂无简介", year: Int(airDate.prefix(4)) ?? 0,
            season: platform ?? "动画", genres: tags.map { Array($0.prefix(3).map(\.name)) } ?? fallback?.genres ?? [], posterAsset: nil, backdropAsset: nil,
            accentHex: "8BB8C8", rating: rating?.score.flatMap { $0 > 0 ? $0 : nil }, totalEpisodes: max(0, eps.flatMap { $0 > 0 ? $0 : nil } ?? total_episodes ?? 0),
            weekday: weekday, broadcastTime: "时间未公布", followState: .planned, updateState: .scheduled, isSeasonPick: true,
            posterURL: Self.approvedImage(images?.large ?? images?.common ?? images?.medium), airDate: airDate)
        result.statistics = SubjectStatistics(rank: rating?.rank, ratingCount: rating?.total, distribution: rating?.count ?? [:], watching: collection?.doing, wish: collection?.wish, collected: collection?.collect)
        return result
    }
    public static func approvedImage(_ raw: String?) -> URL? {
        guard let raw, var parts = URLComponents(string: raw), let host = parts.host?.lowercased(),
              ["lain.bgm.tv", "lain.bangumi.tv"].contains(host), parts.user == nil, parts.password == nil,
              parts.port == nil, ["http", "https"].contains(parts.scheme) else { return nil }
        parts.scheme = "https"
        return parts.url
    }
}
public struct CatalogEpisodePage: Decodable, Sendable { public let total: Int; public let data: [CatalogEpisode] }
public struct CatalogEpisode: Decodable, Sendable {
    public let id: Int
    public let sort: Double
    public let ep: Double?
    public let name: String
    public let name_cn: String?
    public let desc: String?
    public let airdate: String?
    public let duration: String?
    public func episode(subjectID: String) -> Episode {
        let parts = (duration ?? "").split(separator: ":").compactMap { Double($0) }
        let seconds = parts.count == 3 ? parts[0] * 3600 + parts[1] * 60 + parts[2] : (parts.count == 2 ? parts[0] * 60 + parts[1] : 0)
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let ordinal = ep ?? sort
        let number = ordinal.isFinite && ordinal >= 0 && ordinal < 1_000_000 ? Int(ordinal) : 0
        return Episode(id: "bgm-ep-\(id)", bgmEpisodeId: id, subjectID: subjectID, number: number, sort: sort,
            title: name_cn?.isEmpty == false ? name_cn! : (name.isEmpty ? "第 \(sort.formatted()) 话" : name), synopsis: desc ?? "",
            durationSeconds: seconds, airDate: airdate.flatMap(formatter.date), availability: .unavailable)
    }
}
public struct CatalogArtwork: Decodable, Sendable {
    public let state: String
    public let candidates: [ArtworkCandidate]
    public let selected: ArtworkCandidate?
    public init(state: String, candidates: [ArtworkCandidate], selected: ArtworkCandidate?) { self.state = state; self.candidates = candidates; self.selected = selected }
}
public struct ArtworkCandidate: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let mediaType: String
    public let title: String
    public let originalTitle: String
    public let year: String
    public let backdropURL: String?
    public let exactMatch: Bool
    public var identity: String { "\(mediaType)-\(id)" }
}

public struct CatalogCredit: Decodable, Identifiable, Sendable {
    public struct Images: Decodable, Sendable { public let large: String?; public let medium: String?; public let small: String? }
    public struct Actor: Decodable, Sendable { public let id: Int; public let name: String }
    public let id: Int
    public let name: String
    public let relation: String?
    public let images: Images?
    public let actors: [Actor]?
    public func merging(_ other: CatalogCredit) -> CatalogCredit {
        var relations = [String]()
        for value in [relation, other.relation].compactMap({ $0 }) where !relations.contains(value) { relations.append(value) }
        var seen = Set<Int>()
        let combinedActors = ((actors ?? []) + (other.actors ?? [])).filter { seen.insert($0.id).inserted }
        return CatalogCredit(id: id, name: name, relation: relations.joined(separator: " / "), images: images ?? other.images, actors: combinedActors)
    }
    public var imageURL: URL? { CatalogSubject.approvedImage(images?.large ?? images?.medium ?? images?.small) }
    public var subtitle: String { [relation, actors?.map(\.name).joined(separator: " / ")].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ") }
}
