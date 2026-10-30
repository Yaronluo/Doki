import SwiftUI
import DokiCore
import DokiUI

struct FocusableCard<Content: View>: View {
    let focusID: String
    let focus: FocusState<String?>.Binding
    let action: () -> Void
    let content: Content

    init(
        focusID: String,
        focus: FocusState<String?>.Binding,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.focusID = focusID
        self.focus = focus
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(PosterButtonStyle())
        .focused(focus, equals: focusID)
        .accessibilityIdentifier(focusID)
        .accessibilityAddTraits(.isButton)
    }
}

struct PageHeader: View {
    let title: String
    var subtitle: String?
    var badge: String?
    var trailing: AnyView?
    var onBack: (() -> Void)?

    init(
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        onBack: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.trailing = nil
        self.onBack = onBack
    }

    init<Trailing: View>(
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.trailing = AnyView(trailing())
        self.onBack = onBack
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    if let onBack {
                        DokiGlassIconButton("chevron.backward", accessibilityLabel: "返回") {
                            onBack()
                        }
                    }
                    Text("DOKI")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(2.8)
                        .foregroundStyle(DokiTheme.accent)
                    if let badge {
                        DokiBadge(badge, tone: .demo, symbol: "sparkles")
                    }
                }
                Text(title)
                    .font(DokiType.pageTitle)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(DokiType.body)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 24)
            if let trailing {
                trailing
            }
        }
        .padding(.horizontal, DokiTheme.pagePadding)
        .padding(.top, 32)
    }
}

struct SectionScaffold<Content: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    let trailing: Trailing
    let content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DokiSectionHeader(title, subtitle: subtitle) {
                trailing
            }
            content
        }
    }
}

struct HorizontalCardRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 24) {
                content
            }
            .padding(.horizontal, DokiTheme.pagePadding)
            .padding(.vertical, 18)
        }
        .scrollClipDisabled()
    }
}

struct FilterBar: View {
    @Binding var selection: LibraryFilter
    let counts: [LibraryFilter: Int]
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedFilter: LibraryFilter?

    private var selectedTextColor: Color {
        colorScheme == .light ? .white : .black
    }

    var body: some View {
        DokiGlassBar {
            HStack(spacing: 6) {
                ForEach(LibraryFilter.allCases) { filter in
                    Button {
                        selection = filter
                    } label: {
                        HStack(spacing: 7) {
                            Text(filter.title)
                                .font(DokiType.caption)
                            if let count = counts[filter], count > 0 {
                                Text("\(count)")
                                    .font(DokiType.micro)
                                    .foregroundStyle(
                                        selection == filter
                                            ? selectedTextColor.opacity(0.72)
                                            : Color.secondary
                                    )
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(selection == filter ? selectedTextColor : Color.primary)
                        .background(
                            selection == filter ? DokiTheme.accent : Color.clear,
                            in: Capsule()
                        )
                        .overlay {
                            if focusedFilter == filter {
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .focused($focusedFilter, equals: filter)
                    .accessibilityAddTraits(selection == filter ? [.isSelected, .isButton] : .isButton)
                }
            }
        }
        .onAppear {
            focusedFilter = selection
        }
    }
}

struct CalendarDayPill: View {
    let date: Date
    let isSelected: Bool
    let entryCount: Int
    let focus: FocusState<Date?>.Binding
    let action: () -> Void
    @Environment(\.isFocused) private var focused

    @Environment(\.colorScheme) private var colorScheme
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    private var selectedTextColor: Color {
        colorScheme == .light ? .white : .black
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(DokiDate.weekdayName(Calendar.current.component(.weekday, from: date)))
                    .font(DokiType.micro)
                    .foregroundStyle(isSelected ? selectedTextColor.opacity(0.72) : .secondary)
                Text(Calendar.current.component(.day, from: date).formatted())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? selectedTextColor : .primary)
                Text(isToday ? "今天" : (entryCount > 0 ? "\(entryCount) 部" : "—"))
                    .font(DokiType.micro)
                    .foregroundStyle(isSelected ? selectedTextColor.opacity(0.62) : .secondary)
            }
            .frame(width: 112, height: 104)
            .background(
                isSelected ? DokiTheme.accent : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        focused ? Color.white.opacity(0.88) : Color.primary.opacity(0.10),
                        lineWidth: focused ? 2.5 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .focused(focus, equals: date)
        .accessibilityLabel(Text(DokiDate.dayLabel(date)))
        .accessibilityValue(Text("\(entryCount) 个放送条目"))
    }
}

struct NavigationRow: View {
    let title: String
    let detail: String
    let systemImage: String
    var badge: DokiBadge?
    let action: () -> Void
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(DokiTheme.accent)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DokiType.cardTitle)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(DokiType.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 20)
                if let badge {
                    badge
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 17)
            .background(
                isFocused ? Color.white.opacity(0.13) : Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isFocused ? DokiTheme.accent.opacity(0.75) : Color.primary.opacity(0.08),
                        lineWidth: isFocused ? 2 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            VStack(spacing: 10) {
                content
            }
        }
    }
}

struct ToastBanner: View {
    let message: String

    var body: some View {
        DokiGlassBar {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DokiTheme.accent)
                Text(message)
                    .font(DokiType.caption)
            }
        }
    }
}

struct DemoNotice: View {
    var text: String = "演示数据 · 非 Bangumi / TMDB / 源站真实响应"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "testtube.2")
            Text(text)
        }
        .font(DokiType.micro)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.055), in: Capsule())
    }
}

extension EnvironmentValues {
    @Entry var dokiTransitionNamespace: Namespace.ID? = nil
}
struct DokiTransitionSource: ViewModifier {
    let id: String
    @Environment(\.dokiTransitionNamespace) private var namespace
    @Environment(\.dokiReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        if let namespace, !reduceMotion { content.matchedTransitionSource(id: id, in: namespace) }
        else { content }
    }
}
extension View {
    func dokiTransitionSource(_ id: String) -> some View { modifier(DokiTransitionSource(id: id)) }
}
struct PosterButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused
    @Environment(\.dokiReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : (focused ? 1.035 : 1))
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.85), value: focused)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
