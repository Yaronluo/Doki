import Foundation
import Testing
@testable import DokiCore

@Suite("Bangumi route policy")
struct BangumiRouteTests {
    private let request = URLRequest(url: URL(string: "https://api.bgm.tv/calendar")!)

    @Test("Official timeout falls back to the mirror and sticks")
    func fallbackAndSticky() async throws {
        let stub = StubBangumiTransport([
            "api.bgm.tv": [.failure(.timedOut)],
            "api.bangumi.lat": [
                .response(statusCode: 200, body: "{}", contentType: "application/json"),
                .response(statusCode: 200, body: "{}", contentType: "application/json")
            ]
        ])
        let policy = BangumiRoutePolicy(
            configuration: .init(
                mode: .auto,
                mirrorRoots: ["bangumi.lat"],
                probeTimeout: 0.1,
                requestTimeout: 0.1,
                stickyDuration: 1_800,
                officialCooldown: 60
            ),
            transport: stub
        )

        let first = try await policy.send(request)
        #expect(first.route.kind == .mirror)
        #expect(first.route.root == "bangumi.lat")

        let second = try await policy.send(request)
        #expect(second.route == first.route)
        #expect(await stub.requestedHosts == ["api.bgm.tv", "api.bangumi.lat", "api.bangumi.lat"])
        #expect(policy.currentStatus.active == first.route)
    }

    @Test("A 404 is an answer, not a route failure")
    func clientErrorDoesNotFallBack() async throws {
        let stub = StubBangumiTransport([
            "api.bgm.tv": [.response(statusCode: 404, body: "{}", contentType: "application/json")],
            "api.bangumi.lat": [.response(statusCode: 200, body: "{}", contentType: "application/json")]
        ])
        let policy = BangumiRoutePolicy(
            configuration: .init(mode: .auto, mirrorRoots: ["bangumi.lat"], probeTimeout: 0.1, requestTimeout: 0.1),
            transport: stub
        )

        let result = try await policy.send(request)
        #expect(result.statusCode == 404)
        #expect(await stub.requestedHosts == ["api.bgm.tv"])
    }

    @Test("An HTML anti-bot page on an API host falls back to the next route")
    func htmlFallsBack() async throws {
        let stub = StubBangumiTransport([
            "api.bgm.tv": [.response(statusCode: 200, body: "<html>challenge</html>", contentType: "text/html; charset=utf-8")],
            "api.bangumi.lat": [.response(statusCode: 200, body: "{}", contentType: "application/json")]
        ])
        let policy = BangumiRoutePolicy(
            configuration: .init(mode: .auto, mirrorRoots: ["bangumi.lat"], probeTimeout: 0.1, requestTimeout: 0.1),
            transport: stub
        )

        let result = try await policy.send(request)
        #expect(result.route.kind == .mirror)
        #expect(result.statusCode == 200)
    }

    @Test("A 5xx falls back to the next route")
    func serverErrorFallsBack() async throws {
        let stub = StubBangumiTransport([
            "api.bgm.tv": [.response(statusCode: 503, body: "{}", contentType: "application/json")],
            "api.bangumi.lat": [.response(statusCode: 200, body: "{}", contentType: "application/json")]
        ])
        let policy = BangumiRoutePolicy(
            configuration: .init(mode: .auto, mirrorRoots: ["bangumi.lat"], probeTimeout: 0.1, requestTimeout: 0.1),
            transport: stub
        )

        let result = try await policy.send(request)
        #expect(result.route.kind == .mirror)
    }

    @Test("Credentials never go to a third-party mirror")
    func credentialsStayOnTrustedRoutes() async throws {
        let stub = StubBangumiTransport([
            "api.bgm.tv": [.failure(.timedOut)],
            "api.bangumi.lat": [.response(statusCode: 200, body: "{}", contentType: "application/json")]
        ])
        let policy = BangumiRoutePolicy(
            configuration: .init(mode: .auto, mirrorRoots: ["bangumi.lat"], probeTimeout: 0.1, requestTimeout: 0.1),
            transport: stub
        )
        var authenticated = request
        authenticated.setValue("Bearer secret", forHTTPHeaderField: "Authorization")

        do {
            _ = try await policy.send(authenticated)
            Issue.record("Expected no eligible route for a credentialed request")
        } catch {
            #expect(await stub.requestedHosts == ["api.bgm.tv"])
        }
    }

