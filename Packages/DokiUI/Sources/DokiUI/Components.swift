import SwiftUI
import DokiCore

public struct DokiSectionHeader<Trailing: View>: View {
    public let title: String
    public let subtitle: String?
    private let trailing: Trailing

    public init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(DokiType.sectionTitle)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(DokiType.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 24)
            trailing
        }
        .padding(.horizontal, DokiTheme.pagePadding)
    }
}

public extension DokiSectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

public struct DokiBadge: View {
    public enum Tone: Sendable {
        case accent
        case available
        case scheduled
        case warning
        case neutral
        case demo
    }

    public let text: String
    public let tone: Tone
    public var symbol: String?
    @Environment(\.colorScheme) private var colorScheme

    public init(_ text: String, tone: Tone = .neutral, symbol: String? = nil) {
        self.text = text
        self.tone = tone
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
            }
            Text(text)
                .font(DokiType.micro)
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(background, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(border, lineWidth: 1)
        )
    }

    private var isLight: Bool { colorScheme == .light }

    private var foreground: Color {
        if isLight { return .white }
        return switch tone {
        case .accent: DokiTheme.accent
        case .available: Color(red: 0.54, green: 0.93, blue: 0.72)
        case .scheduled: Color(red: 0.98, green: 0.82, blue: 0.48)
        case .warning: Color(red: 1.0, green: 0.66, blue: 0.58)
        case .neutral: Color.secondary
        case .demo: Color(red: 0.75, green: 0.82, blue: 1.0)
        }
    }

    private var background: Color {
        if isLight {
            switch tone {
            case .accent: return DokiTheme.accent
            case .available: return Color(red: 0.05, green: 0.38, blue: 0.23)
            case .scheduled: return Color(red: 0.48, green: 0.31, blue: 0.05)
            case .warning: return Color(red: 0.55, green: 0.16, blue: 0.12)
            case .neutral: return Color.black.opacity(0.66)
            case .demo: return Color(red: 0.12, green: 0.27, blue: 0.52)
            }
        }
        return switch tone {
        case .accent: DokiTheme.accent.opacity(0.16)
        case .available: Color(red: 0.22, green: 0.62, blue: 0.44).opacity(0.22)
        case .scheduled: Color(red: 0.55, green: 0.43, blue: 0.16).opacity(0.22)
        case .warning: Color(red: 0.55, green: 0.23, blue: 0.20).opacity(0.25)
        case .neutral: Color.primary.opacity(0.08)
        case .demo: Color(red: 0.20, green: 0.31, blue: 0.55).opacity(0.28)
        }
    }

    private var border: Color {
        if isLight {
            return Color.white.opacity(0.16)
        }
        return switch tone {
        case .accent: DokiTheme.accent.opacity(0.35)
        case .available: Color(red: 0.54, green: 0.93, blue: 0.72).opacity(0.35)
        case .scheduled: Color(red: 0.98, green: 0.82, blue: 0.48).opacity(0.32)
        case .warning: Color(red: 1.0, green: 0.66, blue: 0.58).opacity(0.35)
        case .neutral: Color.primary.opacity(0.12)
        case .demo: Color(red: 0.75, green: 0.82, blue: 1.0).opacity(0.25)
        }
    }
}

public struct DokiProgressBar: View {
    public let fraction: Double
    public var tint: Color
    public var height: CGFloat

    public init(fraction: Double, tint: Color = DokiTheme.accent, height: CGFloat = 5) {
        self.fraction = fraction
        self.tint = tint
        self.height = height
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(tint)
                    .frame(width: max(3, geometry.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("观看进度"))
        .accessibilityValue(Text("\(Int(min(max(fraction, 0), 1) * 100))%"))
    }
}

public struct DokiProgressRing: View {
    public let fraction: Double
    public var size: CGFloat = 54

    public init(fraction: Double, size: CGFloat = 54) {
        self.fraction = fraction
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(DokiTheme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

public struct DokiEmptyState: View {
    public let title: String
    public let message: String
    public var symbol: String

    public init(title: String, message: String, symbol: String = "rectangle.stack") {
        self.title = title
        self.message = message
        self.symbol = symbol
    }

    public var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(DokiTheme.accent.opacity(0.82))
            Text(title)
                .font(DokiType.sectionTitle)
                .foregroundStyle(.primary)
            Text(message)
                .font(DokiType.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 720)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
        .accessibilityElement(children: .combine)
    }
}

public struct DokiInlineStatus: View {
    public let title: String
    public let detail: String
    public var symbol: String
    public var tone: DokiBadge.Tone

    public init(
        title: String,
        detail: String,
        symbol: String = "info.circle",
        tone: DokiBadge.Tone = .neutral
    ) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.tone = tone
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(DokiTheme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(DokiType.cardTitle)
                Text(detail)
                    .font(DokiType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        )
    }
}
