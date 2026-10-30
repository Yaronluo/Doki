import SwiftUI
import DokiCore
import DokiUI

struct RootTabView: View {
    @Bindable var model: AppModel

    @Namespace private var transitionNamespace

    @Environment(\.dokiReduceMotion) private var reduceMotion
    @Environment(\.resetFocus) private var resetFocus
    @State private var needsContentFocus = false
    @Namespace private var contentScope

    var body: some View {
        ZStack {
            DokiHeroBackdrop(subject: activeSubject ?? model.popularSubjects.first ?? model.seasonPicks.first,
                             frosted: !usesCinematicBackdrop, navigationExpanded: model.navigationExpanded)
                .ignoresSafeArea()
            ZStack {
                tabPage(.discover, path: $model.discoverPath) { DiscoverView(model: model) }
                tabPage(.library, path: $model.libraryPath) { LibraryView(model: model) }
                tabPage(.calendar, path: $model.calendarPath) { CalendarView(model: model) }
                tabPage(.search, path: $model.searchPath) { SearchView(model: model) }
                tabPage(.profile, path: $model.profilePath) { ProfileView(model: model) }
            }
            .environment(\.dokiSharedBackground, true)
            .padding(.top, model.selectedTab == .discover || !activePath.isEmpty ? 0 : 90)
            .disabled(model.navigationExpanded)
            .accessibilityHidden(model.navigationExpanded)
            .focusScope(contentScope)
            if activePath.isEmpty {
                TVNavigationOverlay(model: model, close: closeNavigation)
            }
        }
        .modifier(TVNavigationFocusBridge(enabled: activePath.isEmpty && model.playerRoute == nil,
                                           expanded: model.navigationExpanded,
                                           open: openNavigation, close: closeNavigation))
        .task(id: model.navigationExpanded) {
            guard !model.navigationExpanded, needsContentFocus else { return }
            do {
                if !reduceMotion { try await Task.sleep(for: .milliseconds(450)) }
                try Task.checkCancellation()
                needsContentFocus = false
                resetFocus(in: contentScope)
                model.contentFocusRevision += 1
            } catch { }
        }
        .environment(\.dokiTransitionNamespace, transitionNamespace)
        .task(id: model.hubURLString) { async let catalog: () = model.refreshCatalog(); async let popular: () = model.refreshPopular(); async let account: () = model.refreshAccount(); _ = await (catalog, popular, account) }
        .fullScreenCover(item: $model.playerRoute) { route in
            PlayerScreen(model: model, route: route)
        }
    }

    private func openNavigation() {
        guard !model.navigationExpanded else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88)) { model.navigationExpanded = true }
    }
    private func closeNavigation() {
        guard model.navigationExpanded else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88)) { model.navigationExpanded = false }
        needsContentFocus = true
    }
    private var activePath: [AppRoute] {
        switch model.selectedTab {
        case .discover: model.discoverPath
        case .library: model.libraryPath
        case .calendar: model.calendarPath
        case .search: model.searchPath
        case .profile: model.profilePath
        }
    }
    private var usesCinematicBackdrop: Bool {
        if case .subject = activePath.last { return true }
        return model.selectedTab == .discover && activePath.isEmpty && model.discoverHeroVisible
    }
    private var activeSubject: Subject? {
        let path = activePath
        if case .subject(let id) = path.last { return model.subject(id: id) }
        if model.selectedTab == .discover {
            return model.discoverHeroID.flatMap { model.subject(id: $0) }
                ?? model.popularSubjects.first ?? model.seasonPicks.first(where: { $0.backdropURL != nil }) ?? model.seasonPicks.first
        }
        return nil
    }

    @ViewBuilder
    private func tabPage<Content: View>(
        _ tab: AppTab,
        path: Binding<[AppRoute]>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack(path: path) {
            content()
                .navigationDestination(for: AppRoute.self) { route in
                    RouteDestination(model: model, route: route)
                }
        }
        .opacity(model.selectedTab == tab ? 1 : 0)
        .allowsHitTesting(model.selectedTab == tab)
        .disabled(model.selectedTab != tab)
        .accessibilityHidden(model.selectedTab != tab)
    }
}

struct RouteDestination: View {
    @Bindable var model: AppModel
    let route: AppRoute
    @State private var sourceID: String?
    init(model: AppModel, route: AppRoute) {
        self.model = model; self.route = route
        _sourceID = State(initialValue: model.transitionSourceID)
    }
    @Environment(\.dokiTransitionNamespace) private var namespace
    @Environment(\.dokiReduceMotion) private var reduceMotion

    var body: some View {
        switch route {
        case .subject(let id):
            if let namespace, let source = sourceID, !reduceMotion {
                SubjectDetailView(model: model, subjectID: id).navigationTransition(.zoom(sourceID: source, in: namespace))
            } else {
                SubjectDetailView(model: model, subjectID: id)
            }
        case .integrationSettings:
            IntegrationSettingsView(model: model)
        case .sourceSettings:
            SourceSettingsView(model: model)
        case .danmakuSettings:
            DanmakuSettingsView(model: model, presentation: .settingsTab)
        case .hubSettings:
            HubSettingsView(model: model)
        case .bangumiAuth:
            BangumiAuthView(model: model)
        case .realSourcePreview:
            RealSourcePreviewView(model: model)
        case .about:
            AboutView(model: model)
        case .diagnostics:
            DiagnosticsView(model: model)
        }
    }
}
