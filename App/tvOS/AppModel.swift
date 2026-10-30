import Foundation
import Observation
import SwiftUI
import DokiCore
import DokiDanmaku

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case discover
    case library
    case calendar
    case search
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: "发现"
        case .library: "追番"
        case .calendar: "日历"
        case .search: "搜索"
        case .profile: "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .discover: "sparkles"
        case .library: "books.vertical.fill"
        case .calendar: "calendar"
        case .search: "magnifyingglass"
        case .profile: "person.crop.circle"
        }
    }
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case watching
    case today
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .watching: "追看中"
        case .today: "今日更新"
        case .completed: "已完成"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .dark: "深色"
        case .light: "浅色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

enum AppRoute: Hashable {
    case subject(String)
    case integrationSettings
    case sourceSettings
    case danmakuSettings
    case hubSettings
    case bangumiAuth
    case realSourcePreview
    case about
    case diagnostics
}

struct PlaybackRoute: Identifiable, Hashable {
    let id: UUID
    let subjectID: String
    let episodeID: String
    let episodeNumber: Int
    let subjectTitle: String
    let episodeTitle: String
    let sourceID: String
    let sourceDisplayName: String
    let startAtSeconds: Double
    let durationSeconds: Double
    let mediaURL: URL?
    let isRealSourcePreview: Bool

    init(
        id: UUID = UUID(),
        subject: Subject,
        episode: Episode,
        sourceID: String,
        startAtSeconds: Double
    ) {
        self.id = id
        self.subjectID = subject.id
        self.episodeID = episode.id
        self.episodeNumber = episode.number
        self.subjectTitle = subject.title
        self.episodeTitle = episode.title
        self.sourceID = sourceID
        self.sourceDisplayName = "演示源"
        self.startAtSeconds = startAtSeconds
        self.durationSeconds = episode.durationSeconds
        self.mediaURL = nil
        self.isRealSourcePreview = false
    }

    init(
        id: UUID = UUID(),
        episodeID: String,
        subjectID: String,
        subjectTitle: String,
        episodeNumber: Int,
        episodeTitle: String,
        sourceID: String,
        sourceDisplayName: String,
        startAtSeconds: Double,
        durationSeconds: Double,
        mediaURL: URL
    ) {
        self.id = id
        self.subjectID = subjectID
        self.episodeID = episodeID
        self.episodeNumber = episodeNumber
        self.subjectTitle = subjectTitle
        self.episodeTitle = episodeTitle
        self.sourceID = sourceID
        self.sourceDisplayName = sourceDisplayName
        self.startAtSeconds = startAtSeconds
        self.durationSeconds = durationSeconds
        self.mediaURL = mediaURL
        self.isRealSourcePreview = true
    }
}

struct DanmakuMapping: Codable, Hashable {
    let episodeID: String
    var danmakuEpisodeID: String
    var title: String
    var revision: Int
    var confirmed: Bool
    var provenance: String
}

struct DanmakuCandidate: Identifiable, Hashable {
    let id: String
    let danmakuEpisodeID: String
    let title: String
    let detail: String
    let isRecommended: Bool
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

enum HubConnectionState: Equatable {
    case demo
    case notConfigured
    case notChecked
    case checking
    case connected(String)
    case failed(String)

    var title: String {
        switch self {
        case .demo: "演示模式"
        case .notConfigured: "未连接 Hub"
        case .notChecked: "待检查"
        case .checking: "正在检查"
        case .connected: "已连接"
        case .failed: "连接失败"
        }
    }

