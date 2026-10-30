import SwiftUI
import DokiCore
import DokiUI

struct DiscoverView: View {
    @Bindable var model: AppModel
    @FocusState private var focusedID: String?
    @State private var previewID: String?
    @State private var expandedShelf: String?
    @State private var expandedSubjectID: String?
    @State private var heroVisible = true
    @State private var manualRevision = 0
    @State private var heroGeneration = 0
    @State private var heroImageError: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
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
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            hero.id("hero")
                            if let error = model.catalogError { CatalogFailure(message: error) { Task { await model.refreshCatalog() } } }
                            if model.isRefreshing && model.seasonPicks.isEmpty { ProgressView("正在读取番剧…").padding(48) }
                            if model.accountStatus?.bangumi != nil, !model.continueWatching.isEmpty {
                                DokiSectionHeader("继续观看")
                                HorizontalCardRow {
                                    ForEach(model.continueWatching) { item in
                                        FocusableCard(focusID: "continue-\(item.id)", focus: $focusedID, action: { model.resume(item) }) { DokiContinueCard(item: item, width: 440) }
                                    }
                                }
                            }
                            ForEach(Array(stride(from: 0, to: model.seasonPicks.count, by: 8)), id: \.self) { start in
                                shelf(Array(model.seasonPicks.dropFirst(start).prefix(8)),
                                      title: start == 0 ? "本季推荐" : nil, id: "season-\(start)", prefix: "season", proxy: proxy)
                            }
                            if !model.todayCatalog.isEmpty {
                                shelf(model.todayCatalog, title: "今日放送", id: "today", prefix: "today", proxy: proxy)
                            }
                        }.padding(.bottom, 70)
                    }
                    .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y < 180 } action: { _, visible in heroVisible = visible }
                    .scrollClipDisabled()
                }
            }
        }
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
            if let id {
                model.discoverFocusID = id
                model.discoverBrowsingShelf = id.hasPrefix("season-") || id.hasPrefix("today-") || id.hasPrefix("continue-")
            }
        }
        .onChange(of: model.discoverPath.count) { _, count in if count == 0 { focusedID = model.discoverFocusID } }
        .onChange(of: preview?.id) { _, id in model.discoverHeroID = id }
        .onExitCommand(perform: expandedSubjectID != nil ? {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                expandedSubjectID = nil; expandedShelf = nil
                model.discoverShelfPreviewID = nil; model.discoverShelfPreviewVisible = false
            }
        } : nil)
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
                .accessibilityIdentifier("hero-primary")
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
            if expandedShelf == id, let selected = expandedSubjectID.flatMap({ model.subject(id: $0) }) {
                ShelfPreview(subject: selected)
                    .id("preview-\(id)")
                    .onScrollVisibilityChange(threshold: 0.1) { visible in
                        if expandedShelf == id { model.discoverShelfPreviewVisible = visible }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)))
            }
            if let title { Text(title).font(DokiType.sectionTitle).padding(.horizontal, DokiTheme.pagePadding) }
            HorizontalCardRow {
                ForEach(subjects) { subject in
                    FocusableCard(focusID: "\(prefix)-\(subject.id)", focus: $focusedID, action: {
                        if expandedShelf == id && expandedSubjectID == subject.id {
                            open(subject, source: "\(prefix)-\(subject.id)")
                        } else {
                            heroGeneration += 1
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) {
                                expandedSubjectID = subject.id; expandedShelf = id
                                model.discoverShelfPreviewID = subject.id
                            }

                        }
                    }) { DokiPosterTile(subject: subject, width: 204) }
                    .dokiTransitionSource("\(prefix)-\(subject.id)")
                    .contextMenu { Button("查看详情") { open(subject, source: "\(prefix)-\(subject.id)") } }
                }
            }
        }
        .id("shelf-\(id)")
        .task(id: expandedShelf == id ? expandedSubjectID : nil) {
            guard expandedShelf == id, let selected = expandedSubjectID else { return }
            do {
                // Let the focus engine finish keeping the poster visible before positioning its preview.
                try await Task.sleep(for: .milliseconds(150))
                try Task.checkCancellation()
                guard expandedShelf == id, expandedSubjectID == selected, model.discoverPath.isEmpty else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) {
                    proxy.scrollTo("shelf-\(id)", anchor: .top)
                }
                await model.loadArtwork(selected)
            } catch { }
        }
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
        model.transitionSourceID = source
        model.discoverFocusID = focusedID
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
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            VStack(alignment: .leading, spacing: 18) {
                Text(subject.title).font(.system(size: 48, weight: .semibold)).lineLimit(2)
                HStack(spacing: 20) {
                    if let rating = subject.rating { Label(String(format: "%.1f / 10", rating), systemImage: "star.fill") }
                    if subject.totalEpisodes > 0 { Text("全 \(subject.totalEpisodes) 话") }
                    if subject.year > 0 { Text(String(subject.year)) }
                }.font(.system(size: 23, weight: .medium))
                Text(subject.synopsis).font(DokiType.body).lineSpacing(6).lineLimit(5)
                    .frame(width: 700, alignment: .leading)
            }
            .padding(.horizontal, DokiTheme.pagePadding).padding(.top, 32)
        }
        .frame(height: 440).clipped()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("shelf-preview")
        .accessibilityValue(subject.id)
    }
}
