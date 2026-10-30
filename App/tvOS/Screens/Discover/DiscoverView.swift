import SwiftUI
import DokiCore
import DokiUI

struct DiscoverView: View {
    @Bindable var model: AppModel
    @FocusState private var focusedID: String?
    @State private var previewID: String?
    @State private var expandedShelf: String?
    @State private var expandedSubjectID: String?
    @State private var shelfTimeline = ShelfHeroTimeline()
    @State private var openingID: String?
    @State private var openingSource: String?
    @State private var openFade = 0.0
    @State private var detailReturnFocusID: String?
    @State private var heroVisible = true
    @State private var manualRevision = 0
    @State private var heroGeneration = 0
    @State private var heroImageError: String?
    @State private var pendingFocusID: String?
    @State private var returningToHero = false
    @State private var verticalPosition = ScrollPosition(edge: .top)
    @State private var shelfTops: [String: CGFloat] = [:]
    @State private var expansionHeight: CGFloat = 0
    @State private var heroFocusGeneration = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.resetFocus) private var resetFocus
    @Namespace private var discoveryScope
    private var carousel: [Subject] { Array(model.popularSubjects.prefix(6)) }
    private var canRotate: Bool {
        carousel.count > 1 && heroVisible && !model.discoverBrowsingShelf && expandedSubjectID == nil && !model.navigationExpanded
        && model.selectedTab == .discover && model.discoverPath.isEmpty && model.playerRoute == nil
        && scenePhase == .active && !reduceMotion && !voiceOver

    }
    private var rotationKey: String {
        "\(canRotate)-\(manualRevision)-" + carousel.map(\.id).joined(separator: ",")
    }
    @Environment(\.dokiReduceMotion) private var reduceMotion
    private var preview: Subject? {
        previewID.flatMap { model.subject(id: $0) }
        ?? carousel.first ?? model.seasonPicks.first(where: { $0.backdropURL != nil }) ?? model.seasonPicks.first
    }
    private var shelfRows: [DiscoverShelf] {
        var rows = stride(from: 0, to: model.seasonPicks.count, by: 8).map { start in
            DiscoverShelf(id: "season-\(start)", title: start == 0 ? "本季推荐" : nil,
                          prefix: "season", subjects: Array(model.seasonPicks.dropFirst(start).prefix(8)))
        }
        if !model.todayCatalog.isEmpty {
            rows.append(DiscoverShelf(id: "today", title: "今日放送", prefix: "today", subjects: model.todayCatalog))
        }
        return rows
    }
    private var shelfMotion: Animation? { reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.88) }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            hero.id("hero").opacity(1 - shelfTimeline.above)
                            Color.clear.frame(height: shelfTimeline.active ? 450 : 0)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { expansionHeight = $0 }
                                .accessibilityHidden(true)
                            if let error = model.catalogError { CatalogFailure(message: error) { Task { await model.refreshCatalog() } } }
                            if model.isRefreshing && model.seasonPicks.isEmpty { ProgressView("正在读取番剧…").padding(48) }
                            if model.accountStatus?.bangumi != nil, !model.continueWatching.isEmpty {
                                DokiSectionHeader("继续观看").opacity(1 - shelfTimeline.above)
                                HorizontalCardRow {
                                    ForEach(model.continueWatching) { item in
                                        FocusableCard(focusID: "continue-\(item.id)", focus: $focusedID, action: { model.resume(item) }) { DokiContinueCard(item: item, width: 440) }
                                    }
                                }.opacity(1 - shelfTimeline.above)
                            }
                            ForEach(shelfRows) { row in
                                shelf(row.subjects, title: row.title, id: row.id, prefix: row.prefix, proxy: proxy)
                            }
                        }.padding(.bottom, 70)
                            .coordinateSpace(name: "discover-content")
                            .animation(shelfMotion, value: shelfTimeline.active)
                    }
                    .scrollPosition($verticalPosition)
                    .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y < 180 } action: { _, visible in heroVisible = visible }
                    .scrollClipDisabled()
                    .opacity(max(0.001, 1 - openFade))
                    .task(id: pendingFocusID) {
                        guard let target = pendingFocusID else { return }
                        do {
                            if !reduceMotion { try await Task.sleep(for: .milliseconds(target == "hero-primary" ? 550 : 120)) }
                            try Task.checkCancellation()
                            if target == "hero-primary" {
                                withAnimation(shelfMotion) { verticalPosition.scrollTo(y: 0) }
                                focusedID = nil
                                if !reduceMotion { try await Task.sleep(for: .milliseconds(120)) }
                                resetFocus(in: discoveryScope)
                            }
                            focusedID = target
                            if target == "hero-primary" { returningToHero = false }
                            pendingFocusID = nil
                        } catch { }
                    }
                    .onMoveCommand { direction in
                        let source = focusedID ?? model.discoverFocusID
                        guard let row = shelfRows.first(where: { row in row.subjects.contains { "\(row.prefix)-\($0.id)" == source } }),
                              let subject = row.subjects.first(where: { "\(row.prefix)-\($0.id)" == source }) else { return }
                        if direction == .up || direction == .down { moveVertically(direction, subject: subject, shelfID: row.id, proxy: proxy) }
                    }
                }
                if let subject = expandedSubjectID.flatMap({ model.subject(id: $0) }) {
                    ShelfPreview(subject: subject, detailOpacity: 1 - openFade)
                        .opacity(shelfTimeline.text)
                        .offset(y: (1 - shelfTimeline.text) * 28)
                        .allowsHitTesting(false)
                        .accessibilityHidden(shelfTimeline.text == 0)
                }
            }
        }
        .focusScope(discoveryScope)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: [preview?.id ?? "", model.hubURLString]) { if let id = preview?.id { await model.loadArtwork(id) } }
        .task(id: rotationKey) {
            guard canRotate else { return }
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(8))
                    try Task.checkCancellation()
                    guard canRotate else { return }
                    await advance(by: 1, manual: false)
                }
            } catch { }
        }
        .task(id: carousel.compactMap(\.backdropURL)) {
            await withTaskGroup(of: Void.self) { group in
                for url in carousel.compactMap(\.backdropURL) {
                    group.addTask { try? await DokiArtworkView.prefetch(url) }
                }
            }
        }
        .onChange(of: heroVisible) { _, visible in model.discoverHeroVisible = visible }
        .onChange(of: model.navigationExpanded) { _, _ in heroGeneration += 1 }
        .onChange(of: model.contentFocusRevision) { _, _ in
            if model.selectedTab == .discover { focusedID = model.discoverFocusID ?? "hero-primary" }
        }
        .onChange(of: carousel.map(\.id)) { _, ids in
            if let id = previewID, !ids.contains(id) { previewID = ids.first }
        }
        .onAppear { model.discoverHeroID = preview?.id; if let stored = model.discoverFocusID { focusedID = stored } }
        .onChange(of: focusedID) { _, id in
            if let id, model.discoverPath.isEmpty, detailReturnFocusID == nil {
                if openingID != nil && id != openingSource { cancelOpening() }
                model.discoverFocusID = id
                model.discoverBrowsingShelf = id.hasPrefix("season-") || id.hasPrefix("today-") || id.hasPrefix("continue-")
                if shelfTimeline.active {
                    if id.hasPrefix("season-"), let index = model.seasonPicks.firstIndex(where: { "season-" + $0.id == id }) {
                        selectPreview(model.seasonPicks[index], shelf: "season-\((index / 8) * 8)")
                    } else if id.hasPrefix("today-"), let subject = model.todayCatalog.first(where: { "today-" + $0.id == id }) {
                        selectPreview(subject, shelf: "today")
                    }
                }
            }
        }
        .onChange(of: model.discoverPath.count) { _, count in
            if count == 0 { cancelOpening() }
        }
        .task(id: model.discoverPath.count) {
            guard model.discoverPath.isEmpty, let source = detailReturnFocusID else { return }
            do {
                // The wall must become focusable again after its return fade.
                if !reduceMotion { try await Task.sleep(for: .milliseconds(650)) }
                try Task.checkCancellation()
                model.discoverFocusID = source; focusedID = source
                detailReturnFocusID = nil
            } catch { }
        }
        .onChange(of: preview?.id) { _, id in model.discoverHeroID = id }
        .onChange(of: shelfTimeline.content) { _, progress in
            model.discoverShelfPreviewProgress = progress
            model.discoverShelfPreviewVisible = progress > 0
        }
        .onChange(of: shelfTimeline.above) { _, progress in
            if !shelfTimeline.active && progress == 0 { clearPreview() }
        }
        .onExitCommand(perform: expandedSubjectID != nil ? {
            if openingID != nil { cancelOpening() }
            else {
                setPreviewActive(false)
                if reduceMotion { clearPreview() }
            }
        } : nil)
        .task(id: openingID) {
            guard let id = openingID, let source = openingSource else { return }
            do {
                try await Task.sleep(for: .milliseconds(400))
                try Task.checkCancellation()
                guard openingID == id, model.discoverPath.isEmpty, let subject = model.subject(id: id) else { return }
                open(subject, source: source)
            } catch { }
        }
    }
    private func clearPreview() {
        expandedSubjectID = nil; expandedShelf = nil
        model.discoverShelfPreviewID = nil; model.discoverShelfPreviewVisible = false
        model.discoverShelfPreviewProgress = 0
        if returningToHero {
            // Replace the recycled lazy focus item after the header is visible again.
            heroFocusGeneration += 1
            returningToHero = false
            model.discoverFocusID = "hero-primary"
            pendingFocusID = "hero-primary"
        }
    }
    private func selectPreview(_ subject: Subject, shelf: String) {
        guard expandedSubjectID != subject.id || expandedShelf != shelf else { return }
        heroGeneration += 1
        returningToHero = false
        expandedSubjectID = subject.id; expandedShelf = shelf
        model.discoverShelfPreviewID = subject.id
    }
    private func setPreviewActive(_ active: Bool) {
        withAnimation(shelfMotion) { shelfTimeline.setActive(active, reduceMotion: reduceMotion) }
    }
    private func beginOpening(_ subject: Subject, source: String) {
        guard openingID == nil else { return }
        if reduceMotion { open(subject, source: source); return }
        openingID = subject.id; openingSource = source
        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.2)) { openFade = 1 }
    }
    private func cancelOpening() {
        openingID = nil; openingSource = nil
        withAnimation(reduceMotion ? nil : .timingCurve(0.4, 0, 0.2, 1, duration: 0.2)) { openFade = 0 }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 19) {
            if let subject = preview {
                if model.usesFixtures { DemoNotice() }
                DokiTitleArtwork(subject: subject, width: 550, height: 115)
                HStack(spacing: 20) {
                    if let rating = subject.rating { Label(String(format: "%.1f / 10", rating), systemImage: "star.fill").foregroundStyle(DokiTheme.accent) }
                    if subject.totalEpisodes > 0 { Text("全 \(subject.totalEpisodes) 话") }
                    Text(subject.airDate ?? (subject.year > 0 ? String(subject.year) : ""))
                }.font(.system(size: 23)).foregroundStyle(.secondary)
                Text(subject.synopsis == "暂无简介" ? subject.originalTitle : subject.synopsis)
                    .font(.system(size: 25)).lineSpacing(6).lineLimit(4).foregroundStyle(.primary.opacity(0.88))
                    .frame(width: 700, alignment: .leading)
                Spacer(minLength: 12)
                Button { play(subject) } label: {
                    Label("立即播放", systemImage: "play.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .padding(.horizontal, 32).frame(height: 64)
                }
                .buttonStyle(DiscoverPlayButtonStyle()).focusEffectDisabled()
                .focused($focusedID, equals: "hero-primary")
                .prefersDefaultFocus(true, in: discoveryScope)
                .accessibilityIdentifier("hero-primary")
                .id(heroFocusGeneration)
                .onMoveCommand { direction in
                    if direction == .right { Task { await advance(by: 1, manual: true) } }
                }
                if carousel.count > 1 {
                    HStack(spacing: 9) {
                        ForEach(carousel) { item in
                            Capsule().fill(item.id == preview?.id ? Color.primary : Color.primary.opacity(0.28))
                                .frame(width: item.id == preview?.id ? 28 : 8, height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("番剧轮播").accessibilityIdentifier("hero-page")
                    .accessibilityValue("第 \((carousel.firstIndex { $0.id == preview?.id } ?? 0) + 1) 部，共 \(carousel.count) 部")
                    .accessibilityAdjustableAction { direction in
                        Task { await advance(by: direction == .increment ? 1 : -1, manual: true) }
                    }
                    .padding(.top, 18)
                }
                if let error = heroImageError { Text(error).font(DokiType.micro).foregroundStyle(.secondary) }
                if let error = model.popularError {
                    Button { Task { await model.refreshPopular() } } label: { Label(error + " · 重试", systemImage: "arrow.clockwise").font(DokiType.micro) }
                        .buttonStyle(DokiContentButtonStyle()).focusEffectDisabled().accessibilityIdentifier("popular-retry")
                }
            } else { Text("Doki").font(.system(size: 58, weight: .bold)) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DokiTheme.pagePadding).padding(.top, 110)
        .frame(maxWidth: .infinity, alignment: .leading).frame(height: 660)
    }
    /// Expands at the selected row; the independent carousel above is never replaced.
    private func shelf(_ subjects: [Subject], title: String?, id: String, prefix: String,
                       proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if let title { Text(title).font(DokiType.sectionTitle).padding(.horizontal, DokiTheme.pagePadding) }
            HorizontalCardRow {
                ForEach(subjects) { subject in
                    FocusableCard(focusID: "\(prefix)-\(subject.id)", focus: $focusedID, action: {
                        if shelfTimeline.active {
                            beginOpening(subject, source: "\(prefix)-\(subject.id)")
                        } else {
                            selectPreview(subject, shelf: id)
                            setPreviewActive(true)
                        }
                    }) { DokiPosterTile(subject: subject, width: 204, titleOpacity: 1 - shelfTimeline.above) }
                    .contextMenu { Button("查看详情") { open(subject, source: "\(prefix)-\(subject.id)") } }
                }
            }
            .disabled(returningToHero)
        }
        .opacity(shelfIsAbovePreview(id) ? 1 - shelfTimeline.above : 1)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("discover-content")).minY } action: { top in
            shelfTops[id] = top
        }
        .id("shelf-\(id)")
        .task(id: "\(shelfTimeline.active)-\(expandedShelf == id ? expandedSubjectID ?? "" : "")") {
            guard expandedShelf == id, let selected = expandedSubjectID else { return }
            do {
                // Keep the focused row below the fixed hero stage; never scroll the carousel back in.
                try await Task.sleep(for: .milliseconds(40))
                try Task.checkCancellation()
                guard expandedShelf == id, expandedSubjectID == selected, model.discoverPath.isEmpty else { return }
                if !returningToHero {
                    withAnimation(shelfMotion) {
                        if shelfTimeline.active, let top = shelfTops[id] {
                            // A point stays stable while this row's expansion is animating; a moving view anchor does not.
                            verticalPosition.scrollTo(y: max(0, top - expansionHeight))
                        } else {
                            proxy.scrollTo("shelf-\(id)", anchor: .center)
                        }
                    }
                }
                await model.loadArtwork(selected)
            } catch { }
        }
    }

    private func moveVertically(_ direction: MoveCommandDirection, subject: Subject, shelfID: String, proxy: ScrollViewProxy) {
        guard openingID == nil, let index = shelfRows.firstIndex(where: { $0.id == shelfID }) else { return }
        let row = shelfRows[index]
        let column = row.subjects.firstIndex(where: { $0.id == subject.id }) ?? 0
        let nextIndex = index + (direction == .up ? -1 : 1)
        if nextIndex < 0 {
            guard !returningToHero else { return }
            returningToHero = true
            focusedID = nil
            model.discoverBrowsingShelf = false
            pendingFocusID = nil
            withAnimation(shelfMotion) {
                shelfTimeline.setActive(false, reduceMotion: reduceMotion)
                verticalPosition.scrollTo(y: 0)
            }
            if reduceMotion { clearPreview() }
            return
        }
        returningToHero = false
        guard shelfRows.indices.contains(nextIndex), !shelfRows[nextIndex].subjects.isEmpty else { return }
        let next = shelfRows[nextIndex]
        let target = next.subjects[min(column, next.subjects.count - 1)]
        if shelfTimeline.active { selectPreview(target, shelf: next.id) }
        withAnimation(shelfMotion) { proxy.scrollTo("shelf-\(next.id)", anchor: shelfTimeline.active ? .top : .center) }
        pendingFocusID = "\(next.prefix)-\(target.id)"
    }

    private func shelfIsAbovePreview(_ id: String) -> Bool {
        guard let expandedShelf else { return false }
        if expandedShelf == "today" { return id != "today" }
        guard id.hasPrefix("season-"), let current = Int(id.dropFirst(7)), let selected = Int(expandedShelf.dropFirst(7)) else { return false }
        return current < selected
    }

    private func play(_ subject: Subject) {
        // Uses the existing guarded player path; real catalog entries cannot play fixtures.
        if subject.isRealCatalog { model.showToast("暂无可用播放源"); return }
        guard preview?.id == subject.id, model.selectedTab == .discover, !model.navigationExpanded else { return }
        model.playPrimary(for: model.subject(id: subject.id) ?? subject)
    }

    private func advance(by step: Int, manual: Bool) async {
        guard !carousel.isEmpty else { return }
        heroGeneration += 1
        let generation = heroGeneration
        let index = carousel.firstIndex { $0.id == preview?.id } ?? 0
        // Skip an unavailable automatic slide instead of repeatedly waiting on
        // the same failed image. Manual selection preserves its retry message.
        let steps = manual ? [step] : Array(1..<carousel.count)
        for distance in steps {
            guard generation == heroGeneration, !Task.isCancelled else { return }
            let next = carousel[(index + distance + carousel.count) % carousel.count]
            if next.backdropURL == nil { await model.loadArtwork(next.id) }
            if let url = model.subject(id: next.id)?.backdropURL {
                do { try await DokiArtworkView.prefetch(url) }
                catch {
                    if generation == heroGeneration, manual { heroImageError = "横幅图片暂时无法读取，请稍后重试。" }
                    continue
                }
            }
            guard generation == heroGeneration, !Task.isCancelled, model.selectedTab == .discover,
                  model.discoverPath.isEmpty, !model.navigationExpanded else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) { previewID = next.id }
            heroImageError = nil
            if manual { manualRevision += 1 }
            return
        }
    }
    private func open(_ subject: Subject, source: String) {
        heroGeneration += 1
        model.transitionSourceID = shelfTimeline.active ? "discover-hero" : source
        detailReturnFocusID = source
        model.discoverFocusID = source
        focusedID = nil
        model.discoverPath.append(.subject(subject.id))
    }
}

