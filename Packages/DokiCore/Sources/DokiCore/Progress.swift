import Foundation

public enum PlaybackProgressPolicy {
    public static func clampedPosition(_ position: Double, duration: Double) -> Double {
        guard position.isFinite, duration.isFinite, duration > 0 else { return 0 }
        return min(max(position, 0), duration)
    }

    public static func fraction(position: Double, duration: Double) -> Double {
        guard duration.isFinite, duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    /// A sample counts as finished at the same initial threshold used by the
    /// player shell. A seek to the end alone is not enough; this policy only
    /// consumes positions recorded by the player.
    public static func isFinished(position: Double, duration: Double) -> Bool {
        guard duration.isFinite, duration > 0 else { return false }
        return fraction(position: position, duration: duration) >= 0.9
    }

    /// Opening an almost-finished episode starts from the beginning. Otherwise
    /// a deliberate rewind is preserved even when it is smaller than an earlier
    /// position.
    public static func resumePosition(position: Double, duration: Double) -> Double {
        guard position.isFinite, duration.isFinite, duration > 0 else { return 0 }
        if isFinished(position: position, duration: duration) { return 0 }
        return clampedPosition(position, duration: duration)
    }

    public static func displayTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

public struct PlaybackPosition: Codable, Hashable, Sendable {
    public let subjectID: String
    public let episodeID: String
    public let positionSeconds: Double
    public let durationSeconds: Double
    public let updatedAt: Date
    public let sourceID: String?

    public init(
        subjectID: String,
        episodeID: String,
        positionSeconds: Double,
        durationSeconds: Double,
        updatedAt: Date = .now,
        sourceID: String? = nil
    ) {
        self.subjectID = subjectID
        self.episodeID = episodeID
        self.positionSeconds = PlaybackProgressPolicy.clampedPosition(
            positionSeconds,
            duration: durationSeconds
        )
        self.durationSeconds = durationSeconds
        self.updatedAt = updatedAt
        self.sourceID = sourceID
    }

    public var fraction: Double {
        PlaybackProgressPolicy.fraction(
            position: positionSeconds,
            duration: durationSeconds
        )
    }

    public var isFinished: Bool {
        PlaybackProgressPolicy.isFinished(
            position: positionSeconds,
            duration: durationSeconds
        )
    }
}

/// A tiny, deterministic local journal. It is intentionally not the Hub sync
/// model: this book has no epoch or event sequence and is only persisted by the
/// TV demo shell.
public struct ProgressBook: Codable, Hashable, Sendable {
    public private(set) var positions: [String: PlaybackPosition]

    public init(positions: [String: PlaybackPosition] = [:]) {
        self.positions = positions
    }

    public init(_ entries: [PlaybackPosition]) {
        self.positions = Dictionary(uniqueKeysWithValues: entries.map { ($0.episodeID, $0) })
    }

    public func position(for episodeID: String) -> PlaybackPosition? {
        positions[episodeID]
    }

    public func latestPosition(forSubject subjectID: String) -> PlaybackPosition? {
        positions.values
            .filter { $0.subjectID == subjectID }
            .max { $0.updatedAt < $1.updatedAt }
    }

    public mutating func record(
        subjectID: String,
        episodeID: String,
        positionSeconds: Double,
        durationSeconds: Double,
        sourceID: String? = nil,
        at date: Date = .now
    ) {
        guard durationSeconds.isFinite, durationSeconds > 0 else { return }
        let entry = PlaybackPosition(
            subjectID: subjectID,
            episodeID: episodeID,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            updatedAt: date,
            sourceID: sourceID
        )
        positions[episodeID] = entry
    }

    public mutating func clear(episodeID: String) {
        positions.removeValue(forKey: episodeID)
    }

    public var recent: [PlaybackPosition] {
        positions.values.sorted { $0.updatedAt > $1.updatedAt }
    }
}
