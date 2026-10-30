import Foundation

/// A Bangumi-shaped subject used by the TV client.
///
/// `bgmSubjectId` is the stable metadata identity. `id` is Doki's local fixture
/// identity for this prototype and is deliberately not a TMDB or provider id.
public struct Subject: Identifiable, Hashable, Codable, Sendable {
    public enum FollowState: String, Codable, CaseIterable, Sendable {
        case watching
        case planned
        case completed
        case paused
        case dropped

        public var title: String {
            switch self {
            case .watching: "追看中"
            case .planned: "想看"
            case .completed: "已完成"
            case .paused: "已搁置"
            case .dropped: "已抛弃"
            }
        }
    }

    public enum UpdateState: String, Codable, Sendable {
        case available
        case scheduled
        case unavailable

        public var title: String {
            switch self {
            case .available: "已可播"
            case .scheduled: "计划放送"
            case .unavailable: "暂无资源"
            }
        }
    }

    public let id: String
    public let bgmSubjectId: Int
    public let title: String
    public let originalTitle: String
    public let tagline: String
    public let synopsis: String
    public let year: Int
    public let season: String
    public let genres: [String]
    public let posterAsset: String?
    public let backdropAsset: String?
    public var posterURL: URL?
    public var backdropURL: URL?
    public var titleLogoURL: URL?
    public var titleLogoAspect: Double?
    public var statistics: SubjectStatistics?
    public let airDate: String?
    public var isRealCatalog: Bool { id.hasPrefix("bgm-") }
    public let accentHex: String
    public let rating: Double?
    public let totalEpisodes: Int
    /// Calendar weekday, 1 = Sunday ... 7 = Saturday.
    public let weekday: Int
    public let broadcastTime: String
    public var followState: FollowState
    public var updateState: UpdateState
    public let isSeasonPick: Bool

    public init(
        id: String,
        bgmSubjectId: Int,
        title: String,
        originalTitle: String,
        tagline: String,
        synopsis: String,
        year: Int,
        season: String,
        genres: [String],
        posterAsset: String?,
        backdropAsset: String?,
        accentHex: String,
        rating: Double?,
        totalEpisodes: Int,
        weekday: Int,
        broadcastTime: String,
        followState: FollowState,
        updateState: UpdateState,
        isSeasonPick: Bool,
        posterURL: URL? = nil,
        backdropURL: URL? = nil,
        airDate: String? = nil,
        titleLogoURL: URL? = nil,
        titleLogoAspect: Double? = nil
    ) {
        self.titleLogoURL = titleLogoURL
        self.titleLogoAspect = titleLogoAspect
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.airDate = airDate
        self.id = id
        self.bgmSubjectId = bgmSubjectId
        self.title = title
        self.originalTitle = originalTitle
        self.tagline = tagline
        self.synopsis = synopsis
        self.year = year
        self.season = season
        self.genres = genres
        self.posterAsset = posterAsset
        self.backdropAsset = backdropAsset
        self.accentHex = accentHex
        self.rating = rating
        self.totalEpisodes = totalEpisodes
        self.weekday = weekday
        self.broadcastTime = broadcastTime
        self.followState = followState
        self.updateState = updateState
        self.isSeasonPick = isSeasonPick
    }
}

public struct Episode: Identifiable, Hashable, Codable, Sendable {
    public enum Availability: String, Codable, Sendable {
        case available
        case scheduled
        case unavailable

        public var title: String {
            switch self {
            case .available: "已可播"
            case .scheduled: "计划放送"
            case .unavailable: "不可用"
            }
        }
    }

    public let id: String
    public let bgmEpisodeId: Int
    public let subjectID: String
    public let number: Int
    public let sort: Double
    public let title: String
    public let synopsis: String
    public let durationSeconds: Double
    public let airDate: Date?
    public let availability: Availability

    public init(
        id: String,
        bgmEpisodeId: Int,
        subjectID: String,
        number: Int,
        sort: Double,
        title: String,
        synopsis: String,
        durationSeconds: Double,
        airDate: Date?,
        availability: Availability
    ) {
        self.id = id
        self.bgmEpisodeId = bgmEpisodeId
        self.subjectID = subjectID
        self.number = number
        self.sort = sort
        self.title = title
        self.synopsis = synopsis
        self.durationSeconds = durationSeconds
        self.airDate = airDate
        self.availability = availability
    }
}

