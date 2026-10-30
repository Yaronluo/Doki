import Foundation

/// Immutable, sorted index over one episode's comments.
///
/// The timeline does not own a timer. A platform host asks it for a bounded
/// window around the current AVPlayer media time, so a seek or a pause never
/// replays wall-clock backlog.
public struct DanmakuTimeline: Sendable {
    public let items: [DanmakuItem]
    public let contentRevision: String

    public init(items: [DanmakuItem], contentRevision: String = "fixture") {
        var seen: Set<String> = []
        let unique = items
            .filter { seen.insert($0.id).inserted }
            .sorted {
                if $0.timeSeconds == $1.timeSeconds { return $0.id < $1.id }
                return $0.timeSeconds < $1.timeSeconds
            }
        self.items = unique
        self.contentRevision = contentRevision
    }

    public var displayableItems: [DanmakuItem] {
        items.filter(\.displayable)
    }

    /// Returns items whose display time starts in the inclusive media window.
    /// `offsetSeconds` follows the product contract: positive means later.
    public func window(
        from mediaTime: Double,
        to endMediaTime: Double,
        offsetSeconds: Double
    ) -> ArraySlice<DanmakuItem> {
        guard mediaTime.isFinite, endMediaTime.isFinite, endMediaTime >= mediaTime else {
            return items[0..<0]
        }
        let lower = mediaTime - offsetSeconds
        let upper = endMediaTime - offsetSeconds
        let start = lowerBound(for: lower)
        var end = start
        while end < items.count, items[end].timeSeconds <= upper {
            end += 1
        }
        return items[start..<end]
    }

    /// Re-locates after a seek. It intentionally returns only comments starting
    /// at or after the new media time; comments that began before the seek are
    /// not replayed en masse.
    public func rewindWindow(
        at mediaTime: Double,
        lookAhead: Double = 0.3,
        offsetSeconds: Double
    ) -> ArraySlice<DanmakuItem> {
        window(
            from: mediaTime,
            to: mediaTime + max(0, lookAhead),
            offsetSeconds: offsetSeconds
        )
    }

    public func count(in range: ClosedRange<Double>) -> Int {
        let lower = lowerBound(for: range.lowerBound)
        var upper = lower
        while upper < items.count, items[upper].timeSeconds <= range.upperBound {
            upper += 1
        }
        return upper - lower
    }