struct CatalogHero: View {
    let subject: Subject
    var compact = false
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            DokiHeroBackdrop(subject: subject)
            DokiTitleArtwork(subject: subject).padding(48)
        }.frame(height: compact ? 550 : 600)
    }
}
struct CatalogFailure: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        HStack(spacing: 24) { Image(systemName: "wifi.exclamationmark"); Text(message).font(DokiType.caption); Spacer(); DokiControlButton("重试", systemImage: "arrow.clockwise", action: retry) }
            .padding(20).background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14)).padding(.horizontal, DokiTheme.pagePadding)
    }
}

/// Flat, single-surface Apple-style playback control; no extra tvOS focus plate.
private struct DiscoverPlayButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused
    @Environment(\.dokiReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(focused ? Color.black : Color.white)
            .background(focused ? Color.white : DokiTheme.accent, in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : (focused ? 1.03 : 1))
            .shadow(color: .black.opacity(focused ? 0.16 : 0), radius: 14, y: 6)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: focused)
    }
}

private struct ShelfPreview: View {
    let subject: Subject
    var detailOpacity = 1.0
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            VStack(alignment: .leading, spacing: 18) {
                DokiTitleArtwork(subject: subject, width: 550, height: 115)
                HStack(spacing: 20) {
                    if let rating = subject.rating { Label(String(format: "%.1f / 10", rating), systemImage: "star.fill").foregroundStyle(DokiTheme.accent) }
                    if subject.totalEpisodes > 0 { Text("全 \(subject.totalEpisodes) 话") }
                    if subject.year > 0 { Text(String(subject.year)) }
                }.font(.system(size: 23, weight: .medium)).opacity(detailOpacity)
                Text(subject.synopsis).font(DokiType.body).lineSpacing(6).lineLimit(5)
                    .frame(width: 700, alignment: .leading)
                    .opacity(detailOpacity)
            }
            .padding(.horizontal, DokiTheme.pagePadding).padding(.top, 36)
        }
        .frame(height: 460).clipped()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("shelf-preview")
        .accessibilityValue(subject.id)
    }
}


private struct DiscoverShelf: Identifiable {
    let id: String
    let title: String?
    let prefix: String
    let subjects: [Subject]
}
