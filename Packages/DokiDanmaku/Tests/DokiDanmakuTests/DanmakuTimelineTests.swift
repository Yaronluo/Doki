import Foundation
import Testing
@testable import DokiDanmaku

@Suite("Danmaku timeline")
struct DanmakuTimelineTests {
    private func item(
        id: String = "1",
        time: Double = 10,
        mode: DanmakuMode? = .scroll,
        text: String = "测试"
    ) -> DanmakuItem {
        DanmakuItem(
            id: id,
            timeSeconds: time,
            mode: mode,
            colorRGB: 0xFF_FF_FF,
            text: text
        )!
    }

    @Test("int64 IDs remain decimal strings, including values beyond exact Double range")
    func largeIdentifier() {
        let value = "9223372036854775806"
        let comment = item(id: value)
        #expect(comment.id == value)
        #expect(comment.id.count == 19)

        let encoded = try! JSONEncoder().encode(comment)
        let text = String(data: encoded, encoding: .utf8)!
        #expect(text.contains(value))

        #expect(DanmakuItem(
            id: "12.5",
            timeSeconds: 1,
            mode: .scroll,
            colorRGB: 0,
            text: "x"
        ) == nil)
        #expect(DanmakuItem(
            id: "+12",
            timeSeconds: 1,
            mode: .scroll,
            colorRGB: 0,
            text: "x"
        ) == nil)
    }

    @Test("Unknown upstream modes are skipped but not misclassified")
    func unknownMode() {
        #expect(DanmakuMode(upstreamRawValue: 1) == .scroll)
        #expect(DanmakuMode(upstreamRawValue: 4) == .bottom)
        #expect(DanmakuMode(upstreamRawValue: 5) == .top)
        #expect(DanmakuMode(upstreamRawValue: 7) == nil)

        let unknown = item(id: "2", mode: nil)
        #expect(!unknown.displayable)
        let timeline = DanmakuTimeline(items: [item(id: "1"), unknown])
        #expect(timeline.displayableItems.map(\.id) == ["1"])
    }

    @Test("Durations, NaN, empty text and unsupported lengths are rejected")
    func validation() {
        #expect(DanmakuItem(id: "1", timeSeconds: -.infinity, mode: .scroll, colorRGB: 0, text: "x") == nil)
        #expect(DanmakuItem(id: "1", timeSeconds: .nan, mode: .scroll, colorRGB: 0, text: "x") == nil)
        #expect(DanmakuItem(id: "", timeSeconds: 1, mode: .scroll, colorRGB: 0, text: "x") == nil)
        #expect(DanmakuItem(id: "1", timeSeconds: 1, mode: .scroll, colorRGB: 0, text: "   ") == nil)
        let long = String(repeating: "长", count: 220)
        #expect(DanmakuItem(id: "1", timeSeconds: 1, mode: .scroll, colorRGB: 0, text: long)?.text.count == 180)
    }

    @Test("Duplicate cids keep the first item and sorting is deterministic")
    func deduplication() {
        let timeline = DanmakuTimeline(items: [
            item(id: "3", time: 30),
            item(id: "1", time: 10),
            item(id: "1", time: 99, text: "重复"),
            item(id: "2", time: 20)
        ])
        #expect(timeline.items.map(\.id) == ["1", "2", "3"])
        #expect(timeline.items[0].timeSeconds == 10)
    }

    @Test("Positive offset delays comments, including window lookup")
    func offsetSemantics() {
        let timeline = DanmakuTimeline(items: [
            item(id: "1", time: 10),
            item(id: "2", time: 20)
        ])
        let atTen = timeline.window(from: 10, to: 10.1, offsetSeconds: 0)
        #expect(atTen.map(\.id) == ["1"])

        let delayed = timeline.window(from: 10, to: 10.1, offsetSeconds: 5)
        #expect(delayed.isEmpty)
        let atFifteen = timeline.window(from: 15, to: 15.1, offsetSeconds: 5)
        #expect(atFifteen.map(\.id) == ["1"])
    }

    @Test("Seek window does not replay comments from before the new time")
    func seekWindow() {
        let timeline = DanmakuTimeline(items: [
            item(id: "1", time: 10),
            item(id: "2", time: 11),
            item(id: "3", time: 30)
        ])
        let seeked = timeline.rewindWindow(at: 29.9, lookAhead: 0.2, offsetSeconds: 0)
        #expect(seeked.map(\.id) == ["3"])
    }

    @Test("Preferences clamp invalid values and mode switches")
    func preferences() {
        var preferences = DanmakuPreferences(enabled: true, fontScale: 9, opacity: -1, offsetSeconds: .nan)
        preferences = preferences.normalized()
        #expect(preferences.fontScale == 1.6)
        #expect(preferences.opacity == 0.35)
        #expect(preferences.offsetSeconds == 0)
        preferences.showsTop = false
        #expect(!preferences.includes(.top))
        #expect(preferences.includes(.scroll))
    }

    @Test("Density sampling is deterministic and bounded")
    func sampling() {
        let comments = (0..<500).map { item(id: String($0), time: Double($0)) }
        let first = comments.filter { DanmakuSampling.keeps($0, rate: 0.45) }
        let second = comments.filter { DanmakuSampling.keeps($0, rate: 0.45) }
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first.count > 100 && first.count < 300)
        #expect(comments.allSatisfy { DanmakuSampling.keeps($0, rate: 1.0) })
        #expect(comments.allSatisfy { !DanmakuSampling.keeps($0, rate: 0) })
    }

    @Test("Fixture covers large ID, unknown mode and dense burst")
    func fixtureCoverage() {
        let timeline = DanmakuFixture.demoTimeline
        #expect(timeline.items.contains { $0.id == "9223372036854775811" })
        #expect(timeline.items.contains { !$0.displayable })
        #expect(timeline.count(in: 60...65) >= 20)
        #expect(timeline.displayableItems.count > 50)
        #expect(timeline.contentRevision == "fixture-danmaku-v1")
    }
}
