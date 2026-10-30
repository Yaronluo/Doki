import Foundation

public struct HubPairing: Decodable, Sendable { public let id: String; public let code: String; public let secret: String; public let expiresIn: Int }
public struct HubPairingClaim: Decodable, Sendable { public let deviceId: String; public let token: String }
public struct BangumiAccount: Decodable, Sendable { public let id: Int; public let username: String; public let nickname: String; public let avatar: String? }
public struct HubAccountStatus: Decodable, Sendable { public let paired: Bool; public let bangumi: BangumiAccount? }
public struct AccountCollectionItem: Decodable, Sendable { public let subject_id: Int; public let type: Int; public let subject: CatalogSubject }
public struct AccountCollectionPage: Decodable, Sendable { public let total: Int; public let data: [AccountCollectionItem] }
public struct HubAccountError: LocalizedError, Sendable {
    public let status: Int
    public let message: String
    public var errorDescription: String? { message }
}
public actor HubAccountClient {
    private let hub: URL
    private let session: URLSession
    public init(hub: URL) {
        self.hub = hub
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false; config.httpCookieStorage = nil; config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config, delegate: AccountRedirectPolicy(), delegateQueue: nil)
    }
    private func request<T: Decodable & Sendable>(_ type: T.Type, _ path: String, method: String = "GET", authorization: String? = nil, body: Data? = nil) async throws -> T {
        let root = hub.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: root + path) else { throw URLError(.badURL) }
        var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body, !body.isEmpty { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let authorization { request.setValue(authorization, forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, data.count <= 5 * 1024 * 1024 else { throw CatalogError.unavailable }
        guard (200..<300).contains(http.statusCode) else {
            throw HubAccountError(status: http.statusCode, message: http.statusCode == 401 ? "电视尚未配对或登录已失效，请在 Hub 完成连接。" : "暂时无法连接账号服务，请检查 Hub 后重试。")
        }
        return try JSONDecoder().decode(type, from: data)
    }
    public func createPairing() async throws -> HubPairing {
        try await request(HubPairing.self, "/v1/devices/pairings", method: "POST", body: Data(#"{"name":"Apple TV"}"#.utf8))
    }
    public func pairingStatus(_ pairing: HubPairing) async throws -> String {
        struct Status: Decodable, Sendable { let state: String }
        return try await request(Status.self, "/v1/devices/pairings/\(pairing.id)", authorization: "Pairing \(pairing.secret)").state
    }
    public func claim(_ pairing: HubPairing) async throws -> HubPairingClaim {
        try await request(HubPairingClaim.self, "/v1/devices/pairings/\(pairing.id)/claim", method: "POST", authorization: "Pairing \(pairing.secret)")
    }
    public func status(token: String) async throws -> HubAccountStatus { try await request(HubAccountStatus.self, "/v1/account", authorization: "Bearer \(token)") }
    public func collections(token: String) async throws -> [AccountCollectionItem] {
        var items: [AccountCollectionItem] = []; var offset = 0
        while offset < 10000 {
            let page = try await request(AccountCollectionPage.self, "/v1/account/collections?offset=\(offset)", authorization: "Bearer \(token)")
            items += page.data; offset += page.data.count
            if page.data.isEmpty || offset >= page.total { break }
        }
        return items
    }
}
private final class AccountRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}
