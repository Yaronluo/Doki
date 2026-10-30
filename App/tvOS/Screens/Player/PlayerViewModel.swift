import AVFoundation
import Foundation
import Observation
import DokiCore
import DokiPlayback

@MainActor
@Observable
final class PlayerViewModel {
    let player = AVPlayer()

    private(set) var phase: PlaybackPhase = .idle
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlaying = false
    private(set) var failure: PlaybackFailure?
    private(set) var isLoadingMedia = false

    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var loadGeneration = UUID()
    @ObservationIgnored private var onCheckpoint: ((Double, Double) -> Void)?
    @ObservationIgnored private var lastCheckpoint: Double = -1_000
    @ObservationIgnored private var durationHint: Double = 0
    @ObservationIgnored private var hasEnded = false

    func load(
        url: URL,
        startAt: Double,
        durationHint: Double,
        onCheckpoint: @escaping (Double, Double) -> Void
    ) {
        stop()
        let generation = UUID()
        loadGeneration = generation
        self.onCheckpoint = onCheckpoint
        self.durationHint = durationHint
        self.duration = durationHint
        self.currentTime = max(0, startAt)
        self.lastCheckpoint = -1_000
        self.hasEnded = false
        self.failure = nil
        self.phase = .preparing
        self.isLoadingMedia = true

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 8
        player.replaceCurrentItem(with: item)
        player.automaticallyWaitsToMinimizeStalling = true
        startTicker()

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.prepare(item: item, startAt: startAt, generation: generation)
        }
    }

    func play() {
        guard player.currentItem != nil else { return }
        if hasEnded {
            Task { @MainActor in
                _ = await seek(to: 0)
                hasEnded = false
                phase = .playing
                player.play()
            }
            return
        }
        player.play()
    }

    func pause() {
        player.pause()
        phase = .paused
        isPlaying = false
        checkpointNow(force: true)
    }

    func replay() {
        Task { @MainActor in
            _ = await seek(to: 0)
            hasEnded = false
            phase = .playing
            player.play()
        }
    }

    @discardableResult
    func seek(to seconds: Double) async -> Bool {
        guard player.currentItem != nil else { return false }
        let target = PlaybackTiming.clampedSeek(seconds, duration: max(duration, durationHint))
        let wasPlaying = isPlaying
        phase = .seeking
        let finished = await withCheckedContinuation { continuation in
            player.seek(
                to: CMTime(seconds: target, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            ) { didFinish in
                continuation.resume(returning: didFinish)
            }
        }
        currentTime = target
        if finished {
            phase = wasPlaying ? .playing : .paused
            if wasPlaying { player.play() }
        } else {
            phase = .failed
            failure = PlaybackFailure(stage: .playback, message: "定位失败，请重试。", retryable: true)
        }
        return finished
    }

    func checkpointNow(force: Bool = false) {
        guard duration.isFinite, duration > 0, currentTime.isFinite else { return }
        if !force, currentTime - lastCheckpoint < PlaybackTiming.periodicCheckpointSeconds {
            return
        }
        lastCheckpoint = currentTime
        onCheckpoint?(currentTime, duration)
    }

    func stop() {
        checkpointNow(force: true)
        ticker?.cancel()
        ticker = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        phase = .cancelled
        isPlaying = false
        isLoadingMedia = false
    }

    private func prepare(item: AVPlayerItem, startAt: Double, generation: UUID) async {
        let deadline = Date().addingTimeInterval(PlaybackTiming.resolveBudgetSeconds)
        while item.status == .unknown, Date() < deadline {
            guard loadGeneration == generation else { return }
            try? await Task.sleep(for: .milliseconds(120))
        }
        guard loadGeneration == generation else { return }

        if item.status == .failed {
            fail(
                stage: .preparing,
                message: item.error?.localizedDescription ?? "无法准备这集样片。",
                retryable: true
            )
            return
        }

        if startAt > 0.5 {
            let didSeek = await seek(to: startAt)
            guard didSeek, loadGeneration == generation else { return }
        }

        isLoadingMedia = false
        phase = .playing
        player.play()
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { break }
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let item = player.currentItem else { return }

        let seconds = player.currentTime().seconds
        if seconds.isFinite {
            currentTime = max(0, seconds)
        }

        let itemDuration = item.duration.seconds
        if itemDuration.isFinite, itemDuration > 0 {
            duration = itemDuration
        }

        if item.status == .failed {
            fail(
                stage: .playback,
                message: item.error?.localizedDescription ?? "播放中断。",
                retryable: true
            )
            return
        }

        if phase != .seeking, phase != .ended, phase != .failed {
            switch player.timeControlStatus {
            case .playing:
                phase = .playing
                isPlaying = true
                isLoadingMedia = false
            case .waitingToPlayAtSpecifiedRate:
                if phase != .paused {
                    phase = .buffering
                }
                isPlaying = true
            case .paused:
                if currentTime > 0, duration > 0, currentTime >= duration - 0.35 {
                    finish()
                } else if phase != .preparing {
                    phase = .paused
                    isPlaying = false
                }
            @unknown default:
                break
            }
        }

        if !hasEnded, duration > 1, currentTime > 0, currentTime >= duration - 0.35,
           player.timeControlStatus != .playing {
            finish()
        }

        if currentTime - lastCheckpoint >= PlaybackTiming.periodicCheckpointSeconds {
            checkpointNow()
        }
    }

    private func finish() {
        guard !hasEnded else { return }
        hasEnded = true
        phase = .ended
        isPlaying = false
        currentTime = max(duration, currentTime)
        checkpointNow(force: true)
    }

    private func fail(stage: PlaybackFailureStage, message: String, retryable: Bool) {
        failure = PlaybackFailure(stage: stage, message: message, retryable: retryable)
        phase = .failed
        isLoadingMedia = false
        isPlaying = false
    }
}
