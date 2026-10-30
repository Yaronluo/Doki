import SwiftUI

/// Independent linear tracks, sampled so reversing starts at the visible value.
/// Timing follows izuko's blurred-background hero mode; no darkening track is needed.
@MainActor @Observable
final class ShelfHeroTimeline {
    private(set) var above = 0.0
    private(set) var content = 0.0
    private(set) var text = 0.0
    private(set) var active = false
    @ObservationIgnored private var task: Task<Void, Never>?

    func setActive(_ active: Bool, reduceMotion: Bool) {
        task?.cancel()
        self.active = active
        if reduceMotion {
            above = active ? 1 : 0; content = above; text = above
            return
        }
        let initialAbove = above, initialContent = content, initialText = text
        task = Task { [weak self] in
            let clock = ContinuousClock()
            let start = clock.now
            // Entry: above/tone 150 ms, content 400 ms, text delayed 100 ms / 300 ms.
            // Exit: text 150 ms + content 250 ms, then above 250 ms.
            let lead = active ? 0.15 * (1 - initialAbove) : 0.25 * initialContent
            let textDelay = active ? lead + (initialContent > 0 ? 0 : 0.1) : 0
            while let self, !Task.isCancelled {
                let elapsed = start.duration(to: clock.now)
                let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                func track(_ from: Double, to: Double, duration: Double, delay: Double = 0) -> Double {
                    let span = duration * abs(to - from)
                    guard seconds >= delay else { return from }
                    return span == 0 ? to : from + (to - from) * min(1, (seconds - delay) / span)
                }
                self.above = track(initialAbove, to: active ? 1 : 0, duration: active ? 0.15 : 0.25, delay: active ? 0 : lead)
                self.content = track(initialContent, to: active ? 1 : 0, duration: active ? 0.4 : 0.25, delay: active ? lead : 0)
                self.text = track(initialText, to: active ? 1 : 0, duration: active ? 0.3 : 0.15, delay: textDelay)
                let target = active ? 1.0 : 0.0
                if self.above == target && self.content == target && self.text == target { return }
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            }
        }
    }
}
