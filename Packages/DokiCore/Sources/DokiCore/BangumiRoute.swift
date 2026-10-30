import Foundation

/// 用户选择的 Bangumi 连接方式。匿名公开资料可以在官方连不上时走镜像；
/// 账号令牌只允许经过官方或自建反代。
public enum BangumiRouteMode: String, CaseIterable, Codable, Sendable {
    case auto
    case official
    case mirror
    case custom
}

/// 一条发往 Bangumi 的线路。镜像和自建都按通配子域映射：
/// `bgm.tv -> <root>`、`api.bgm.tv -> api.<root>`、`lain.bgm.tv -> lain.<root>`。
public struct BangumiRoute: Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case official
        case custom
        case mirror
    }

    public let kind: Kind
    public let root: String?

    public static let official = BangumiRoute(kind: .official, root: nil)

    private init(kind: Kind, root: String?) {
        self.kind = kind
        self.root = root
    }

    public static func custom(_ raw: String) -> BangumiRoute? {
        guard let root = normalizedRoot(raw) else { return nil }
        return BangumiRoute(kind: .custom, root: root)
    }

    public static func mirror(_ raw: String) -> BangumiRoute? {
        guard let root = normalizedRoot(raw) else { return nil }
        return BangumiRoute(kind: .mirror, root: root)
    }

    /// 当前内置的镜像。`bangumi.vip` 会 301 到 `bangumi.lat`，
    /// 这里先只放最终域名，避免跨域重定向丢掉请求语义。
    public static let bundledMirrorRoots = ["bangumi.lat"]

    public var label: String {
        switch kind {
        case .official: "官方"
        case .custom: "自建 \(root ?? "")"
        case .mirror: "镜像 \(root ?? "")"
        }
    }

    public var apiHost: String {
        root.map { "api.\($0)" } ?? "api.bgm.tv"
    }

    public var imageHost: String {
        root.map { "lain.\($0)" } ?? "lain.bgm.tv"
    }

    public var servesMainSite: Bool {
        kind != .mirror
    }

    public var isThirdParty: Bool {
        kind == .mirror
    }

    /// 把官方域名换算到这条线路上。不是 Bangumi 域名时返回 `nil`。
    public func host(forCanonical host: String) -> String? {
        guard let canonical = Self.canonicalBangumiHost(host) else { return nil }
        guard let root else { return canonical }
        if canonical == "bgm.tv" { return root }
        guard canonical.hasSuffix(".bgm.tv") else { return nil }
        return String(canonical.dropLast("bgm.tv".count)) + root
    }

    /// 把线路上的域名换回官方域名。不是这条线路的域名时返回 `nil`。
    public func canonicalHost(for host: String) -> String? {
        guard let root else { return Self.canonicalBangumiHost(host) }
        let normalized = host.lowercased()
        if normalized == root { return "bgm.tv" }
        guard normalized.hasSuffix(".\(root)") else { return nil }
        return String(normalized.dropLast(root.count)) + "bgm.tv"
    }

    /// 把官方地址换到这条线路上，保留 path 和 query。
    public func url(for canonical: URL) -> URL? {
        guard var parts = URLComponents(url: canonical, resolvingAgainstBaseURL: false),
              let originalHost = parts.host,
              let mapped = host(forCanonical: originalHost) else { return nil }
        parts.scheme = "https"
        parts.host = mapped
        parts.port = nil
        return parts.url
    }

    /// 官方域名（含 `bangumi.tv` 别名）归一成 `*.bgm.tv`。
    public static func canonicalBangumiHost(_ raw: String) -> String? {
        let host = raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !host.isEmpty else { return nil }
        if host == "bgm.tv" || host.hasSuffix(".bgm.tv") { return host }
        if host == "bangumi.tv" || host.hasSuffix(".bangumi.tv") {
            return String(host.dropLast("bangumi.tv".count)) + "bgm.tv"
        }
        return nil
    }

    /// 把用户填的镜像地址归一成裸根域名。只接受有至少两段、TLD 为字母的域名，
    /// 拒绝 IP、端口、路径、userinfo 和 Unicode。
    public static func normalizedRoot(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("https://") {
            value.removeFirst("https://".count)
        } else if value.hasPrefix("http://") {
            value.removeFirst("http://".count)
        } else if value.contains("://") {
            return nil
        }
        if let separator = value.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) {
            value = String(value[..<separator])
        }
        guard !value.isEmpty, !value.contains("@"), !value.contains(":") else { return nil }
        var labels = value.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty && $0.count <= 63 }) else { return nil }
        for label in labels {
            guard let first = label.first, let last = label.last,
                  isASCIIAlphanumeric(first), isASCIIAlphanumeric(last),
                  label.allSatisfy({ isASCIIAlphanumeric($0) || $0 == "-" }) else { return nil }
        }
        guard let tld = labels.last, tld.count >= 2, tld.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        if labels.count > 2, ["api", "next", "lain", "www", "fast", "doujin"].contains(labels[0]) {
            labels.removeFirst()
        }
        let root = labels.joined(separator: ".")
        guard root.count <= 253 else { return nil }
        return root
    }

    private static func isASCIIAlphanumeric(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber)
    }
}