    var detail: String {
        switch self {
        case .demo:
            "当前使用自造数据。填写 Hub 地址后可做一次真实 /health 检查。"
        case .notConfigured:
            "尚未填写 Doki Hub 地址。"
        case .notChecked:
            "地址已保存，尚未检查。"
        case .checking:
            "正在请求 Hub 的 /health。"
        case .connected(let version):
            "Hub 可达，版本 \(version)。"
        case .failed(let message):
            message
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isBusy: Bool {
        if case .checking = self { return true }
        return false
    }
}

@MainActor
@Observable
final class AppModel {
    // MARK: Content

    var manualWatchOverrides: [String: Bool] = UserDefaults.standard.dictionary(forKey: "doki.watchOverrides.v1") as? [String: Bool] ?? [:]
    @ObservationIgnored var catalogGeneration = 0
    @ObservationIgnored var searchGeneration = 0
    var artworkChoices: [String: ArtworkCandidate] = [:]
    var usesFixtures = false
    var catalogSubjects: [String: Subject] = [:]
    var catalogPicks: [String] = []
    var catalogPopular: [String] = []
    var popularError: String?
    @ObservationIgnored var popularGeneration = 0
    var catalogDays: [Int: [String]] = [:]
    var catalogEpisodes: [String: [Episode]] = [:]
    var catalogError: String?
    var detailErrors: [String: String] = [:]
    var characterCredits: [String: [CatalogCredit]] = [:]
    var staffCredits: [String: [CatalogCredit]] = [:]
    var creditErrors: [String: String] = [:]
    var accountStatus: HubAccountStatus?
    var accountError: String?
    var accountCollectionIDs: Set<String> = []
    var accountGeneration = 0
    var artworkMapIDs: Set<String> = []
    var artworkResults: [String: CatalogArtwork] = [:]
    var remoteSearchResults: [Subject] = []
    var searchError: String?
    var isSearching = false
    var searchTotal = 0
    var searchOffset = 0
    var completedSearchQuery = ""
    var library: DemoLibrary
    var progress: ProgressBook {
        didSet { persistProgress() }
    }
    var followOverrides: [String: Subject.FollowState] {
        didSet { persistFollowOverrides() }
    }
    var sources: [SourceProvider]
    var enabledSourceIDs: Set<String> {
        didSet { persistSources() }
    }
    var selectedSourceID: String {
        didSet { defaults.set(selectedSourceID, forKey: Keys.selectedSource) }
    }

    // MARK: Navigation and focus

    var selectedTab: AppTab = .discover
    var discoverPath: [AppRoute] = []
    var libraryPath: [AppRoute] = []
    var calendarPath: [AppRoute] = []
    var searchPath: [AppRoute] = []
    var profilePath: [AppRoute] = []
    var playerRoute: PlaybackRoute?

    var navigationExpanded = false
    var contentFocusRevision = 0
    var discoverHeroVisible = true
    var discoverBrowsingShelf = false
    var discoverShelfPreviewID: String?
    var discoverShelfPreviewVisible = false
    var discoverShelfPreviewProgress = 0.0
    var discoverHeroID: String?
    var transitionSourceID: String?
    var discoverFocusID: String?
    var libraryFocusID: String?
    var calendarFocusID: String?
    var searchFocusID: String?
    var profileFocusID: String?

    // MARK: Filters and calendar

    var libraryFilter: LibraryFilter = .all
    var selectedCalendarDate: Date
    var searchQuery: String = ""

    // MARK: Hub and preferences

    var hubURLString: String {
        didSet { defaults.set(hubURLString, forKey: Keys.hubURL) }
    }
    var hubState: HubConnectionState
    var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearance) }
    }
    var danmakuPreferences: DanmakuPreferences {
        didSet {
            persistDanmakuPreferences()
            if !danmakuPreferences.enabled {
                // Keep the preference; the overlay reads enabled directly.
            }
        }
    }
    var danmakuMappings: [String: DanmakuMapping] {
        didSet { persistDanmakuMappings() }
    }

    // MARK: Ephemeral UI state

    var isRefreshing = false
    var lastRefresh: Date?
    var toast: ToastMessage?

    @ObservationIgnored let defaults: UserDefaults
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        usesFixtures = ProcessInfo.processInfo.arguments.contains("--demo-fixtures")
        let library = DemoLibrary()
        self.library = library
        self.sources = DemoSources.all
        self.selectedCalendarDate = Calendar.current.startOfDay(for: .now)

        let decoder = JSONDecoder()
        if let data = defaults.data(forKey: Keys.progress),
           let stored = try? decoder.decode(ProgressBook.self, from: data) {
            self.progress = stored
        } else {
            self.progress = library.seededProgress()
        }

