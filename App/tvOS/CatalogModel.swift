import Foundation
import DokiCore

struct CatalogSnapshot: Codable {
    let subjects: [String: Subject]
    let picks: [String]
    let days: [Int: [String]]
}

extension AppModel {
    var catalogClient: CatalogClient { CatalogClient(hubURL: configuredHubURL) }
    var configuredHubURL: URL? {
        let text = hubURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let url = URL(string: text), ["http", "https"].contains(url.scheme), url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return nil }
        return url
    }
    var allFollowedSubjects: [Subject] {
        if usesFixtures { return library.subjects }
        return catalogSubjects.values.filter { followOverrides[$0.id] != nil || accountCollectionIDs.contains($0.id) }.sorted { $0.title < $1.title }
    }
    var todayCatalog: [Subject] { calendarSubjects(on: .now) }
    func calendarSubjects(on day: Date) -> [Subject] {
        (catalogDays[Calendar.current.component(.weekday, from: day)] ?? []).compactMap { catalogSubjects[$0] }
    }
    func restoreCatalog() {
        if let choices = defaults.data(forKey: "doki.artwork.choices.v1"), let decoded = try? JSONDecoder().decode([String: ArtworkCandidate].self, from: choices) { artworkChoices = decoded }
        guard let data = defaults.data(forKey: "doki.catalog.snapshot.v1"),
              let snapshot = try? JSONDecoder().decode(CatalogSnapshot.self, from: data) else { return }
        catalogSubjects = snapshot.subjects; catalogPicks = snapshot.picks; catalogDays = snapshot.days
        for (id, state) in followOverrides { catalogSubjects[id]?.followState = state }
    }
    func persistCatalog() {
        let retained = Set(catalogPicks + catalogDays.values.flatMap { $0 } + Array(followOverrides.keys) + Array(accountCollectionIDs))
        let subjects = catalogSubjects.filter { retained.contains($0.key) }
        if let data = try? JSONEncoder().encode(CatalogSnapshot(subjects: subjects, picks: catalogPicks, days: catalogDays)) {
            defaults.set(data, forKey: "doki.catalog.snapshot.v1")
        }
    }
    func mergeCatalog(_ entry: CatalogSubject, weekday: Int? = nil) {
        guard entry.nsfw != true, entry.type == nil || entry.type == 2 else { return }
        let id = "bgm-\(entry.id)"
        let old = catalogSubjects[id]
        var subject = entry.subject(weekday: weekday ?? old?.weekday ?? 0, fallback: old)
        subject.followState = followOverrides[id] ?? old?.followState ?? .planned
        subject.backdropURL = old?.backdropURL
        subject.titleLogoURL = old?.titleLogoURL
        subject.titleLogoAspect = old?.titleLogoAspect
        if entry.rating?.total == nil { subject.statistics = old?.statistics }
        if subject.posterURL == nil { subject.posterURL = old?.posterURL }
        catalogSubjects[id] = subject
    }
    func refreshCatalog() async {
        if usesFixtures { await refreshDemoContent(); return }
        catalogGeneration += 1
        let generation = catalogGeneration
        let address = hubURLString
        guard address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || configuredHubURL != nil else {
            catalogError = "Hub 地址无效，请在“我的 → Hub”填写完整地址。"; return
        }
        for (id, subject) in catalogSubjects {
            if let old = subject.backdropURL, old.path.hasPrefix("/v1/artwork/tmdb/") {
                catalogSubjects[id]?.backdropURL = configuredHubURL.flatMap { URL(string: $0.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + old.path) }
            }
        }
        isRefreshing = true
        defer { if generation == catalogGeneration { isRefreshing = false } }
        do {
            let home = try await catalogClient.home()
            try Task.checkCancellation()
            guard address == hubURLString, generation == catalogGeneration else { return }
            for day in home.calendar { for item in day.items { mergeCatalog(item, weekday: day.appleWeekday) } }
            for item in home.picks.data { mergeCatalog(item) }
            var days: [Int: [String]] = [:]
            for day in home.calendar {
                days[day.appleWeekday, default: []] += day.items.filter { $0.type == 2 && $0.nsfw != true }.map { "bgm-\($0.id)" }
            }
            catalogDays = days.mapValues { ids in var seen = Set<String>(); return ids.filter { seen.insert($0).inserted } }
            var picksSeen = Set<String>()
            catalogPicks = home.picks.data.filter { $0.nsfw != true }.map { "bgm-\($0.id)" }.filter { picksSeen.insert($0).inserted }
            lastRefresh = .now; catalogError = nil; persistCatalog()
            // Warm only the visible first shelf; subsequent previews are requested by focus.
            await withTaskGroup(of: Void.self) { group in
                for id in catalogPicks.prefix(8) { group.addTask { await self.loadArtwork(id) } }
            }
        } catch is CancellationError { } catch {
            guard address == hubURLString, generation == catalogGeneration else { return }
            catalogError = "无法刷新 Bangumi，已显示的内容会保留。请检查网络后重试。"
        }
    }
    func loadDetail(_ id: String) async {
        guard let subject = subject(id: id), subject.isRealCatalog else { return }
        let client = catalogClient; let address = hubURLString
        do {
            async let detail = client.subject(subject.bgmSubjectId)
            async let list = client.episodes(subject.bgmSubjectId)
            let (item, episodes) = try await (detail, list)
            try Task.checkCancellation(); guard address == hubURLString else { return }
            mergeCatalog(item)
            catalogEpisodes[id] = episodes.map { $0.episode(subjectID: id) }
            detailErrors[id] = nil; persistCatalog()
        } catch is CancellationError { return } catch {
            guard address == hubURLString else { return }
            detailErrors[id] = "简介或章节加载失败，请重试。"
        }
        async let art: () = loadArtwork(id)
        async let credits: () = loadCredits(id)
        _ = await (art, credits)
    }
    private func mergedCredits(_ entries: [CatalogCredit]) -> [CatalogCredit] {
        var result: [CatalogCredit] = []; var indexes: [Int: Int] = [:]
        for entry in entries {
            if let index = indexes[entry.id] { result[index] = result[index].merging(entry) }
            else { indexes[entry.id] = result.count; result.append(entry) }
        }
        return result
    }
    func loadCredits(_ id: String) async {
        guard let subject = subject(id: id), subject.isRealCatalog else { return }
        let address = hubURLString; let client = catalogClient
        do {
            async let characters = client.credits(subject.bgmSubjectId, characters: true)
            async let staff = client.credits(subject.bgmSubjectId, characters: false)
            let (c, s) = try await (characters, staff)
            try Task.checkCancellation(); guard address == hubURLString else { return }
            characterCredits[id] = mergedCredits(c)
            staffCredits[id] = mergedCredits(s)
            creditErrors[id] = nil
        } catch is CancellationError { } catch { if address == hubURLString { creditErrors[id] = "角色与制作人员暂时无法加载。" } }
    }
    func loadArtwork(_ id: String) async {
        guard let subject = subject(id: id), subject.isRealCatalog else { return }
        let address = hubURLString
        if let entry = await PublicArtworkMap.shared.lookup(subject.bgmSubjectId) {
            guard address == hubURLString, !Task.isCancelled else { return }
            if artworkChoices[id] == nil {
                catalogSubjects[id]?.backdropURL = entry.backdropURL
                catalogSubjects[id]?.titleLogoURL = entry.logoURL
                catalogSubjects[id]?.titleLogoAspect = entry.logoAspect
            }
            if entry.backdropURL != nil || entry.manual {
                artworkMapIDs.insert(id)
                persistCatalog()
                if let manual = artworkChoices[id] { chooseArtwork(manual, subjectID: id, notify: false) }
                return
            }
        }
        do {
            let artwork = try await catalogClient.artwork(subject.bgmSubjectId)
            try Task.checkCancellation(); guard address == hubURLString else { return }
            artworkResults[id] = artwork
            if let manual = artworkChoices[id] { chooseArtwork(manual, subjectID: id, notify: false) }
            else if let selected = artwork.selected { chooseArtwork(selected, subjectID: id, notify: false) }
        } catch { }
    }
    func chooseArtwork(_ candidate: ArtworkCandidate, subjectID: String, notify: Bool = true) {
        guard let hub = configuredHubURL, let path = candidate.backdropURL,
              path.hasPrefix("/v1/artwork/tmdb/"), let url = URL(string: hub.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path) else { return }
        catalogSubjects[subjectID]?.backdropURL = url
        catalogSubjects[subjectID]?.titleLogoURL = nil
        catalogSubjects[subjectID]?.titleLogoAspect = nil
        persistCatalog()
        if notify {
            artworkChoices[subjectID] = candidate
            if let data = try? JSONEncoder().encode(artworkChoices) { defaults.set(data, forKey: "doki.artwork.choices.v1") }
            showToast("已选择 TMDB 横幅（本机）")
        }
    }
    func searchCatalog(loadMore: Bool = false) async {
        guard !usesFixtures else { return }
        if loadMore && isSearching { return }
        searchGeneration += 1
        let generation = searchGeneration
        let address = hubURLString
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hubURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || configuredHubURL != nil else { searchError = "Hub 地址无效，请在设置中修正。"; isSearching = false; return }
        guard !query.isEmpty else { remoteSearchResults = []; searchError = nil; isSearching = false; return }
        isSearching = true
        defer { if searchGeneration == generation { isSearching = false } }
        do {
            if !loadMore { try await Task.sleep(for: .milliseconds(350)) }
            try Task.checkCancellation()
            let offset = loadMore ? searchOffset : 0
            let page = try await catalogClient.search(query, offset: offset)
            try Task.checkCancellation()
            guard address == hubURLString, searchGeneration == generation, searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
            for item in page.data { mergeCatalog(item) }
            let subjects = page.data.filter { $0.nsfw != true && ($0.type == nil || $0.type == 2) }.compactMap { catalogSubjects["bgm-\($0.id)"] }
            var seen = Set<String>()
            remoteSearchResults = ((loadMore ? remoteSearchResults : []) + subjects).filter { seen.insert($0.id).inserted }
            searchOffset = offset + page.data.count; searchTotal = page.total; searchError = nil; completedSearchQuery = query
        } catch is CancellationError { } catch {
            guard address == hubURLString, searchGeneration == generation, searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
            searchError = "搜索暂时不可用，请重试。"
        }
    }
}
