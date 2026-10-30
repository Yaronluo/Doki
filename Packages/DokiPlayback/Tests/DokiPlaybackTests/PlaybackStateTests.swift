import Testing
@testable import DokiPlayback

@Suite("Playback state")
struct PlaybackStateTests {
    @Test("A normal session reaches playing and ends")
    func normalFlow() {
        var state = PlaybackStateMachine()
        state.begin()
        #expect(state.phase == .preparing)
        let playing = state.transition(to: .playing)
        let paused = state.transition(to: .paused)
        let seeking = state.transition(to: .seeking)
        let resumed = state.transition(to: .playing)
        let ended = state.transition(to: .ended)
        #expect(playing)
        #expect(paused)
        #expect(seeking)
        #expect(resumed)
        #expect(ended)
        #expect(state.phase == .ended)
    }

    @Test("Stale idle callbacks cannot move a session")
    func staleTransitions() {
        var state = PlaybackStateMachine()
        let idlePlay = state.transition(to: .playing)
        #expect(!idlePlay)
        state.begin()
        let cancelled = state.transition(to: .cancelled)
        #expect(cancelled)
        let stalePlay = state.transition(to: .playing)
        #expect(!stalePlay)
        let restarted = state.transition(to: .preparing)
        #expect(restarted)
        #expect(state.phase == .preparing)
    }

    @Test("Failure keeps the stage and recovery begins a new preparation")
    func failureRecovery() {
        var state = PlaybackStateMachine()
        state.begin()
        state.fail(PlaybackFailure(stage: .firstFrame, message: "首帧超时", retryable: true))
        #expect(state.phase == .failed)
        #expect(state.lastFailure?.stage == .firstFrame)
        let recovered = state.transition(to: .preparing)
        #expect(recovered)
        #expect(state.lastFailure == nil)
        #expect(state.phase == .preparing)
    }

    @Test("Seek stays inside a finite duration")
    func seekClamp() {
        #expect(PlaybackTiming.clampedSeek(-5, duration: 100) == 0)
        #expect(PlaybackTiming.clampedSeek(50, duration: 100) == 50)
        #expect(PlaybackTiming.clampedSeek(200, duration: 100) == 99.5)
        #expect(PlaybackTiming.clampedSeek(.nan, duration: 100) == 0)
        #expect(PlaybackTiming.clampedSeek(50, duration: .infinity) == 0)
    }
}