public struct AiringEntry: Identifiable, Hashable, Sendable {
    public var id: String { "\(subject.id)-\(episode.id)" }

    public let subject: Subject
    public let episode: Episode
    public let airDate: Date
    public let availability: Episode.Availability

    public init(
        subject: Subject,
        episode: Episode,
        airDate: Date,
        availability: Episode.Availability
    ) {
        self.subject = subject
        self.episode = episode
        self.airDate = airDate
        self.availability = availability
    }
}

public struct ContinueWatchingItem: Identifiable, Hashable, Sendable {
    public var id: String { episode.id }

    public let subject: Subject
    public let episode: Episode
    public let positionSeconds: Double
    public let updatedAt: Date

    public init(
        subject: Subject,
        episode: Episode,
        positionSeconds: Double,
        updatedAt: Date
    ) {
        self.subject = subject
        self.episode = episode
        self.positionSeconds = positionSeconds
        self.updatedAt = updatedAt
    }

    public var fraction: Double {
        PlaybackProgressPolicy.fraction(
            position: positionSeconds,
            duration: episode.durationSeconds
        )
    }
}

public enum SourceProviderStatus: String, Codable, Sendable {
    case verified
    case needsVerification
    case disabled
    case unavailable

    public var title: String {
        switch self {
        case .verified: "已验证"
        case .needsVerification: "待验证"
        case .disabled: "已禁用"
        case .unavailable: "不可用"
        }
    }
}

/// A provider entry shown in source settings.
///
/// All current entries are self-made demo rows. `isDemoOnly` prevents the
/// prototype from claiming that a provider rule was actually executed.
public struct SourceProvider: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let qualityLabel: String
    public let status: SourceProviderStatus
    public let requiresRelay: Bool
    public let isDemoOnly: Bool
    public let compatibilityNote: String

    public init(
        id: String,
        name: String,
        detail: String,
        qualityLabel: String,
        status: SourceProviderStatus,
        requiresRelay: Bool,
        isDemoOnly: Bool,
        compatibilityNote: String
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.qualityLabel = qualityLabel
        self.status = status
        self.requiresRelay = requiresRelay
        self.isDemoOnly = isDemoOnly
        self.compatibilityNote = compatibilityNote
    }
}

public enum DemoSources {
    public static let all: [SourceProvider] = [
        SourceProvider(
            id: "demo-aster",
            name: "Aster",
            detail: "示例线路 · 1080p",
            qualityLabel: "1080p",
            status: .needsVerification,
            requiresRelay: true,
            isDemoOnly: true,
            compatibilityNote: "自造 UI 数据；未执行 online.json 规则，真实解析待 SRC-001。"
        ),
        SourceProvider(
            id: "demo-kite",
            name: "Kite",
            detail: "示例线路 · 720p",
            qualityLabel: "720p",
            status: .needsVerification,
            requiresRelay: true,
            isDemoOnly: true,
            compatibilityNote: "自造 UI 数据；仅用于验证换源与恢复交互。"
        ),
        SourceProvider(
            id: "demo-legacy",
            name: "Legacy Rule",
            detail: "未知工厂 v1",
            qualityLabel: "—",
            status: .disabled,
            requiresRelay: false,
            isDemoOnly: true,
            compatibilityNote: "不兼容的规则格式示例，默认禁用并保留原因。"
        )
    ]
}

public struct SubjectStatistics: Codable, Hashable, Sendable {
    public let rank: Int?
    public let ratingCount: Int?
    public let distribution: [String: Int]
    public let watching: Int?
    public let wish: Int?
    public let collected: Int?
    public init(rank: Int?, ratingCount: Int?, distribution: [String: Int], watching: Int?, wish: Int?, collected: Int?) {
        self.rank = rank; self.ratingCount = ratingCount; self.distribution = distribution
        self.watching = watching; self.wish = wish; self.collected = collected
    }
}