public struct BangumiRouteConfiguration: Sendable {
    public var mode: BangumiRouteMode
    public var customRoot: String?
    public var mirrorRoots: [String]
    /// 官方不是最后一个候选时，探测请求的总超时（连接失败通常卡在这里）。
    public var probeTimeout: TimeInterval
    /// 最后一个候选和写请求使用的正常超时。
    public var requestTimeout: TimeInterval
    /// 非官方线路成功后记住多久。
    public var stickyDuration: TimeInterval
    /// 官方连接失败后，暂时不再先试官方的时间。
    public var officialCooldown: TimeInterval

    public init(
        mode: BangumiRouteMode = .auto,
        customRoot: String? = nil,
        mirrorRoots: [String] = BangumiRoute.bundledMirrorRoots,
        probeTimeout: TimeInterval = 6,
        requestTimeout: TimeInterval = 18,
        stickyDuration: TimeInterval = 30 * 60,
        officialCooldown: TimeInterval = 60
    ) {
        self.mode = mode
        self.customRoot = customRoot
        self.mirrorRoots = mirrorRoots.compactMap(BangumiRoute.normalizedRoot)
        self.probeTimeout = probeTimeout
        self.requestTimeout = requestTimeout
        self.stickyDuration = stickyDuration
        self.officialCooldown = officialCooldown
    }
}

public struct BangumiRouteStatus: Equatable, Sendable {
    public var active: BangumiRoute?
    public var lastLatencyMilliseconds: Int?
    public var lastError: String?

    public init(active: BangumiRoute? = nil, lastLatencyMilliseconds: Int? = nil, lastError: String? = nil) {
        self.active = active
        self.lastLatencyMilliseconds = lastLatencyMilliseconds
        self.lastError = lastError
    }
}

public struct BangumiRouteResponse: Sendable {
    public let data: Data
    public let statusCode: Int
    public let route: BangumiRoute
    public let latencyMilliseconds: Int

    public init(data: Data, statusCode: Int, route: BangumiRoute, latencyMilliseconds: Int) {
        self.data = data
        self.statusCode = statusCode
        self.route = route
        self.latencyMilliseconds = latencyMilliseconds
    }
}

public struct BangumiHTTPResult: Sendable {
    public let data: Data
    public let statusCode: Int
    public let headers: [String: String]

    public init(data: Data, statusCode: Int, headers: [String: String] = [:]) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }
}

public protocol BangumiTransport: Sendable {
    func send(_ request: URLRequest) async throws -> BangumiHTTPResult
}

public enum BangumiRouteError: LocalizedError, Sendable {
    case noEligibleRoute

    public var errorDescription: String? {
        "没有可用于当前请求的 Bangumi 线路。"
    }
}

/// 按配置的顺序尝试线路；只有连接失败、5xx、3xx 或 API 返回网页时才换下一条。
/// 4xx 是对方在回答，不换线，也不改粘性。
public final class BangumiRoutePolicy: @unchecked Sendable {
    private struct SendSnapshot {
        let routes: [BangumiRoute]
        let probeTimeout: TimeInterval
        let requestTimeout: TimeInterval
    }

    private let lock = NSLock()
    private let transport: any BangumiTransport
    private let clock: @Sendable () -> Date
    private var configuration: BangumiRouteConfiguration
    private var routes: [BangumiRoute]
    private var sticky: (route: BangumiRoute, at: Date)?
    private var officialSkipUntil: Date?
    private var status = BangumiRouteStatus()

