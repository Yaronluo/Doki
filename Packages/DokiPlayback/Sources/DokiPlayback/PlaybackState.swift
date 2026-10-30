import Foundation
import DokiCore

public enum PlaybackPhase: String, Codable, Hashable, Sendable {
    case idle
    case preparing
    case playing
    case paused
    case seeking
    case buffering
    case ended
    case failed
    case cancelled

    public var isActive: Bool {
        switch self {
        case .preparing, .playing, .paused, .seeking, .buffering: true
        default: false
        }
    }
}

public enum PlaybackFailureStage: String, Codable, Hashable, Sendable {
    case resolving
    case preparing
    case firstFrame
    case playback
    case expiredAsset

    public var title: String {
        switch self {
        case .resolving: "寻找片源"
        case .preparing: "准备播放"
        case .firstFrame: "等待首帧"
        case .playback: "播放中"
        case .expiredAsset: "地址过期"
        }
    }
}

public struct PlaybackFailure: Error, Codable, Hashable, Sendable, LocalizedError {
    public let stage: PlaybackFailureStage
    public let message: String
    public let retryable: Bool

    public init(stage: PlaybackFailureStage, message: String, retryable: Bool) {
        self.stage = stage
        self.message = message
        self.retryable = retryable
    }

    public var errorDescription: String? { message }
}

public struct PlaybackRequest: Identifiable, Hashable, Sendable {
    public var id: String { episodeID }
    public let subjectID: String
    public let episodeID: String
    public let episodeNumber: Int
    public let subjectTitle: String
    public let episodeTitle: String
    public let sourceID: String
    public let startAtSeconds: Double
    public let durationSeconds: Double
    public let mediaURL: URL

    public init(
        subjectID: String,
        episodeID: String,
        episodeNumber: Int,
        subjectTitle: String,
        episodeTitle: String,
        sourceID: String,
        startAtSeconds: Double,
        durationSeconds: Double,
        mediaURL: URL
    ) {
        self.subjectID = subjectID
        self.episodeID = episodeID
        self.episodeNumber = episodeNumber
        self.subjectTitle = subjectTitle
        self.episodeTitle = episodeTitle
        self.sourceID = sourceID
        self.startAtSeconds = startAtSeconds
        self.durationSeconds = durationSeconds
        self.mediaURL = mediaURL
    }
}

/// Small, testable state machine. The AVKit adapter still owns the actual
/// AVPlayer; this type only rejects stale/invalid UI transitions.
public struct PlaybackStateMachine: Sendable {
    public private(set) var phase: PlaybackPhase = .idle
    public private(set) var lastFailure: PlaybackFailure?

    public init() {}

    public mutating func begin() {
        phase = .preparing
        lastFailure = nil
    }

    @discardableResult
    public mutating func transition(to next: PlaybackPhase) -> Bool {
        guard Self.allowed(from: phase, to: next) else { return false }
        phase = next
        if next != .failed { lastFailure = nil }
        return true
    }

    public mutating func fail(_ failure: PlaybackFailure) {
        phase = .failed
        lastFailure = failure
    }

    public mutating func reset() {
        phase = .idle
        lastFailure = nil
    }

    public static func allowed(from current: PlaybackPhase, to next: PlaybackPhase) -> Bool {
        if current == next { return true }
        switch current {
        case .idle:
            return [.preparing, .cancelled].contains(next)
        case .preparing:
            return [.playing, .buffering, .failed, .cancelled].contains(next)
        case .playing:
            return [.paused, .seeking, .buffering, .ended, .failed, .cancelled].contains(next)
        case .paused:
            return [.playing, .seeking, .ended, .failed, .cancelled].contains(next)
        case .seeking:
            return [.playing, .paused, .buffering, .failed, .cancelled].contains(next)
        case .buffering:
            return [.playing, .paused, .failed, .cancelled].contains(next)
        case .ended:
            return [.preparing, .cancelled].contains(next)
        case .failed:
            return [.preparing, .cancelled].contains(next)
        case .cancelled:
            return [.preparing].contains(next)
        }
    }
}

public enum PlaybackTiming {
    /// Initial interaction budget before the UI must offer a recovery action.
    public static let resolveBudgetSeconds: TimeInterval = 15
    /// First-frame observation budget after a playable URL is known.
    public static let firstFrameBudgetSeconds: TimeInterval = 8
    /// Progress writes while playing; a checkpoint is still written on exit.
    public static let periodicCheckpointSeconds: TimeInterval = 5

    public static func clampedSeek(
        _ requested: Double,
        duration: Double
    ) -> Double {
        guard requested.isFinite, duration.isFinite, duration > 0 else { return 0 }
        let margin = min(0.5, duration * 0.01)
        return min(max(requested, 0), max(0, duration - margin))
    }
}
