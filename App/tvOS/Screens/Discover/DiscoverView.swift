import SwiftUI
import DokiCore
import DokiUI

struct DiscoverView: View {
    @Bindable var model: AppModel
    @FocusState private var focusedID: String?
    @State private var previewID: String?
    @State private var previewing = false
    @State private var heroVisible = true
    @State private var manualRevision = 0
    @State private var heroGeneration = 0
    @State private var heroImageError: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    private var carousel: [Subject] { Array(model.popularSubjects.prefix(6)) }
    private var canRotate: Bool {
        carousel.count > 1 && heroVisible && !previewing && !model.navigationExpanded
        && model.selectedTab == .discover && model.discoverPath.isEmpty && model.playerRoute == nil
        && scenePhase == .active && !reduceMotion && !voiceOver
        && focusedID != "hero-previous" && focusedID != "hero-next"
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
                            if !model.continueWatching.isEmpty {
                                DokiSectionHeader("继续观看")
                                HorizontalCardRow {
                                    ForEach(model.continueWatching) { item in
                                        FocusableCard(focusID: "continue-\(item.id)", focus: $focusedID, action: { model.resume(item) }) { DokiContinueCard(item: item, width: 440) }
                                    }
                                }
                            }
                            HStack {
                                Text("本季推荐").font(.system(size: 28, weight: .medium))
                                Spacer()
                                Text("\(model.seasonPicks.count) 部").font(DokiType.caption).foregroundStyle(.secondary)
                            }.padding(.horizontal, DokiTheme.pagePadding)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 30, alignment: .top), count: 6), alignment: .leading, spacing: 34) {
                                ForEach(model.seasonPicks) { subject in
                                    FocusableCard(focusID: "season-\(subject.id)", focus: $focusedID, action: {
                                        if previewing && previewID == subject.id { open(subject, source: "season-\(subject.id)") }
                                        else {
                                            heroGeneration += 1; previewID = subject.id; previewing = true
                                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) { proxy.scrollTo("hero", anchor: .top) }
                                        }
                                    }) { DokiPosterTile(subject: subject) }
                                        .dokiTransitionSource("season-\(subject.id)")
                                        .contextMenu { Button("查看详情") { open(subject, source: "season-\(subject.id)") } }
                                }
                            }.padding(.horizontal, DokiTheme.pagePadding).padding(.top, 10)
                            if !model.todayCatalog.isEmpty {
                                Text("今日放送").font(DokiType.sectionTitle).padding(.horizontal, DokiTheme.pagePadding)
                                HorizontalCardRow {
                                    ForEach(model.todayCatalog) { subject in
                                        FocusableCard(focusID: "today-\(subject.id)", focus: $focusedID, action: { open(subject, source: "today-\(subject.id)") }) { DokiPosterTile(subject: subject, width: 230) }
                                            .dokiTransitionSource("today-\(subject.id)")
                                    }
                                }
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
            if !previewing, let id = previewID, !ids.contains(id) { previewID = ids.first }
        }
        .onAppear { model.discoverHeroID = preview?.id; if let stored = model.discoverFocusID { focusedID = stored } }
        .onChange(of: focusedID) { _, id in if let id { model.discoverFocusID = id } }
        .onChange(of: model.discoverPath.count) { _, count in if count == 0 { focusedID = model.discoverFocusID } }
        .onChange(of: preview?.id) { _, id in model.discoverHeroID = id }
        .onExitCommand(perform: previewing ? { previewing = false; previewID = carousel.first?.id } : nil)
    }
    private var hero: some View {
        VStack(alignment: .leading, spacing: 19) {
            if let subject = preview {
                HStack(spacing: 10) {
                    Text(model.usesFixtures ? "自造演示轮播" : (previewing || carousel.isEmpty ? "本季推荐" : "Bangumi 热门"))
                    if !previewing, !carousel.isEmpty { Text("· 收藏热度") }
                }.font(.system(size: 19, weight: .medium)).foregroundStyle(.secondary)
                DokiTitleArtwork(subject: subject, width: 550, height: 130)
                HStack(spacing: 20) {
                    if let rating = subject.rating { Label(String(format: "%.1f / 10", rating), systemImage: "star.fill").foregroundStyle(DokiTheme.accent) }
                    if subject.totalEpisodes > 0 { Text("全 \(subject.totalEpisodes) 话") }
                    Text(subject.airDate ?? (subject.year > 0 ? String(subject.year) : ""))
                }.font(.system(size: 23)).foregroundStyle(.secondary)
                Text(subject.synopsis == "暂无简介" ? subject.originalTitle : subject.synopsis)
                    .font(.system(size: 25)).lineSpacing(6).lineLimit(3).foregroundStyle(.primary.opacity(0.88))
                    .frame(width: 665, alignment: .leading)
                HStack(spacing: 18) {
                    Button { open(subject, source: "hero-\(subject.id)") } label: { Label("查看详情", systemImage: "play.fill").font(.system(size: 23, weight: .medium)).padding(.horizontal, 20).padding(.vertical, 8) }
                        .buttonStyle(DokiButtonStyle(prominent: true)).tint(DokiTheme.accent)
                        .focused($focusedID, equals: "hero-primary")
                        .accessibilityIdentifier("hero-primary")
                        .dokiTransitionSource("hero-\(subject.id)")
                    DokiControlButton("放送日历", systemImage: "calendar") { model.selectedTab = .calendar }
                }.padding(.top, 4)
                if !previewing, carousel.count > 1 {
                    HStack(spacing: 20) {
                        Button { Task { await advance(by: -1, manual: true) } } label: { Image(systemName: "chevron.left").frame(width: 34, height: 34) }
                            .buttonStyle(DokiButtonStyle()).buttonBorderShape(.circle)
                            .focused($focusedID, equals: "hero-previous")
                            .accessibilityLabel("上一部热门番剧").accessibilityIdentifier("hero-previous")
                        HStack(spacing: 9) {
                            ForEach(carousel) { item in
                                Capsule().fill(item.id == preview?.id ? Color.primary : Color.primary.opacity(0.28))
                                    .frame(width: item.id == preview?.id ? 26 : 7, height: 7)
                            }
                        }.accessibilityElement(children: .ignore)
                            .accessibilityLabel("热门番剧轮播").accessibilityIdentifier("hero-page")
                            .accessibilityValue("第 \((carousel.firstIndex { $0.id == preview?.id } ?? 0) + 1) 部，共 \(carousel.count) 部")
                        Button { Task { await advance(by: 1, manual: true) } } label: { Image(systemName: "chevron.right").frame(width: 34, height: 34) }
                            .buttonStyle(DokiButtonStyle()).buttonBorderShape(.circle)
                            .focused($focusedID, equals: "hero-next")
                            .accessibilityLabel("下一部热门番剧").accessibilityIdentifier("hero-next")
                    }.padding(.top, 4)
                }
                if let error = heroImageError { Text(error).font(DokiType.micro).foregroundStyle(.secondary) }
                if let error = model.popularError {
                    Button { Task { await model.refreshPopular() } } label: { Label(error + " · 重试", systemImage: "arrow.clockwise").font(DokiType.micro) }
                        .buttonStyle(DokiContentButtonStyle()).focusEffectDisabled().accessibilityIdentifier("popular-retry")
                }
            } else { Text("Doki").font(.system(size: 58, weight: .bold)) }
            Spacer(minLength: 0)
        }
        .padding(.leading, DokiTheme.pagePadding).padding(.top, 120)
        .frame(maxWidth: .infinity, alignment: .leading).frame(height: 660)
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