    public init(
        configuration: BangumiRouteConfiguration = BangumiRouteConfiguration(),
        transport: any BangumiTransport = URLSessionBangumiTransport(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.transport = transport
        self.clock = clock
        self.routes = Self.routes(for: configuration)
    }

    public func update(configuration: BangumiRouteConfiguration) {
        withLock {
            self.configuration = configuration
            self.routes = Self.routes(for: configuration)
            self.sticky = nil
            self.officialSkipUntil = nil
            self.status = BangumiRouteStatus()
        }
    }

    public var currentStatus: BangumiRouteStatus {
        withLock { status }
    }

    public var preferredRoute: BangumiRoute {
        withLock { status.active ?? routes.first ?? .official }
    }

    public var currentImageHost: String {
        withLock { currentImageHostLocked() }
    }

    /// 已知的 `lain.*` 图床域名。模型里存的是官方或镜像地址，显示前统一映射。
    public var knownImageHosts: Set<String> {
        withLock { knownImageHostsLocked() }
    }

    /// 同一个图片在另一条线路上的地址；用于图片抢跑，官方和镜像谁先回谁赢。
    /// 只接受已知的 `lain.*` 域名，其他地址返回 `nil`。
    public func alternateImageURL(_ url: URL?) -> URL? {
        guard let url, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = parts.host?.lowercased(),
              parts.user == nil, parts.password == nil, parts.port == nil else { return nil }
        let (hosts, target) = withLock { (knownImageHostsLocked(), currentImageHostLocked()) }
        guard hosts.contains(host) else { return nil }
        let alternate = (host == "lain.bgm.tv" || host == "lain.bangumi.tv") ? target : "lain.bgm.tv"
        guard alternate != host else { return nil }
        parts.scheme = "https"
        parts.host = alternate
        return parts.url
    }

    /// 把图床地址映射到当前线路。只接受已知的 `lain.*` 域名。
    public func imageURL(_ raw: String?) -> URL? {
        guard let raw, var parts = URLComponents(string: raw),
              let host = parts.host?.lowercased(),
              parts.user == nil, parts.password == nil, parts.port == nil,
              let scheme = parts.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        let (hosts, target) = withLock { (knownImageHostsLocked(), currentImageHostLocked()) }
        guard hosts.contains(host) else { return nil }
        parts.scheme = "https"
        parts.host = target
        return parts.url
    }

    public func send(_ request: URLRequest, retryable: Bool = true) async throws -> BangumiRouteResponse {
        let carriesCredentials = request.value(forHTTPHeaderField: "Authorization") != nil
        let snapshot = sendSnapshot(carriesCredentials: carriesCredentials)
        guard let canonicalURL = request.url, !snapshot.routes.isEmpty else {
            throw BangumiRouteError.noEligibleRoute
        }

        var lastError: (any Error)?
        var lastServerResponse: BangumiRouteResponse?

        for (index, route) in snapshot.routes.enumerated() {
            guard let target = route.url(for: canonicalURL) else { continue }
            var attempt = request
            attempt.url = target
            let isLast = index == snapshot.routes.count - 1
            attempt.timeoutInterval = (retryable && !isLast) ? snapshot.probeTimeout : snapshot.requestTimeout

            let started = clock()
            do {
                let result = try await transport.send(attempt)
                let latency = max(0, Int(clock().timeIntervalSince(started) * 1000))

                switch result.statusCode {
                case 500...:
                    lastError = URLError(.badServerResponse)
                    lastServerResponse = BangumiRouteResponse(
                        data: result.data,
                        statusCode: result.statusCode,
                        route: route,
                        latencyMilliseconds: latency
                    )
                    continue
                case 300..<400:
                    lastError = URLError(.httpTooManyRedirects)
                    continue
                case 400..<500:
                    recordAnswer(route: route, latency: latency)
                    return BangumiRouteResponse(
                        data: result.data,
                        statusCode: result.statusCode,
                        route: route,
                        latencyMilliseconds: latency
                    )
                default:
                    if isHTML(result), isAPIHost(canonicalURL.host) {
                        lastError = URLError(.cannotParseResponse)
                        continue
                    }
                    settle(route: route, latency: latency)
                    return BangumiRouteResponse(
                        data: result.data,
                        statusCode: result.statusCode,
                        route: route,
                        latencyMilliseconds: latency
                    )
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if Task.isCancelled { throw CancellationError() }
                lastError = error
                if route.kind == .official { markOfficialFailure() }
                continue
            }
        }

        recordFailure(lastError)
        if let lastServerResponse { return lastServerResponse }
        throw lastError ?? URLError(.cannotConnectToHost)
    }

    private func sendSnapshot(carriesCredentials: Bool) -> SendSnapshot {
        withLock {
            let now = clock()
            var candidates = routes
            if carriesCredentials {
                candidates = candidates.filter(\.servesMainSite)
            }
            if candidates.count > 1, let until = officialSkipUntil, until > now,
               let index = candidates.firstIndex(of: .official) {
                candidates.remove(at: index)
            }
            if let sticky, sticky.at.addingTimeInterval(configuration.stickyDuration) > now,
               let index = candidates.firstIndex(of: sticky.route) {
                candidates = Array(candidates[index...]) + Array(candidates[..<index])
            }
            return SendSnapshot(
                routes: candidates,
                probeTimeout: configuration.probeTimeout,
                requestTimeout: configuration.requestTimeout
            )
        }
    }

    private func settle(route: BangumiRoute, latency: Int) {
        withLock {
            status.active = route
            status.lastLatencyMilliseconds = latency
            status.lastError = nil
            if route.kind == .official {
                sticky = nil
                officialSkipUntil = nil
            } else {
                sticky = (route, clock())
            }
        }
    }

    private func recordAnswer(route: BangumiRoute, latency: Int) {
        withLock {
            status.active = route
            status.lastLatencyMilliseconds = latency
            status.lastError = nil
        }
    }

    private func recordFailure(_ error: (any Error)?) {
        withLock {
            status.lastError = error.map { error in
                (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
            } ?? "所有 Bangumi 线路均不可用"
        }
    }

    private func markOfficialFailure() {
        withLock {
            officialSkipUntil = clock().addingTimeInterval(configuration.officialCooldown)
        }
    }

    private func currentImageHostLocked() -> String {
        status.active?.imageHost ?? routes.first?.imageHost ?? BangumiRoute.official.imageHost
    }

    private func knownImageHostsLocked() -> Set<String> {
        var hosts: Set<String> = ["lain.bgm.tv", "lain.bangumi.tv"]
        for route in routes where route.kind != .official {
            hosts.insert(route.imageHost)
        }
        // 官方模式下也要认得出先前缓存里留下的镜像图床地址，才能换回官方。
        for root in configuration.mirrorRoots {
            if let route = BangumiRoute.mirror(root) { hosts.insert(route.imageHost) }
        }
        if let custom = configuration.customRoot, let route = BangumiRoute.custom(custom) {
            hosts.insert(route.imageHost)
        }
        return hosts
    }

    private func isHTML(_ result: BangumiHTTPResult) -> Bool {
        result.headers["content-type"]?.lowercased().contains("text/html") == true
    }

    private func isAPIHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "api.bgm.tv" || host == "next.bgm.tv" ||
            host == "api.bangumi.tv" || host == "next.bangumi.tv"
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private static func routes(for configuration: BangumiRouteConfiguration) -> [BangumiRoute] {
        let mirrors = configuration.mirrorRoots.compactMap(BangumiRoute.mirror)
        let custom = configuration.customRoot.flatMap(BangumiRoute.custom).map { [$0] } ?? []
        let ordered: [BangumiRoute]
        switch configuration.mode {
        case .official:
            ordered = [.official]
        case .mirror:
            ordered = mirrors.isEmpty ? [.official] : mirrors + [.official]
        case .custom:
            ordered = custom + [.official] + mirrors
        case .auto:
            ordered = [.official] + custom + mirrors
        }
        var seen = Set<BangumiRoute>()
        return ordered.filter { seen.insert($0).inserted }
    }
}

/// 生产环境的 URLSession 传输。重定向一律拒绝；镜像列表里只放最终域名。
public final class URLSessionBangumiTransport: BangumiTransport, @unchecked Sendable {
    private let session: URLSession
    private let redirectDelegate: BangumiRedirectDelegate

    public init(timeout: TimeInterval = 18) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = max(timeout, 30)
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let delegate = BangumiRedirectDelegate()
        self.redirectDelegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    public func send(_ request: URLRequest) async throws -> BangumiHTTPResult {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.expectedContentLength > 8 * 1024 * 1024 {
            throw URLError(.dataLengthExceedsMaximum)
        }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key.lowercased()] = value
            }
        }
        return BangumiHTTPResult(data: data, statusCode: http.statusCode, headers: headers)
    }

    deinit {
        session.invalidateAndCancel()
    }
}

private final class BangumiRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
