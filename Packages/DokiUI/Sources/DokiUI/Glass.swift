import SwiftUI
import UIKit

/// A single translucent control surface. It is used only for navigation or
/// transient action layers; posters, episode rows and body copy remain opaque.
public struct DokiGlassBar<Content: View>: View {
    @Environment(\.dokiReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        Group {
            if reduceTransparency {
                content
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        DokiTheme.controlSurface(for: colorScheme),
                        in: Capsule()
                    )
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.16), lineWidth: 1))
            } else {
                content
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: Capsule())
            }
        }
        .accessibilityElement(children: .contain)
    }
}

public struct DokiGlassButton: View {
    public let title: String
    public var systemImage: String?
    public let action: () -> Void
    @Environment(\.dokiReduceTransparency) private var reduceTransparency

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Group {
            if reduceTransparency { control.buttonStyle(.bordered) }
            else { control.buttonStyle(.glass) }
        }.buttonBorderShape(.capsule)
    }
    private var control: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(DokiType.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Capsule())
        }
    }
}

/// A small icon-only glass control for player chrome and toolbar-adjacent
/// actions. The system focus effect is retained; no second scale animation is
/// applied on top.
public struct DokiGlassIconButton: View {
    public let systemImage: String
    public let accessibilityLabel: String
    public let action: () -> Void
    @Environment(\.dokiReduceTransparency) private var reduceTransparency

    public init(_ systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Group {
            if reduceTransparency { control.buttonStyle(.bordered) }
            else { control.buttonStyle(.glass) }
        }.buttonBorderShape(.circle)
    }
    private var control: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 46, height: 46)
                .contentShape(Circle())
        }
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

public struct DokiGlassGroup<Content: View>: View {
    @Environment(\.dokiReduceTransparency) private var reduceTransparency
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        if reduceTransparency {
            content
        } else {
            GlassEffectContainer(spacing: 12) {
                content
            }
        }
    }
}

/// A screen reader friendly section surface. This is deliberately a semantic
/// fill, not glass.
public struct DokiSurface<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    public init(padding: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.primary.opacity(0.055),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}