        if let data = defaults.data(forKey: Keys.danmakuPreferences),
           let stored = try? decoder.decode(DanmakuPreferences.self, from: data) {
            self.danmakuPreferences = stored.normalized()
        } else {
            self.danmakuPreferences = DanmakuPreferences()
        }

        if let data = defaults.data(forKey: Keys.followOverrides),
           let stored = try? decoder.decode([String: Subject.FollowState].self, from: data) {
            self.followOverrides = stored
        } else {
            self.followOverrides = [:]
        }

        if let stored = defaults.stringArray(forKey: Keys.enabledSources) {
            self.enabledSourceIDs = Set(stored)
        } else {
            self.enabledSourceIDs = Set(DemoSources.all.filter { $0.status != .disabled }.map(\.id))
        }

        let storedSource = defaults.string(forKey: Keys.selectedSource)
        let validSources = DemoSources.all.filter { $0.status != .disabled }
        if let storedSource, validSources.contains(where: { $0.id == storedSource }) {
            self.selectedSourceID = storedSource
        } else {
            self.selectedSourceID = validSources.first?.id ?? DemoSources.all[0].id
        }

        if let data = defaults.data(forKey: Keys.danmakuMappings),
           let stored = try? decoder.decode([String: DanmakuMapping].self, from: data) {
            self.danmakuMappings = stored
        } else {
            let episodeID = "demo-subject-01-ep-05"
            self.danmakuMappings = [
                episodeID: DanmakuMapping(
                    episodeID: episodeID,
                    danmakuEpisodeID: "923450000000000105",
                    title: "星海邮差 · 第 5 话",
                    revision: 1,
                    confirmed: true,
                    provenance: "自造 fixture · 已确认（演示）"
                )
            ]
        }

        let storedURL = defaults.string(forKey: Keys.hubURL) ?? ""
        self.hubURLString = storedURL
        self.hubState = storedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (ProcessInfo.processInfo.arguments.contains("--demo-fixtures") ? .demo : .notConfigured)
            : .notChecked

        self.appearanceMode = AppearanceMode(
            rawValue: defaults.string(forKey: Keys.appearance) ?? ""
        ) ?? .system

