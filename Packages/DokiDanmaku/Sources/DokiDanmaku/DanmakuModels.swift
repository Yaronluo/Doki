import Foundation

/// Danmaku modes supported by the first TV release. Upstream numeric values are
/// mapped explicitly; unknown values are retained as `nil` so the UI can skip
/// them without pretending they are a supported mode.
public enum DanmakuMode: String, Codable, CaseIterable, Hashable, Sendable {
    case scroll
    case top
    case bottom

    public init?(upstreamRawValue: Int) {
        switch upstreamRawValue {
        case 1: self = .scroll
        case 4: self = .bottom
        case 5: self = .top
        default: return nil
        }
    }

    public var upstreamRawValue: Int {
        switch self {
        case .scroll: 1
        case .bottom: 4
        case .top: 5
        }
    }

    public var title: String {
        switch self {
        case .scroll: "滚动"
        case .top: "顶部"
        case .bottom: "底部"
        }
    }
}

/// A normalized comment. IDs from the dandanplay API are int64 decimal strings;
/// they are never parsed through a JavaScript number or a Double.
public struct DanmakuItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let timeSeconds: Double
    public let mode: DanmakuMode?
    public let colorRGB: UInt32
    public let text: String
    public let userHash: String?

    public init?(
        id: String,
        timeSeconds: Double,
        mode: DanmakuMode?,
        colorRGB: UInt32,
        text: String,
        userHash: String? = nil
    ) {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty,
              trimmedID.allSatisfy(\.isNumber),
              trimmedID.count <= 20 else { return nil }
        guard timeSeconds.isFinite, timeSeconds >= 0, timeSeconds <= 7 * 24 * 3600 else {
            return nil
        }
        let normalizedText = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return nil }

        self.id = trimmedID
        self.timeSeconds = timeSeconds
        self.mode = mode
        self.colorRGB = min(colorRGB, 0xFF_FF_FF)
        self.text = String(normalizedText.prefix(180))
        self.userHash = userHash
    }

    public var displayable: Bool {
        mode != nil
    }

    /// Display time relative to the video clip. A positive offset makes the
    /// comment appear later.
    public func displayTime(offsetSeconds: Double) -> Double {
        timeSeconds + offsetSeconds
    }
}

public struct DanmakuPreferences: Codable, Hashable, Sendable {
    public enum Density: String, Codable, CaseIterable, Sendable {
        case light
        case normal
        case dense

        public var title: String {
            switch self {
            case .light: "轻"
            case .normal: "适中"
            case .dense: "密"
            }
        }

        public var samplingRate: Double {
            switch self {
            case .light: 0.45
            case .normal: 0.75
            case .dense: 1.0
            }
        }

        public var maximumOnScreen: Int {
            switch self {
            case .light: 18
            case .normal: 34
            case .dense: 60
            }
        }
    }

    public enum Area: String, Codable, CaseIterable, Sendable {
        case topThird
        case twoThirds
        case full

        public var title: String {
            switch self {
            case .topThird: "上部 1/3"
            case .twoThirds: "上部 2/3"
            case .full: "全部画面"
            }
        }

        public var normalizedHeight: Double {
            switch self {
            case .topThird: 0.34
            case .twoThirds: 0.62
            case .full: 0.82
            }
        }
    }

    public var enabled: Bool
    public var density: Density
    public var fontScale: Double
    public var opacity: Double
    public var area: Area
    public var offsetSeconds: Double
    public var showsScroll: Bool
    public var showsTop: Bool
    public var showsBottom: Bool

    public init(
        enabled: Bool = false,
        density: Density = .normal,
        fontScale: Double = 1.0,
        opacity: Double = 0.9,
        area: Area = .topThird,
        offsetSeconds: Double = 0,
        showsScroll: Bool = true,
        showsTop: Bool = true,
        showsBottom: Bool = true
    ) {
        self.enabled = enabled
        self.density = density
        self.fontScale = fontScale
        self.opacity = opacity
        self.area = area
        self.offsetSeconds = offsetSeconds
        self.showsScroll = showsScroll
        self.showsTop = showsTop
        self.showsBottom = showsBottom
    }

    /// Clamps values loaded from an old device preference. Invalid floats are
    /// replaced rather than allowed to destabilize layout.
    public func normalized() -> DanmakuPreferences {
        var copy = self
        copy.fontScale = fontScale.isFinite ? min(max(fontScale, 0.7), 1.6) : 1
        copy.opacity = opacity.isFinite ? min(max(opacity, 0.35), 1) : 0.9
        copy.offsetSeconds = offsetSeconds.isFinite
            ? min(max(offsetSeconds, -30), 30)
            : 0
        return copy
    }

    public func includes(_ mode: DanmakuMode) -> Bool {
        switch mode {
        case .scroll: showsScroll
        case .top: showsTop
        case .bottom: showsBottom
        }
    }
}
