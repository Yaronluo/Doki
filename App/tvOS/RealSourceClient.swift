import Foundation

struct RealSourcePreviewPlan: Decodable, Hashable {
    struct Provider: Decodable, Hashable {
        let id: String
        let name: String
    }

    struct Subject: Decodable, Hashable {
        let name: String
        let sourceSubjectKey: String
    }

    struct Episode: Decodable, Hashable {
        let number: Int
        let title: String
        let channel: String
        let mediaId: String
    }

    struct Source: Decodable, Hashable {
        let mode: String
        let url: String
        let expiresAt: String
    }

    struct Tracks: Decodable, Hashable {
        let subtitleLanguages: [String]
        let hasAlternateAudio: Bool
    }

    struct Capabilities: Decodable, Hashable {
        let canSeek: Bool
        let canAutoFailover: Bool
    }

    struct Provenance: Decodable, Hashable {
        let ruleCommit: String
        let snapshotSha256: String
        let verifiedAt: String
    }

    let sessionId: String
    let status: String
    let provider: Provider
    let subject: Subject
    let episode: Episode
    let source: Source
    let tracks: Tracks
    let capabilities: Capabilities
    let durationHintSeconds: Double
    let provenance: Provenance

    var sourceURL: URL? {
        guard let url = URL(string: source.url),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return nil }
        return url
    }
}

enum RealSourceClientError: LocalizedError {
    case invalidHubURL
    case notConfigured
    case http(status: Int, code: String, message: String, requestId: String?)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidHubURL:
            "Hub 地址不是有效的 http(s) URL。"
        case .notConfigured:
            "Hub 未配置。"
        case .http(let status, let code, let message, let requestId):
            "Hub \(status) · \(code)：\(message)"
                + (requestId.map { "（请求 \($0)）" } ?? "")
        case .invalidResponse:
            "Hub 返回了无法解析的真实源计划。"
        }
    }
}

private struct RealSourceRequest: Encodable {
    let query: String
    let episodeNumber: Int
}

private struct HubErrorPayload: Decodable {
    let code: String?
    let message: String?
    let requestId: String?
}

enum RealSourceClient {
    static func preview(
        hubBaseURL: URL,
        query: String,
        episodeNumber: Int
    ) async throws -> RealSourcePreviewPlan {
        var components = URLComponents(
            url: hubBaseURL,
            resolvingAgainstBaseURL: false
        )
        guard let scheme = components?.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components?.host != nil else {
            throw RealSourceClientError.invalidHubURL
        }
        let basePath = components?.path.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        ) ?? ""
        components?.path = "/" + (basePath.isEmpty ? "" : "\(basePath)/") + "v1/dev/source-preview"
        components?.query = nil
        components?.fragment = nil
        guard let endpoint = components?.url else {
            throw RealSourceClientError.invalidHubURL
        }

        var request = URLRequest(url: endpoint, timeoutInterval: 75)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        request.httpBody = try JSONEncoder().encode(
            RealSourceRequest(query: query, episodeNumber: episodeNumber)
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw RealSourceClientError.http(
                status: 0,
                code: "HUB_UNREACHABLE",
                message: (error as? any LocalizedError)?.errorDescription
                    ?? "无法连接 Hub。",
                requestId: nil
            )
        }

        guard let http = response as? HTTPURLResponse else {
            throw RealSourceClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(HubErrorPayload.self, from: data)
            throw RealSourceClientError.http(
                status: http.statusCode,
                code: payload?.code ?? "HUB_ERROR",
                message: payload?.message ?? "Hub 返回错误。",
                requestId: payload?.requestId
            )
        }

        do {
            return try JSONDecoder().decode(RealSourcePreviewPlan.self, from: data)
        } catch {
            throw RealSourceClientError.invalidResponse
        }
    }
}
