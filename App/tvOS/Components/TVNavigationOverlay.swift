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
        Group {
            if model.navigationExpanded {
                panel
                    .modifier(NavigationMaterial(reduceTransparency: reduceTransparency))
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .onMoveCommand { direction in
                        if direction == .right || (direction == .down && (focus == "account" || focus == AppTab.profile.rawValue)) { close() }
                    }
                    .onExitCommand(perform: close)
            } else {
                Button { open() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold))
                        avatar(size: 48)
                    }.padding(8).background(.black.opacity(0.25), in: Capsule())
                }
                .buttonStyle(NavigationButtonStyle()).focusEffectDisabled()
                .focused($focus, equals: "avatar")
                .accessibilityLabel("打开导航")
                .accessibilityIdentifier("navigation-avatar")
                .onMoveCommand { direction in
                    if direction == .up || direction == .left { open() }
                }
            }
        }
        .padding(.leading, 48).padding(.top, 40).padding(.bottom, 40)
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: model.navigationExpanded) {
            if model.navigationExpanded { focus = model.selectedTab.rawValue }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 44) {
            Button {
                model.selectedTab = .profile; close()
            } label: {
                HStack(spacing: 14) {
                    avatar(size: 56)
                    Text(model.accountStatus?.bangumi?.nickname ?? "我的 Doki")
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
            Label("向右返回内容", systemImage: "chevron.right")
                .font(.system(size: 19)).foregroundStyle(.secondary).padding(20)
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
    func body(content: Content) -> some View {
        content.background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 44).fill(Color(red: 0.27, green: 0.29, blue: 0.36))
            } else {
                NavigationLightFrost()
                    .clipShape(RoundedRectangle(cornerRadius: 44))
                    .overlay(RoundedRectangle(cornerRadius: 44).fill(.black.opacity(0.10)))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 44).strokeBorder(.white.opacity(0.28), lineWidth: 1.2))
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
