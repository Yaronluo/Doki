import SwiftUI

/// A quiet, flat control surface; content cards never acquire a material layer.
public struct DokiControlBar<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        content.padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain)
    }
}

public struct DokiControlButton: View {
    public let title: String
    public var systemImage: String?
    public let action: () -> Void
    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title; self.systemImage = systemImage; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(DokiType.caption)
            }.padding(.horizontal, 18).padding(.vertical, 13)
        }.buttonStyle(DokiButtonStyle())
    }
}

public struct DokiControlIconButton: View {
    public let systemImage: String
    public let accessibilityLabel: String
    public let action: () -> Void
    public init(_ systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.systemImage = systemImage; self.accessibilityLabel = accessibilityLabel; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 22, weight: .medium))
                .frame(width: 54, height: 54)
        }.buttonStyle(DokiButtonStyle()).accessibilityLabel(Text(accessibilityLabel))
    }
}

public struct DokiControlGroup<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View { content }
}

/// Custom content owns its shape. SwiftUI's tvOS PlainButtonStyle adds a
/// separate system focus plate, so it must not be used around an existing fill.
public struct DokiContentButtonStyle: ButtonStyle {
    public var drawFocusRing: Bool
    @Environment(\.isFocused) private var focused
    @Environment(\.isEnabled) private var enabled
    public init(drawFocusRing: Bool = true) { self.drawFocusRing = drawFocusRing }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if drawFocusRing && focused {
                    RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.7), lineWidth: 2)
                }
            }
            .opacity(enabled ? (configuration.isPressed ? 0.78 : 1) : 0.45)
    }
}

/// Solid focus feedback, without lensing, reflective rims or a glass container.
public struct DokiButtonStyle: ButtonStyle {
    public var prominent: Bool
    @Environment(\.isFocused) private var focused
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dokiReduceMotion) private var reduceMotion
    public init(prominent: Bool = false) { self.prominent = prominent }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(focused ? Color.black : (prominent ? Color.white : Color.primary))
            .background(focused ? Color.white : (prominent ? DokiTheme.accent : DokiTheme.controlSurface(for: scheme)), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : (focused ? 1.025 : 1))
            .opacity(enabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: focused)
    }
}

/// An opaque semantic content surface.
public struct DokiSurface<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    public init(padding: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.content = content(); self.padding = padding
    }
    public var body: some View {
        content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }
}
