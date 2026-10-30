import SwiftUI
import DokiCore
import DokiUI

struct RootTabView: View {
    @Bindable var model: AppModel

    @Namespace private var transitionNamespace

    var body: some View {
        ZStack {
            if let activeSubject { DokiHeroBackdrop(subject: activeSubject).ignoresSafeArea() }
            else { DokiBackground() }
            TabView(selection: $model.selectedTab) {
                Tab("发现", systemImage: "sparkles", value: AppTab.discover) { tabNavigation(path: $model.discoverPath) { DiscoverView(model: model) } }
                Tab("追番", systemImage: "books.vertical.fill", value: AppTab.library) { tabNavigation(path: $model.libraryPath) { LibraryView(model: model) } }
                Tab("日历", systemImage: "calendar", value: AppTab.calendar) { tabNavigation(path: $model.calendarPath) { CalendarView(model: model) } }
                Tab("搜索", systemImage: "magnifyingglass", value: AppTab.search) { tabNavigation(path: $model.searchPath) { SearchView(model: model) } }
                Tab("我的", systemImage: "person.crop.circle", value: AppTab.profile) { tabNavigation(path: $model.profilePath) { ProfileView(model: model) } }
            }
        }
        .environment(\.dokiTransitionNamespace, transitionNamespace)
        .task(id: model.hubURLString) { async let catalog: () = model.refreshCatalog(); async let account: () = model.refreshAccount(); _ = await (catalog, account) }
        .fullScreenCover(item: $model.playerRoute) { route in
            PlayerScreen(model: model, route: route)
        }
    }

    private var activeSubject: Subject? {
        let path: [AppRoute]
        switch model.selectedTab {
        case .discover: path = model.discoverPath
        case .library: path = model.libraryPath
        case .calendar: path = model.calendarPath
        case .search: path = model.searchPath
        case .profile: path = model.profilePath
        }
        if case .subject(let id) = path.last { return model.subject(id: id) }
        if model.selectedTab == .discover {
            return model.discoverHeroID.flatMap { model.subject(id: $0) }
                ?? model.seasonPicks.first(where: { $0.backdropURL != nil }) ?? model.seasonPicks.first
        }
        return nil
    }

    @ViewBuilder
    private func tabNavigation<Content: View>(
        path: Binding<[AppRoute]>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack(path: path) {
            content()
                .navigationDestination(for: AppRoute.self) { route in
                    RouteDestination(model: model, route: route)
                }
        }
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
