import QuartzCore
import SwiftUI
import UIKit
import DokiDanmaku

struct DanmakuOverlayRepresentable: UIViewRepresentable {
    let timeline: DanmakuTimeline
    let preferences: DanmakuPreferences
    let mediaTime: @MainActor () -> Double

    func makeUIView(context: Context) -> DanmakuOverlayView {
        let view = DanmakuOverlayView()
        view.configure(timeline: timeline, preferences: preferences, mediaTime: mediaTime)
        return view
    }

    func updateUIView(_ uiView: DanmakuOverlayView, context: Context) {
        uiView.configure(timeline: timeline, preferences: preferences, mediaTime: mediaTime)
    }
}

/// CALayer/UILabel based danmaku host. A display link reads the AVPlayer media
/// clock, schedules comments in a bounded window and never replays wall-clock
/// backlog after pause or seek.
final class DanmakuOverlayView: UIView {
    private final class ActiveComment {
        let label: UILabel
        let mode: DanmakuMode
        let startTime: Double
        let startX: CGFloat
        let width: CGFloat
        let speed: CGFloat

        init(
            label: UILabel,
            mode: DanmakuMode,
            startTime: Double,
            startX: CGFloat,
            width: CGFloat,
            speed: CGFloat
        ) {
            self.label = label
            self.mode = mode
            self.startTime = startTime
            self.startX = startX
            self.width = width
            self.speed = speed
        }
    }

    private struct ScrollLane {
        var startTime: Double
        var startX: CGFloat
        var width: CGFloat
    }