        restoreCatalog()
        applyFollowOverrides()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--demo-reset-progress") {
            progress = library.seededProgress()
        }
        if arguments.contains("--demo-enable-danmaku") {
            danmakuPreferences.enabled = true
        }
        if let index = arguments.firstIndex(of: "--demo-hub-url"),
           index + 1 < arguments.count {
            hubURLString = arguments[index + 1]
            hubState = .notChecked
        }
        if arguments.contains("--demo-light") {
            appearanceMode = .light
        }
        if arguments.contains("--demo-dark") {
            appearanceMode = .dark
        }
        if let index = arguments.firstIndex(of: "--demo-search-query"), index + 1 < arguments.count { searchQuery = arguments[index + 1] }
        if let index = arguments.firstIndex(of: "--demo-tab"), index + 1 < arguments.count,
           let tab = AppTab(rawValue: arguments[index + 1]) {
            selectedTab = tab
        }
        if let index = arguments.firstIndex(of: "--demo-route"), index + 1 < arguments.count {
            let route = arguments[index + 1]
            selectedTab = .profile
            switch route {
            case "source": profilePath = [.sourceSettings]
            case "danmaku": profilePath = [.danmakuSettings]
            case "hub": profilePath = [.hubSettings]
            case "auth": profilePath = [.bangumiAuth]
            case "real-source": profilePath = [.realSourcePreview]
            case "player":
                selectedTab = .discover
                let id = arguments.firstIndex(of: "--demo-subject").flatMap { index in
                    index + 1 < arguments.count ? arguments[index + 1] : nil
                } ?? "demo-subject-01"
                let episodeNumber = arguments.firstIndex(of: "--demo-episode").flatMap { index in
                    index + 1 < arguments.count ? Int(arguments[index + 1]) : nil
                } ?? 5
                if let subject = library.subject(id: id),
                   let episode = library.episodes(for: subject).first(where: {
                       $0.number == episodeNumber
                   }) {
                    presentPlayer(for: subject, episode: episode)
                }
            case "about": profilePath = [.about]
            case "diagnostics": profilePath = [.diagnostics]
            case "detail":
                selectedTab = .discover
                let id = arguments.firstIndex(of: "--demo-subject").flatMap { index in
                    index + 1 < arguments.count ? arguments[index + 1] : nil
                } ?? "demo-subject-02"
                discoverPath = [.subject(id)]
            default:
                break
            }
        }
        #endif
        persistProgress()
        persistDanmakuMappings()
    }

    // MARK: Derived content

    var todayAvailable: [AiringEntry] {
        usesFixtures ? library.todayEntries.filter { $0.availability == .available } : []
    }

    var todayScheduled: [AiringEntry] {
        usesFixtures ? library.todayEntries.filter { $0.availability == .scheduled } : []
    }

    var continueWatching: [ContinueWatchingItem] {
        usesFixtures ? Array(library.continueWatching(progress: progress).prefix(6)) : []
    }

    var seasonPicks: [Subject] {
        usesFixtures ? library.seasonPicks : catalogPicks.compactMap { catalogSubjects[$0] }
    }

    var watchingCount: Int {
        allFollowedSubjects.filter { $0.followState == .watching }.count
    }

    var completedCount: Int {
        allFollowedSubjects.filter { $0.followState == .completed }.count
    }

    var calendarEntries: [AiringEntry] {
        usesFixtures ? library.airingEntries(on: selectedCalendarDate) : []
    }

    var calendarAvailable: [AiringEntry] {
        calendarEntries.filter { $0.availability == .available }
    }

    var calendarScheduled: [AiringEntry] {
        calendarEntries.filter { $0.availability != .available }
    }

    var searchResults: [Subject] {
        usesFixtures ? library.search(searchQuery) : remoteSearchResults
    }

    var suggestedSubjects: [Subject] {
        usesFixtures ? library.seasonPicks : catalogPicks.compactMap { catalogSubjects[$0] }
    }

    var selectedSource: SourceProvider? {
        sources.first { $0.id == selectedSourceID }
    }

    var enabledSources: [SourceProvider] {
        sources.filter { enabledSourceIDs.contains($0.id) }
    }

    var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return "\(version ?? "0.1.0") (\(build ?? "1"))"
    }

    var demoMediaURL: URL? {
        Bundle.main.url(forResource: "doki-demo-24min", withExtension: "mp4")
            ?? Bundle.main.url(
                forResource: "doki-demo-24min",
                withExtension: "mp4",
                subdirectory: "DemoMedia"
            )
    }

    func subject(id: String) -> Subject? {
        id.hasPrefix("bgm-") ? catalogSubjects[id] : library.subject(id: id)
    }

    func episodes(for subject: Subject) -> [Episode] {
        subject.isRealCatalog ? (catalogEpisodes[subject.id] ?? []) : library.episodes(for: subject)
    }

    func episode(id: String) -> Episode? {
        id.hasPrefix("bgm-ep-") ? catalogEpisodes.values.lazy.flatMap { $0 }.first { $0.id == id } : library.episode(id: id)
    }

    func progress(for episodeID: String) -> PlaybackPosition? {
        progress.position(for: episodeID)
    }

    func fraction(for episode: Episode) -> Double? {
        guard let position = progress.position(for: episode.id), position.positionSeconds > 0 else {
            return nil
        }
        return position.fraction
    }

    func latestPosition(for subjectID: String) -> PlaybackPosition? {
        progress.latestPosition(forSubject: subjectID)
    }

    func nextEpisode(for subject: Subject) -> Episode? {
        subject.isRealCatalog ? episodes(for: subject).first : library.nextEpisode(for: subject, progress: progress)
    }

    func isWatched(_ episode: Episode) -> Bool {
        if let manual = manualWatchOverrides[episode.id] { return manual }
        guard let subject = subject(id: episode.subjectID) else { return false }
        return subject.isRealCatalog ? progress.position(for: episode.id)?.isFinished == true : library.isWatched(subject: subject, episode: episode, progress: progress)
    }

    func filteredSubjects() -> [Subject] {
        if !usesFixtures {
            switch libraryFilter {
            case .all: return allFollowedSubjects
            case .watching: return allFollowedSubjects.filter { $0.followState == .watching }
            case .completed: return allFollowedSubjects.filter { $0.followState == .completed }
            case .today: return allFollowedSubjects.filter { $0.weekday == Calendar.current.component(.weekday, from: .now) }
            }
        }
        switch libraryFilter {
        case .all:
            return library.subjects
        case .watching:
            return library.subjects.filter { $0.followState == .watching }
        case .today:
            let ids = Set(library.todayEntries.map(\.subject.id))
            return library.subjects.filter { ids.contains($0.id) }
        case .completed:
            return library.subjects.filter { $0.followState == .completed }
        }
    }

    func dayEntries(for date: Date) -> [AiringEntry] {
        library.airingEntries(on: date)
    }

    // MARK: Actions

    func toggleFollow(_ subject: Subject) {
        if subject.isRealCatalog {
            let next: Subject.FollowState = followOverrides[subject.id] == .watching ? .paused : .watching
            followOverrides[subject.id] = next
            catalogSubjects[subject.id]?.followState = next
            persistCatalog()
            showToast(next == .watching ? "已加入本机追番" : "已暂停追番")
            return
        }
        guard let index = library.subjects.firstIndex(where: { $0.id == subject.id }) else { return }
        let current = library.subjects[index].followState
        let next: Subject.FollowState
        switch current {
        case .watching: next = .paused
        case .paused, .dropped: next = .watching
        case .planned: next = .watching
        case .completed: next = .watching
        }
        library.subjects[index].followState = next
        followOverrides[subject.id] = next
        showToast(next == .watching ? "已加入追看" : "已更新追番状态（本地演示）")
    }

    func refreshDemoContent() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        try? await Task.sleep(for: .milliseconds(650))
        lastRefresh = .now
        isRefreshing = false
        showToast("已刷新本地演示内容；未请求 Hub")
    }

    func checkHubConnection() async {
        let trimmed = hubURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hubState = .notConfigured
            return
        }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            hubState = .failed("地址需要是完整的 http(s) URL。")
            return
        }

        hubState = .checking
        do {
            let version = try await HubHealthClient.check(baseURL: url)
            guard hubURLString.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
            hubState = .connected(version)
            showToast("Hub 可达")
        } catch {
            guard hubURLString.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
            let message = (error as? any LocalizedError)?.errorDescription ?? "无法连接 Hub。"
            hubState = .failed(String(message.prefix(140)))
        }
    }

    func selectSource(_ source: SourceProvider) {
        guard source.status != .disabled else { return }
        selectedSourceID = source.id
        showToast("已选择 \(source.name)（演示源，未发起真实解析）")
    }

    func toggleSource(_ source: SourceProvider) {
        guard source.status != .disabled else {
            showToast("该规则格式不兼容，已禁用")
            return
        }
        if enabledSourceIDs.contains(source.id) {
            enabledSourceIDs.remove(source.id)
            if selectedSourceID == source.id {
                selectedSourceID = enabledSources.first?.id ?? DemoSources.all[0].id
            }
        } else {
            enabledSourceIDs.insert(source.id)
        }
    }

    func presentRealSource(_ plan: RealSourcePreviewPlan) {
        guard let mediaURL = plan.sourceURL else {
            showToast("Hub 返回的 relay 地址无效")
            return
        }
        let episodeID = plan.episode.mediaId
        let stored = progress.position(for: episodeID)?.positionSeconds ?? 0
        let startAt = PlaybackProgressPolicy.resumePosition(
            position: stored,
            duration: plan.durationHintSeconds
        )
        playerRoute = PlaybackRoute(
            episodeID: episodeID,
            subjectID: "real-preview-\(plan.provider.id)",
            subjectTitle: plan.subject.name,
            episodeNumber: plan.episode.number,
            episodeTitle: plan.episode.title,
            sourceID: plan.provider.id,
            sourceDisplayName: "\(plan.provider.name) · relay",
            startAtSeconds: startAt,
            durationSeconds: plan.durationHintSeconds,
            mediaURL: mediaURL
        )
    }

    func presentPlayer(for subject: Subject, episode: Episode, startAt: Double? = nil) {
        guard !subject.isRealCatalog else {
            showToast("尚未配置可用播放源；不会将演示片当作这部番剧播放")
            return
        }
        let resume = startAt ?? PlaybackProgressPolicy.resumePosition(
            position: progress.position(for: episode.id)?.positionSeconds ?? 0,
            duration: episode.durationSeconds
        )
        playerRoute = PlaybackRoute(
            subject: subject,
            episode: episode,
            sourceID: selectedSourceID,
            startAtSeconds: resume
        )
    }

    func playPrimary(for subject: Subject) {
        guard let episode = nextEpisode(for: subject) else {
            showToast("当前没有可播放的章节")
            return
        }
        presentPlayer(for: subject, episode: episode)
    }

    func resume(_ item: ContinueWatchingItem) {
        presentPlayer(
            for: item.subject,
            episode: item.episode,
            startAt: PlaybackProgressPolicy.resumePosition(
                position: item.positionSeconds,
                duration: item.episode.durationSeconds
            )
        )
    }

    func recordPlayback(
        route: PlaybackRoute,
        position: Double,
        duration: Double
    ) {
        progress.record(
            subjectID: route.subjectID,
            episodeID: route.episodeID,
            positionSeconds: position,
            durationSeconds: duration,
            sourceID: route.sourceID
        )
    }

    func markWatched(_ episode: Episode, watched: Bool) {
        manualWatchOverrides[episode.id] = watched
        UserDefaults.standard.set(manualWatchOverrides, forKey: "doki.watchOverrides.v1")
        if episode.subjectID.hasPrefix("bgm-") {
            showToast(watched ? "已标记为已看（本机）" : "已标记为未看（本机）")
            return
        }
        if watched {
            progress.record(
                subjectID: episode.subjectID,
                episodeID: episode.id,
                positionSeconds: episode.durationSeconds,
                durationSeconds: episode.durationSeconds,
                sourceID: selectedSourceID
            )
            showToast("已标记第 \(episode.number) 话为已看（本地）")
        } else {
            progress.clear(episodeID: episode.id)
            showToast("已取消已看标记（本地）")
        }
    }

    func resetDemoProgress() {
        progress = library.seededProgress()
        showToast("本地演示进度已恢复")
    }

    // MARK: Danmaku

    func mapping(for episodeID: String) -> DanmakuMapping? {
        danmakuMappings[episodeID]
    }

    func danmakuCandidates(for episode: Episode) -> [DanmakuCandidate] {
        let base = 923_450_000_000_000_000 + Int64(episode.number)
        let alternate = 823_450_000_000_000_000 + Int64(episode.number)
        let collection = 723_450_000_000_000_000 + Int64(episode.number)
        let subjectTitle = subject(id: episode.subjectID)?.title ?? "未知条目"
        return [
            DanmakuCandidate(
                id: "candidate-\(episode.id)-primary",
                danmakuEpisodeID: String(base),
                title: "\(subjectTitle) · 第 \(episode.number) 话",
                detail: "Bangumi 条目映射候选 · 演示 fixture",
                isRecommended: true
            ),
            DanmakuCandidate(
                id: "candidate-\(episode.id)-alternate",
                danmakuEpisodeID: String(alternate),
                title: "\(subjectTitle) 第 \(episode.number) 话（其他版本）",
                detail: "标题搜索候选 · 需要人工确认",
                isRecommended: false
            ),
            DanmakuCandidate(
                id: "candidate-\(episode.id)-collection",
                danmakuEpisodeID: String(collection),
                title: "\(subjectTitle) TV 合集",
                detail: "章节范围不匹配，不建议使用",
                isRecommended: false
            )
        ]
    }

    func confirmDanmaku(_ candidate: DanmakuCandidate, for episode: Episode) {
        let nextRevision = (danmakuMappings[episode.id]?.revision ?? 0) + 1
        danmakuMappings[episode.id] = DanmakuMapping(
            episodeID: episode.id,
            danmakuEpisodeID: candidate.danmakuEpisodeID,
            title: candidate.title,
            revision: nextRevision,
            confirmed: true,
            provenance: "手动确认 · 演示候选"
        )
        showToast("已保存弹幕匹配（演示）")
    }

    func clearDanmakuMapping(for episode: Episode) {
        danmakuMappings.removeValue(forKey: episode.id)
        showToast("已取消弹幕匹配（演示）")
    }

    func timeline(for episode: Episode) -> DanmakuTimeline? {
        guard let mapping = danmakuMappings[episode.id], mapping.confirmed else { return nil }
        return DanmakuFixture.demoTimeline
    }

    func isDanmakuMapped(_ episode: Episode) -> Bool {
        danmakuMappings[episode.id]?.confirmed == true
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        let toast = ToastMessage(message: message)
        self.toast = toast
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled, self?.toast?.id == toast.id else { return }
            self?.toast = nil
        }
    }

    func selectCalendarDay(_ date: Date) {
        selectedCalendarDate = Calendar.current.startOfDay(for: date)
    }

    func dismissPlayer() {
        playerRoute = nil
    }

    // MARK: Persistence

    private func applyFollowOverrides() {
        for (id, state) in followOverrides {
            guard let index = library.subjects.firstIndex(where: { $0.id == id }) else { continue }
            library.subjects[index].followState = state
        }
    }

    private func persistProgress() {
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: Keys.progress)
        }
    }

    private func persistFollowOverrides() {
        if let data = try? JSONEncoder().encode(followOverrides) {
            defaults.set(data, forKey: Keys.followOverrides)
        }
    }

    private func persistDanmakuPreferences() {
        if let data = try? JSONEncoder().encode(danmakuPreferences) {
            defaults.set(data, forKey: Keys.danmakuPreferences)
        }
    }

    private func persistDanmakuMappings() {
        if let data = try? JSONEncoder().encode(danmakuMappings) {
            defaults.set(data, forKey: Keys.danmakuMappings)
        }
    }

    private func persistSources() {
        defaults.set(Array(enabledSourceIDs).sorted(), forKey: Keys.enabledSources)
    }

    private enum Keys {
        static let progress = "doki.progress.v1"
        static let followOverrides = "doki.follow-overrides.v1"
        static let danmakuPreferences = "doki.danmaku-preferences.v1"
        static let danmakuMappings = "doki.danmaku-mappings.v1"
        static let enabledSources = "doki.sources.enabled.v1"
        static let selectedSource = "doki.sources.selected.v1"
        static let hubURL = "doki.hub.url.v1"
        static let appearance = "doki.appearance.v1"
    }
}

private struct HubHealthPayload: Decodable {
    let status: String?
    let version: String?
    let service: String?
}

private enum HubHealthClient {
    static func check(baseURL: URL) async throws -> String {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HubHealthError.invalidURL
        }
        if !components.path.hasSuffix("/health") {
            components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = "/" + components.path + (components.path.isEmpty ? "health" : "/health")
            components.path = components.path.replacingOccurrences(of: "//", with: "/")
            if components.path == "/health" { /* expected */ }
        }
        guard let url = components.url else { throw HubHealthError.invalidURL }

        var request = URLRequest(url: url, timeoutInterval: 4)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HubHealthError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HubHealthError.httpStatus(http.statusCode)
        }
        if let payload = try? JSONDecoder().decode(HubHealthPayload.self, from: data) {
            return payload.version ?? payload.service ?? "unknown"
        }
        return "unknown"
    }
}

private enum HubHealthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Hub 地址无效。"
        case .invalidResponse: "Hub 返回了无法识别的响应。"
        case .httpStatus(let status): "Hub 返回 HTTP \(status)。"
        }
    }
}