    @Test("Image hosts map between the official and mirror image origins")
    func imageMapping() {
        let mirror = BangumiRoutePolicy(
            configuration: .init(mode: .mirror, mirrorRoots: ["bangumi.lat"]),
            transport: StubBangumiTransport([:])
        )
        #expect(mirror.currentImageHost == "lain.bangumi.lat")
        #expect(mirror.imageURL("https://lain.bgm.tv/pic/cover/l/test.jpg")?.host == "lain.bangumi.lat")
        #expect(mirror.imageURL("https://lain.bangumi.lat/pic/cover/l/test.jpg")?.host == "lain.bangumi.lat")
        #expect(mirror.imageURL("https://lain.bgm.tv.evil.example/pic/cover/l/test.jpg") == nil)
        #expect(mirror.imageURL("https://user:password@lain.bgm.tv/test.jpg") == nil)
        #expect(mirror.imageURL("https://lain.bgm.tv:8443/test.jpg") == nil)
        #expect(mirror.imageURL("https://127.0.0.1/test.jpg") == nil)
        #expect(mirror.alternateImageURL(URL(string: "https://lain.bangumi.lat/pic/cover/l/test.jpg"))?.host == "lain.bgm.tv")
        #expect(mirror.alternateImageURL(URL(string: "https://lain.bgm.tv/pic/cover/l/test.jpg"))?.host == "lain.bangumi.lat")
        #expect(mirror.alternateImageURL(URL(string: "https://evil.example/test.jpg")) == nil)

        let official = BangumiRoutePolicy(
            configuration: .init(mode: .official),
            transport: StubBangumiTransport([:])
        )
        #expect(official.imageURL("https://lain.bangumi.lat/pic/cover/l/test.jpg")?.host == "lain.bgm.tv")
    }

    @Test("Mirror roots reject ports, IPs and malformed labels")
    func rootNormalization() {
        #expect(BangumiRoute.normalizedRoot("https://api.bangumi.lat/path") == "bangumi.lat")
        #expect(BangumiRoute.normalizedRoot("bangumi.lat") == "bangumi.lat")
        #expect(BangumiRoute.normalizedRoot("api.bangumi.lat") == "bangumi.lat")
        #expect(BangumiRoute.normalizedRoot("bangumi.lat:443") == nil)
        #expect(BangumiRoute.normalizedRoot("127.0.0.1") == nil)
        #expect(BangumiRoute.normalizedRoot("localhost") == nil)
        #expect(BangumiRoute.normalizedRoot("https://bangumi.lat/a/b") == "bangumi.lat")
    }

    @Test("Sticky mirror expires and official is probed again")
    func stickyExpiry() async throws {
        let clock = RouteClock()
        let stub = StubBangumiTransport([
            "api.bgm.tv": [.failure(.timedOut), .failure(.timedOut)],
            "api.bangumi.lat": [
                .response(statusCode: 200, body: "{}", contentType: "application/json"),
                .response(statusCode: 200, body: "{}", contentType: "application/json")
            ]
        ])
        let policy = BangumiRoutePolicy(
            configuration: .init(
                mode: .auto,
                mirrorRoots: ["bangumi.lat"],
                probeTimeout: 0.1,
                requestTimeout: 0.1,
                stickyDuration: 30,
                officialCooldown: 0
            ),
            transport: stub,
            clock: { clock.now }
        )

        _ = try await policy.send(request)
        clock.advance(31)
        _ = try await policy.send(request)
        #expect(await stub.requestedHosts == ["api.bgm.tv", "api.bangumi.lat", "api.bgm.tv", "api.bangumi.lat"])
    }

    @Test("A mirror image accepted by the route policy reaches Subject.posterURL")
    func mirrorImageInSubject() throws {
        let policy = BangumiRoutePolicy(
            configuration: .init(mode: .mirror, mirrorRoots: ["bangumi.lat"]),
            transport: StubBangumiTransport([:])
        )
        let data = Data(#"{"id":1,"name":"x","images":{"large":"https://lain.bangumi.lat/pic/cover/l/x.jpg"}}"#.utf8)
        let subject = try JSONDecoder().decode(CatalogSubject.self, from: data)
            .subject(imageURL: { policy.imageURL($0) })
        #expect(subject.posterURL?.host == "lain.bangumi.lat")
    }
}

private actor StubBangumiTransport: BangumiTransport {
    enum Reply: Sendable {
        case response(statusCode: Int, body: String, contentType: String)
        case failure(URLError.Code)
    }

    private var replies: [String: [Reply]]
    private(set) var requestedHosts: [String] = []

    init(_ replies: [String: [Reply]]) {
        self.replies = replies
    }

    func send(_ request: URLRequest) async throws -> BangumiHTTPResult {
        let host = request.url?.host ?? ""
        requestedHosts.append(host)
        guard var queue = replies[host], !queue.isEmpty else {
            throw URLError(.cannotFindHost)
        }
        let reply = queue.removeFirst()
        replies[host] = queue
        switch reply {
        case let .response(statusCode, body, contentType):
            return BangumiHTTPResult(
                data: Data(body.utf8),
                statusCode: statusCode,
                headers: ["content-type": contentType]
            )
        case let .failure(code):
            throw URLError(code)
        }
    }
}

private final class RouteClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_000_000)

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func advance(_ seconds: TimeInterval) {
        lock.lock()
        value = value.addingTimeInterval(seconds)
        lock.unlock()
    }
}