    private var displayLink: CADisplayLink?
    private var timeline: DanmakuTimeline?
    private var preferences: DanmakuPreferences?
    private var mediaTimeProvider: (() -> Double)?
    private var active: [String: ActiveComment] = [:]
    private var scrollLanes: [ScrollLane?] = []
    private var fixedTopFreeAt: [Double] = []
    private var fixedBottomFreeAt: [Double] = []
    private var lastTick: Double = .nan
    private var lastBounds: CGSize = .zero
    private var configurationSignature = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        clipsToBounds = true
        isAccessibilityElement = false
        accessibilityElementsHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func configure(
        timeline: DanmakuTimeline,
        preferences: DanmakuPreferences,
        mediaTime: @escaping @MainActor () -> Double
    ) {
        let normalized = preferences.normalized()
        let signature = [
            timeline.contentRevision,
            String(timeline.items.count),
            String(normalized.enabled),
            normalized.density.rawValue,
            String(normalized.fontScale),
            String(normalized.opacity),
            normalized.area.rawValue,
            String(normalized.offsetSeconds),
            String(normalized.showsScroll),
            String(normalized.showsTop),
            String(normalized.showsBottom)
        ].joined(separator: "|")

        mediaTimeProvider = mediaTime
        self.timeline = timeline
        self.preferences = normalized

        if signature != configurationSignature {
            configurationSignature = signature
            clearActive()
            lastTick = currentMediaTime() - 0.08
        }

        if normalized.enabled, window != nil {
            startDisplayLink()
        } else if !normalized.enabled {
            stopDisplayLink()
            clearActive()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, preferences?.enabled == true {
            startDisplayLink()
            lastTick = currentMediaTime() - 0.08
        } else {
            stopDisplayLink()
            clearActive()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastBounds {
            lastBounds = bounds.size
            clearActive()
            lastTick = currentMediaTime() - 0.08
        }
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 60, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        render()
    }

    private func currentMediaTime() -> Double {
        let value = mediaTimeProvider?() ?? 0
        return value.isFinite ? max(0, value) : 0
    }

    private func render() {
        guard let timeline, let preferences, preferences.enabled else {
            clearActive()
            return
        }

        let now = currentMediaTime()
        if lastTick.isNaN {
            lastTick = now - 0.08
        }

        let delta = now - lastTick
        if delta < -0.25 || delta > 1.2 {
            clearActive()
            lastTick = now - 0.05
        }

        let lower = max(lastTick, now - 0.18)
        let upper = now + 0.05
        if upper >= lower {
            let window = timeline.window(
                from: lower,
                to: upper,
                offsetSeconds: preferences.offsetSeconds
            )
            for item in window where item.displayable {
                guard active[item.id] == nil else { continue }
                guard preferences.includes(item.mode ?? .scroll) else { continue }
                guard DanmakuSampling.keeps(item, rate: preferences.density.samplingRate) else { continue }
                guard active.count < preferences.density.maximumOnScreen else { break }
                let displayTime = item.timeSeconds + preferences.offsetSeconds
                guard displayTime <= now + 0.02 else { continue }
                schedule(item, displayTime: displayTime, now: now)
            }
        }

        lastTick = now
        updateActive(now: now)
    }

    private func schedule(_ item: DanmakuItem, displayTime: Double, now: Double) {
        guard let preferences, let mode = item.mode else { return }

        let fontSize = 28 * preferences.fontScale
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attributed = NSAttributedString(
            string: item.text,
            attributes: [
                .font: font,
                .foregroundColor: readableColor(item.colorRGB),
                .shadow: textShadow
            ]
        )
        let measured = attributed.size()
        let labelWidth = min(bounds.width * 0.86, ceil(measured.width) + 6)
        let lineHeight = ceil(font.lineHeight + 10)

        let topInset: CGFloat = 132
        let bottomInset: CGFloat = 126
        let topFixedLaneCount = preferences.showsTop ? 2 : 0
        let bottomFixedLaneCount = preferences.showsBottom ? 2 : 0
        let scrollTop = topInset + CGFloat(topFixedLaneCount) * lineHeight + 8
        let scrollBottom = bounds.height - bottomInset - CGFloat(bottomFixedLaneCount) * lineHeight - 8
        let usableHeight = max(lineHeight, (scrollBottom - scrollTop) * CGFloat(preferences.area.normalizedHeight))
        let laneCount = max(1, Int(usableHeight / lineHeight))

        let y: CGFloat
        let speed: CGFloat
        let startX: CGFloat
        var isScroll = false

        switch mode {
        case .scroll:
            speed = max(180, (bounds.width + 320) / 8.0)
            startX = bounds.width + 12
            guard let lane = availableScrollLane(
                laneCount: laneCount,
                now: now,
                speed: speed,
                width: labelWidth
            ) else { return }
            y = scrollTop + CGFloat(lane) * lineHeight
            isScroll = true
            if scrollLanes.indices.contains(lane) {
                scrollLanes[lane] = ScrollLane(startTime: displayTime, startX: startX, width: labelWidth)
            }
        case .top:
            guard let lane = availableFixedLane(&fixedTopFreeAt, count: 2, now: now) else { return }
            y = topInset + CGFloat(lane) * lineHeight
            speed = 0
            startX = (bounds.width - labelWidth) / 2
        case .bottom:
            guard let lane = availableFixedLane(&fixedBottomFreeAt, count: 2, now: now) else { return }
            y = bounds.height - bottomInset - CGFloat(lane + 1) * lineHeight + 3
            speed = 0
            startX = (bounds.width - labelWidth) / 2
        }

        let label = UILabel()
        label.attributedText = attributed
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        label.frame = CGRect(x: startX, y: y, width: labelWidth, height: lineHeight)
        label.alpha = preferences.opacity
        label.backgroundColor = .clear
        label.layer.shouldRasterize = true
        label.layer.rasterizationScale = UIScreen.main.scale
        label.isAccessibilityElement = false
        addSubview(label)

        active[item.id] = ActiveComment(
            label: label,
            mode: mode,
            startTime: displayTime,
            startX: startX,
            width: labelWidth,
            speed: isScroll ? speed : 0
        )
    }

    private func availableScrollLane(
        laneCount: Int,
        now: Double,
        speed: CGFloat,
        width: CGFloat
    ) -> Int? {
        if scrollLanes.count != laneCount {
            scrollLanes = Array(repeating: nil, count: laneCount)
        }
        let gap: CGFloat = 34
        for lane in 0..<laneCount {
            guard let state = scrollLanes[lane] else { return lane }
            let elapsed = max(0, now - state.startTime)
            let tail = state.startX - speed * CGFloat(elapsed) + state.width
            if tail < bounds.width - gap {
                return lane
            }
        }
        return nil
    }

    private func availableFixedLane(_ lanes: inout [Double], count: Int, now: Double) -> Int? {
        if lanes.count != count {
            lanes = Array(repeating: 0, count: count)
        }
        for lane in 0..<count where lanes[lane] <= now {
            lanes[lane] = now + 4.4
            return lane
        }
        return nil
    }

    private func updateActive(now: Double) {
        var removals: [String] = []
        for (id, comment) in active {
            let elapsed = max(0, now - comment.startTime)
            switch comment.mode {
            case .scroll:
                let x = comment.startX - comment.speed * CGFloat(elapsed)
                comment.label.frame.origin.x = x
                if x + comment.width < -8 {
                    removals.append(id)
                }
            case .top, .bottom:
                if elapsed > 4.4 {
                    removals.append(id)
                }
            }
        }
        for id in removals {
            guard let comment = active.removeValue(forKey: id) else { continue }
            comment.label.removeFromSuperview()
        }
    }

    private func clearActive() {
        for comment in active.values {
            comment.label.removeFromSuperview()
        }
        active.removeAll()
        scrollLanes.removeAll()
        fixedTopFreeAt.removeAll()
        fixedBottomFreeAt.removeAll()
    }

    private var textShadow: NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.92)
        shadow.shadowBlurRadius = 4
        shadow.shadowOffset = CGSize(width: 0, height: 1)
        return shadow
    }

    private func readableColor(_ rgb: UInt32) -> UIColor {
        var red = CGFloat((rgb >> 16) & 0xFF) / 255
        var green = CGFloat((rgb >> 8) & 0xFF) / 255
        var blue = CGFloat(rgb & 0xFF) / 255
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        if luminance < 0.30 {
            red = red * 0.45 + 0.55
            green = green * 0.45 + 0.55
            blue = blue * 0.45 + 0.55
        }
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}