    private func lowerBound(for time: Double) -> Int {
        var low = 0
        var high = items.count
        while low < high {
            let middle = (low + high) / 2
            if items[middle].timeSeconds < time {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }
}

public enum DanmakuSampling {
    /// Stable deterministic sampling for a dense stream. It never depends on
    /// wall time, so seeking to the same media time yields the same density.
    public static func keeps(_ item: DanmakuItem, rate: Double) -> Bool {
        guard rate > 0 else { return false }
        if rate >= 1 { return true }
        let hash = item.id.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return Double(hash % 10_000) / 10_000.0 < rate
    }
}

public enum DanmakuFixture {
    /// Entirely invented comments used only for local UI and timing tests.
    public static func demoItems() -> [DanmakuItem] {
        var items: [DanmakuItem] = []

        let opening = [
            (5.0, "开场的光真好看"),
            (8.5, "这里是自造弹幕，用来验证媒体时钟"),
            (12.0, "滚动弹幕会从右向左移动"),
            (16.0, "暂停时应该一起冻结"),
            (22.0, "顶部弹幕停留几秒"),
            (26.0, "底部弹幕不要挡住字幕"),
            (31.0, "第一次 seek 后不应该补跑"),
            (38.0, "海报与正文保持清晰，弹幕不抢焦点")
        ]
        for (index, item) in opening.enumerated() {
            let mode: DanmakuMode = index == 4 ? .top : (index == 5 ? .bottom : .scroll)
            if let comment = DanmakuItem(
                id: "922337203685477580\(index)",
                timeSeconds: item.0,
                mode: mode,
                colorRGB: index == 5 ? 0xFF_D6_6B : 0xFF_FF_FF,
                text: item.1
            ) {
                items.append(comment)
            }
        }

        // A deliberately dense burst exercises sampling and finite lanes.
        for index in 0..<28 {
            let color: UInt32 = index % 3 == 0 ? 0x8C_E9_FF : 0xFF_FF_FF
            if let comment = DanmakuItem(
                id: String(9_000_000_000_000_000_000 + Int64(index)),
                timeSeconds: 60.0 + Double(index) * 0.18,
                mode: .scroll,
                colorRGB: color,
                text: "密集弹幕 \(index + 1) · 自造测试"
            ) {
                items.append(comment)
            }
        }

        // Colored, top and bottom comments across the sample clip.
        let middle: [(Double, DanmakuMode, UInt32, String)] = [
            (120.0, .top, 0xFF_E0_8A, "顶部弹幕有独立轨道"),
            (180.0, .bottom, 0x9F_E8_FF, "底部弹幕保留字幕区域"),
            (240.0, .scroll, 0xFF_AA_C8, "颜色不应该影响可读性"),
            (300.0, .scroll, 0xFF_FF_FF, "切换倍速后按照媒体时间继续"),
            (313.0, .scroll, 0x8C_E9_FF, "媒体时钟：从本地检查点续播"),
            (316.0, .top, 0xFF_E0_8A, "暂停后弹幕一起冻结"),
            (319.0, .bottom, 0x9F_E8_FF, "底部固定弹幕保留字幕区"),
            (323.0, .scroll, 0xFF_AA_C8, "这是自造弹幕 fixture，不是弹弹play数据"),
            (327.0, .scroll, 0xFF_FF_FF, "seek 后只显示新的时间窗口"),
            (360.0, .top, 0xFF_FF_FF, "这条弹幕使用一个很大的 int64 ID"),
            (420.0, .scroll, 0xB8_FF_CC, "未知模式会被跳过，而不是按滚动显示"),
            (480.0, .bottom, 0xFF_FF_FF, "这里是一条比较长的自造弹幕，用来检查窄边距、换行与最大宽度处理，不会输出到日志"),
            (540.0, .scroll, 0xFF_FF_FF, "seek 回到前面时，只显示新的窗口"),
            (600.0, .top, 0xFF_D9_8A, "顶部 • 演示"),
            (660.0, .bottom, 0x9F_E8_FF, "底部 • 演示"),
            (720.0, .scroll, 0xFF_FF_FF, "继续观看位置应保存到本地检查点"),
            (780.0, .scroll, 0xFF_8A_8A, "这条弹幕故意设置为超长文本：" + String(repeating: "风从海面吹来，信件沿着轨道飞向群星。", count: 6)),
            (840.0, .scroll, 0xFF_FF_FF, "没有弹幕服务时，视频仍然正常播放"),
            (900.0, .top, 0xFF_FF_FF, "弹幕不是字幕"),
            (960.0, .scroll, 0x9F_E8_FF, "画面尺寸变化时重新排轨"),
            (1_020.0, .bottom, 0xFF_D9_8A, "底部固定弹幕 • 自造"),
            (1_080.0, .scroll, 0xFF_FF_FF, "第 18 分钟附近的测试弹幕"),
            (1_140.0, .top, 0xFF_AA_C8, "切换分集后清空旧轨道"),
            (1_200.0, .scroll, 0xFF_FF_FF, "退出播放器时保存检查点"),
            (1_260.0, .scroll, 0xFF_FF_FF, "重新打开后从检查点续播"),
            (1_320.0, .bottom, 0x9F_E8_FF, "结尾附近仍然可以正常 seek"),
            (1_380.0, .scroll, 0xFF_FF_FF, "片尾 · 自造弹幕")
        ]
        for (index, entry) in middle.enumerated() {
            if let comment = DanmakuItem(
                id: String(8_000_000_000_000_000_000 + Int64(index)),
                timeSeconds: entry.0,
                mode: entry.1,
                colorRGB: entry.2,
                text: entry.3
            ) {
                items.append(comment)
            }
        }

        // Explicit unsupported mode and a duplicate cid: both must be handled
        // deterministically by the timeline.
        if let unknown = DanmakuItem(
            id: "9223372036854775811",
            timeSeconds: 450,
            mode: nil,
            colorRGB: 0xFF_FF_FF,
            text: "这条弹幕来自未知模式，不应显示"
        ) {
            items.append(unknown)
        }
        if let duplicate = DanmakuItem(
            id: "9223372036854775800",
            timeSeconds: 38,
            mode: .scroll,
            colorRGB: 0xFF_FF_FF,
            text: "重复 cid 只保留第一条"
        ) {
            items.append(duplicate)
        }

        return items
    }

    public static var demoTimeline: DanmakuTimeline {
        DanmakuTimeline(items: demoItems(), contentRevision: "fixture-danmaku-v1")
    }
}
