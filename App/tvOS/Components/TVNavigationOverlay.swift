import SwiftUI
import UIKit
import DokiCore
import DokiUI

/// The content keeps its own navigation stacks. This is only the transient
/// navigation layer, with a translucent material that retains scene color.
struct TVNavigationOverlay: View {
    @Bindable var model: AppModel
    let close: () -> Void
    @FocusState private var focus: String?
    @Environment(\.dokiReduceMotion) private var reduceMotion
    @Environment(\.dokiReduceTransparency) private var reduceTransparency
    private let destinations: [AppTab] = [.search, .discover, .library, .calendar, .profile]

    var body: some View {
        GeometryReader { geometry in
            let expanded = model.navigationExpanded
            let visible = expanded || model.selectedTab != .discover || (model.discoverHeroVisible && !model.discoverBrowsingShelf)
            ZStack(alignment: .topLeading) {
                if expanded {
                    panel
                        .transition(.opacity)
                        .onMoveCommand { direction in
                            if direction == .right || (direction == .down && (focus == "account" || focus == AppTab.profile.rawValue)) { close() }
                        }
                        .onExitCommand(perform: close)
                } else if visible {
                    Button { open() } label: {
                        HStack(spacing: 12) {
                            avatar(size: 44)
                            Text(accountName).font(.system(size: 23, weight: .medium)).lineLimit(1)
                        }
                        .padding(.horizontal, 14).frame(width: 250, height: 72, alignment: .leading)
                    }
                    .buttonStyle(NavigationButtonStyle()).focusEffectDisabled()
                    .focused($focus, equals: "avatar")
                    .accessibilityLabel("\(accountName)，打开导航")
                    .accessibilityIdentifier("navigation-avatar")
                    .onMoveCommand { direction in
                        if direction == .up || direction == .left { open() }
                    }
                    .transition(.opacity)
                }
            }
            // One material surface changes size around the capsule's top-left origin.
            // Both directions follow the same interruptible animation; no side slide.
            .frame(width: expanded ? 420 : 250,
                   height: expanded ? max(720, geometry.size.height - 80) : 72, alignment: .topLeading)
            .modifier(NavigationMaterial(reduceTransparency: reduceTransparency, radius: expanded ? 44 : 36))
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .disabled(!visible)
            .accessibilityHidden(!visible)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: visible)
            .padding(.leading, 48).padding(.top, 40)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .task(id: model.navigationExpanded) {
            if model.navigationExpanded { focus = model.selectedTab.rawValue }
        }
    }

    private var accountName: String {
        guard let account = model.accountStatus?.bangumi else { return "未登录" }
        return account.nickname.isEmpty ? account.username : account.nickname
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 44) {
            Button {
                model.selectedTab = .profile; close()
            } label: {
                HStack(spacing: 14) {
                    avatar(size: 56)
                    Text(accountName)
                        .font(.system(size: 25, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 4)
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(context.date, format: .dateTime.hour().minute())
                            .font(.system(size: 23, weight: .regular)).monospacedDigit()
                    }
                }.padding(12)
            }
            .buttonStyle(NavigationButtonStyle()).focusEffectDisabled().focused($focus, equals: "account")
            .accessibilityIdentifier("navigation-account")
            VStack(spacing: 12) {
                ForEach(destinations) { tab in
                    Button {
                        model.selectedTab = tab; close()
                    } label: {
                        HStack(spacing: 20) {
                            Image(systemName: tab.systemImage).font(.system(size: 24, weight: .semibold)).frame(width: 32)
                            Text(tab.title).font(.system(size: 29, weight: .medium))
                            Spacer()
                        }
                        .foregroundStyle(focus == tab.rawValue ? Color.black : Color.primary)
                        .padding(.horizontal, 24).frame(height: 78)
                        .background(focus == tab.rawValue ? Color.white : (model.selectedTab == tab ? Color.primary.opacity(0.10) : .clear), in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(NavigationButtonStyle()).focusEffectDisabled().focused($focus, equals: tab.rawValue)
                    .accessibilityIdentifier("navigation-\(tab.rawValue)")
                    .accessibilityAddTraits(model.selectedTab == tab ? [.isSelected] : [])
                }
            }
            Spacer(minLength: 24)
        }
        .padding(16).frame(width: 420)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func avatar(size: CGFloat) -> some View {
        Group {
            if let raw = model.accountStatus?.bangumi?.avatar, let url = CatalogSubject.approvedImage(raw) {
                DokiArtworkView(assetName: nil, title: "用户头像", accentHex: "8BB8C8", remoteURL: url)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFit().foregroundStyle(.primary.opacity(0.85))
                    .padding(2).background(Color.primary.opacity(0.08))
            }
        }.frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true)
    }
    private func open() {
        guard !model.navigationExpanded else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88)) { model.navigationExpanded = true }
    }
}

private struct NavigationMaterial: ViewModifier {
    let reduceTransparency: Bool
    var radius: CGFloat = 44
    func body(content: Content) -> some View {
        content.background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: radius).fill(Color(red: 0.27, green: 0.29, blue: 0.36))
            } else if radius < 40 {
                RoundedRectangle(cornerRadius: radius).fill(.ultraThinMaterial)
            } else {
                NavigationLightFrost()
                    .clipShape(RoundedRectangle(cornerRadius: radius))
                    .overlay(RoundedRectangle(cornerRadius: radius).fill(.black.opacity(0.10)))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.28), lineWidth: 1.2))
    }
}

/// Interpolate the public UIKit blur effect itself, rather than reducing the
/// opacity of a fully blurred copy (which makes background text show twice).
private struct NavigationLightFrost: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView()
        view.isUserInteractionEnabled = false
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
            view.effect = UIBlurEffect(style: .dark)
        }
        animator.startAnimation()
        animator.pauseAnimation()
        animator.fractionComplete = 0.32
        context.coordinator.animator = animator
        return view
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
    static func dismantleUIView(_ uiView: UIVisualEffectView, coordinator: Coordinator) {
        coordinator.animator?.stopAnimation(true)
        coordinator.animator = nil
    }
    @MainActor final class Coordinator {
        var animator: UIViewPropertyAnimator?
    }
}

private struct NavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Focus boundary events cover both directional clicks and touchpad swipes.
/// Normal movement between content cards and menu rows remains system-owned.
struct TVNavigationFocusBridge: ViewModifier {
    let enabled: Bool
    let expanded: Bool
    let open: () -> Void
    let close: () -> Void
    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: UIFocusSystem.movementDidFailNotification)) { notification in
            guard enabled,
                  let context = notification.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext else { return }
            let heading = context.focusHeading
            if expanded {
                if heading.contains(.right) || heading.contains(.down) { close() }
            } else if heading.contains(.up) || heading.contains(.left) { open() }
        }
    }
}
