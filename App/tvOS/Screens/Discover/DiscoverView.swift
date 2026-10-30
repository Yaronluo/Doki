import SwiftUI
import DokiCore
import DokiUI

struct DiscoverView: View {
    @Bindable var model: AppModel
    @FocusState private var focusedID: String?
    @State private var previewID: String?
    @State private var previewing = false
    @Environment(\.dokiReduceMotion) private var reduceMotion
    private var preview: Subject? {
        previewID.flatMap { model.subject(id: $0) }
        ?? model.seasonPicks.first(where: { $0.backdropURL != nil }) ?? model.seasonPicks.first
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
                                            previewID = subject.id; previewing = true
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
                    }.scrollClipDisabled()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: [preview?.id ?? "", model.hubURLString]) { if let id = preview?.id { await model.loadArtwork(id) } }
        .onAppear { if let stored = model.discoverFocusID { focusedID = stored } }
        .onChange(of: focusedID) { _, id in if let id { model.discoverFocusID = id } }
        .onChange(of: model.discoverPath.count) { _, count in if count == 0 { focusedID = model.discoverFocusID } }
        .onChange(of: preview?.id) { _, id in model.discoverHeroID = id }
        .onExitCommand(perform: previewing ? { previewing = false } : nil)
    }
    private var hero: some View {
        VStack(alignment: .leading, spacing: 19) {
            if let subject = preview {
                DokiTitleArtwork(subject: subject)
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
                        .buttonStyle(.borderedProminent).tint(DokiTheme.accent)
                        .focused($focusedID, equals: "hero-primary")
                        .dokiTransitionSource("hero-\(subject.id)")
                    DokiGlassButton("放送日历", systemImage: "calendar") { model.selectedTab = .calendar }
                }.padding(.top, 4)
            } else { Text("Doki").font(.system(size: 58, weight: .bold)) }
            Spacer(minLength: 0)
        }
        .padding(.leading, DokiTheme.pagePadding).padding(.top, 68)
        .frame(maxWidth: .infinity, alignment: .leading).frame(height: 520)
    }
    private func open(_ subject: Subject, source: String) {
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
        HStack(spacing: 24) { Image(systemName: "wifi.exclamationmark"); Text(message).font(DokiType.caption); Spacer(); DokiGlassButton("重试", systemImage: "arrow.clockwise", action: retry) }
            .padding(20).background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14)).padding(.horizontal, DokiTheme.pagePadding)
    }
}
