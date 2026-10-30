import SwiftUI
import DokiCore
import DokiUI

struct SubjectDetailView: View {
    @Bindable var model: AppModel
    let subjectID: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dokiReduceMotion) private var reduceMotion
    @FocusState private var focusedEpisodeID: String?
    @State private var showEpisodeActions = false
    @State private var showSourcePicker = false
    @State private var showDanmakuMapping = false
    @State private var showArtworkPicker = false
    @State private var expandedCredits: Set<String> = []
    @State private var showFullSynopsis = false
    private var subject: Subject? { model.subject(id: subjectID) }
    private var episodes: [Episode] { subject.map { model.episodes(for: $0) } ?? [] }
    private var targetEpisode: Episode? { episodes.first { $0.id == focusedEpisodeID } ?? episodes.first }
    var body: some View {
        ScrollView {
            if let subject {
                VStack(alignment: .leading, spacing: 28) {
                    detailHero(subject)
                    if let error = model.detailErrors[subjectID] { CatalogFailure(message: error) { Task { await model.loadDetail(subjectID) } } }
                    if subject.isRealCatalog {
                        HStack(spacing: 12) {
                            Image(systemName: "play.rectangle")
                            Text("番剧资料已连接 · 播放源尚未配置").font(DokiType.caption)
                            Spacer()
                            DokiControlButton("查看播放源", systemImage: "antenna.radiowaves.left.and.right") { showSourcePicker = true }
                        }.foregroundStyle(.secondary).padding(.horizontal, DokiTheme.pagePadding)
                    }
                    episodeSection(subject).padding(.horizontal, DokiTheme.pagePadding)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("关于这部番剧").font(DokiType.sectionTitle)
                        Text(subject.synopsis).font(DokiType.body).foregroundStyle(.secondary).lineSpacing(7)
                            .lineLimit(showFullSynopsis ? nil : 5).frame(maxWidth: 1200, alignment: .leading)
                        if subject.synopsis.count > 150 {
                            DokiControlButton(showFullSynopsis ? "收起简介" : "展开简介", systemImage: "text.alignleft") {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showFullSynopsis.toggle() }
                            }
                        }
                    }.padding(.horizontal, DokiTheme.pagePadding)
                    creditsSection("角色与声优", items: model.characterCredits[subjectID] ?? [])
                    creditsSection("制作人员", items: model.staffCredits[subjectID] ?? [])
                    if let error = model.creditErrors[subjectID] { CatalogFailure(message: error) { Task { await model.loadCredits(subjectID) } } }
                    artworkStatus(subject).padding(.horizontal, DokiTheme.pagePadding)
                }.padding(.bottom, 64)
            } else {
                DokiEmptyState(title: "暂时无法打开条目", message: "返回后重新选择或刷新。", symbol: "questionmark.folder").padding(DokiTheme.pagePadding)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topTrailing) {
            DokiControlIconButton("chevron.backward", accessibilityLabel: "返回") { dismiss() }
                .padding(.trailing, DokiTheme.pagePadding).padding(.top, 12)
        }
        .confirmationDialog(targetEpisode.map { "第 \($0.sort.formatted()) 话 · \($0.title)" } ?? "章节", isPresented: $showEpisodeActions, titleVisibility: .visible) {
            if let episode = targetEpisode {
                if subject?.isRealCatalog == true { Button("选择播放源") { showSourcePicker = true } }
                else if let subject { Button("播放此集") { model.presentPlayer(for: subject, episode: episode) } }
                Button(model.isWatched(episode) ? "标记未看" : "标记已看") { model.markWatched(episode, watched: !model.isWatched(episode)) }
                Button("取消", role: .cancel) {}
            }
        }
        .task(id: [subjectID, model.hubURLString]) { await model.loadDetail(subjectID) }
        .sheet(isPresented: $showSourcePicker) { SourcePickerSheet(model: model) }
        .sheet(isPresented: $showDanmakuMapping) {
            if let episode = targetEpisode { DanmakuMappingSheet(model: model, episode: episode) }
        }
        .sheet(isPresented: $showArtworkPicker) { artworkPicker }
    }
    private func detailHero(_ subject: Subject) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            DokiTitleArtwork(subject: subject, width: 600, height: 180)
                .padding(.top, 35)
            Spacer(minLength: 20)
            HStack(alignment: .bottom, spacing: 45) {
                VStack(alignment: .leading, spacing: 20) {
                    DokiControlGroup {
                        HStack(spacing: 22) {
                            DokiControlIconButton(subject.followState == .watching ? "star.fill" : "star", accessibilityLabel: subject.followState == .watching ? "已加入追番" : "加入追番") { model.toggleFollow(subject) }
                            DokiControlIconButton("square.grid.2x2", accessibilityLabel: "章节列表") { focusedEpisodeID = episodes.first?.id }
                            DokiControlIconButton("antenna.radiowaves.left.and.right", accessibilityLabel: "播放源") { showSourcePicker = true }
                        }
                    }
                    Button {
                        if let episode = episodes.first { focusedEpisodeID = episode.id; showEpisodeActions = true }
                    } label: { Label("选择章节", systemImage: "play.fill").font(.system(size: 25, weight: .medium)).frame(minWidth: 230).padding(.vertical, 10) }
                        .buttonStyle(DokiButtonStyle(prominent: true)).tint(DokiTheme.accent).disabled(episodes.isEmpty)
                }.frame(width: 300, alignment: .leading)
                VStack(alignment: .leading, spacing: 20) {
                    Text([subject.airDate, subject.season, subject.totalEpisodes > 0 ? "全 \(subject.totalEpisodes) 话" : nil].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 25)).foregroundStyle(.primary)
                    if let stats = subject.statistics {
                        HStack(spacing: 34) {
                            count(stats.collected, label: "收藏")
                            count(stats.watching, label: "在看")
                            count(stats.wish, label: "想看")
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), alignment: .leading, spacing: 10) {
                        ForEach(Array(subject.genres.prefix(6)), id: \.self) { tag in
                            Text(tag).font(DokiType.caption).lineLimit(1).padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
                        }
                    }
                }.frame(maxWidth: 650, alignment: .leading)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 10) {
                    if let stats = subject.statistics, !stats.distribution.isEmpty {
                        HStack(alignment: .bottom, spacing: 7) {
                            ForEach(1...10, id: \.self) { score in
                                let largest = max(1, stats.distribution.values.max() ?? 1)
                                let value = stats.distribution[String(score)] ?? 0
                                VStack(spacing: 5) {
                                    RoundedRectangle(cornerRadius: 3).fill(DokiTheme.accent).frame(width: 16, height: max(2, 65 * CGFloat(value) / CGFloat(largest)))
                                    Text(String(score)).font(.system(size: 14)).foregroundStyle(.secondary)
                                }
                            }
                        }.frame(height: 90, alignment: .bottom)
                    }
                    if let rating = subject.rating { Text(String(format: "%.1f", rating)).font(.system(size: 65, weight: .semibold)) }
                    if let stats = subject.statistics {
                        Text([stats.rank.flatMap { $0 > 0 ? "#\($0)" : nil }, stats.ratingCount.map { "\($0.formatted()) 人评分" }].compactMap { $0 }.joined(separator: " · ")).font(DokiType.caption).foregroundStyle(.secondary)
                    }
                }.frame(width: 260, alignment: .leading)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, DokiTheme.pagePadding)
        .frame(height: 650)
    }
    @ViewBuilder
    private func count(_ value: Int?, label: String) -> some View {
        if let value {
            VStack(alignment: .leading, spacing: 6) {
                Text(value.formatted()).font(.system(size: 27))
                Text(label).font(DokiType.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func episodeSection(_ subject: Subject) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("章节").font(DokiType.sectionTitle)
                Text("\(episodes.count) 话").font(DokiType.caption).foregroundStyle(.secondary)
                Spacer()
                if let targetEpisode { Text(targetEpisode.airDate.map { DokiDate.shortDate($0) } ?? "日期未公布").font(DokiType.caption).foregroundStyle(.secondary) }
            }
            if episodes.isEmpty {
                Text(model.detailErrors[subjectID] != nil ? "章节暂不可用" : "章节资料加载中，或尚未公布")
                    .font(DokiType.caption).foregroundStyle(.secondary).padding(.vertical, 24)
            } else {
                if let episode = targetEpisode {
                    HStack {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("第 \(episode.sort.formatted()) 话 · \(episode.title)").font(DokiType.cardTitle).lineLimit(2)
                            if !episode.synopsis.isEmpty { Text(episode.synopsis).font(DokiType.caption).foregroundStyle(.secondary).lineLimit(2) }
                        }
                        Spacer()
                        DokiControlButton(model.isWatched(episode) ? "标为未看" : "标为已看", systemImage: "checkmark.circle") { model.markWatched(episode, watched: !model.isWatched(episode)) }
                    }.frame(minHeight: 72)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210, maximum: 250), spacing: 20)], alignment: .leading, spacing: 20) {
                    ForEach(episodes) { episode in
                        FocusableCard(focusID: episode.id, focus: $focusedEpisodeID, action: {
                            focusedEpisodeID = episode.id
                            showEpisodeActions = true
                        }) {
                            DokiEpisodeChip(episode: episode, watched: model.isWatched(episode), fraction: model.fraction(for: episode))
                        }
                        .contextMenu {
                            Button(model.isWatched(episode) ? "标记未看" : "标记已看") { model.markWatched(episode, watched: !model.isWatched(episode)) }
                        }
                    }
                }
            }
        }
    }
    @ViewBuilder
    private func creditsSection(_ title: String, items: [CatalogCredit]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(title).font(DokiType.sectionTitle)
                    Spacer()
                    if items.count > 12 {
                        DokiControlButton(expandedCredits.contains(title) ? "收起" : "全部 \(items.count) 位", systemImage: "person.2") {
                            if expandedCredits.contains(title) { expandedCredits.remove(title) } else { expandedCredits.insert(title) }
                        }
                    }
                }.padding(.horizontal, DokiTheme.pagePadding)
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 28) {
                        ForEach(expandedCredits.contains(title) ? items : Array(items.prefix(12))) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                DokiArtworkView(assetName: nil, title: item.name, accentHex: "8BB8C8", remoteURL: item.imageURL)
                                    .frame(width: 150, height: 190).clipShape(RoundedRectangle(cornerRadius: 12))
                                Text(item.name).font(DokiType.caption).lineLimit(2)
                                Text(item.subtitle).font(DokiType.micro).foregroundStyle(.secondary).lineLimit(2)
                            }.frame(width: 180, alignment: .leading).focusable()
                        }
                    }.padding(.horizontal, DokiTheme.pagePadding).padding(.vertical, 15)
                }.frame(height: 300).scrollClipDisabled()
            }
        }
    }
    private func artworkStatus(_ subject: Subject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("横幅图片").font(DokiType.cardTitle)
                Spacer()
                if model.artworkResults[subjectID]?.candidates.isEmpty == false {
                    DokiControlButton("修正关联", systemImage: "photo") { showArtworkPicker = true }
                }
            }
            Text(artworkDescription).font(DokiType.caption).foregroundStyle(.secondary)
        }.padding(.top, 10)
    }
    private var artworkDescription: String {
        if subject?.backdropURL != nil { return "横幅由 TMDB 提供；封面和章节以 Bangumi 为准。" }
        if model.artworkMapIDs.contains(subjectID) { return "公开对应表暂未提供横幅，保留原始封面。" }
        switch model.artworkResults[subjectID]?.state {
        case "ready": return "找到 TMDB 候选，请选择对应番剧；未确认时保留竖版封面。"
        case "noMatch": return "暂未找到对应 TMDB 横幅，保留原始竖版封面。"
        case "unavailable": return "TMDB 暂时不可用，番剧资料仍可浏览。"
        default: return "公开图片对应表尚未命中，当前保留原始竖版封面。"
        }
    }
    private var artworkPicker: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Text("选择 TMDB 关联").font(DokiType.sectionTitle); Spacer(); DokiControlButton("完成") { showArtworkPicker = false } }
                    ForEach(model.artworkResults[subjectID]?.candidates ?? [], id: \.identity) { candidate in
                        Button {
                            model.chooseArtwork(candidate, subjectID: subjectID); showArtworkPicker = false
                        } label: {
                            HStack(spacing: 24) {
                                if let path = candidate.backdropURL, let hub = model.configuredHubURL,
                                   let url = URL(string: hub.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path) {
                                    DokiArtworkView(assetName: nil, title: candidate.title, accentHex: "8BB8C8", remoteURL: url).frame(width: 320, height: 180).clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(candidate.title).font(DokiType.cardTitle)
                                    Text("\(candidate.originalTitle) · \(candidate.year) · \(candidate.mediaType.uppercased())").font(DokiType.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }.padding(16)
                        }.buttonStyle(.card).disabled(candidate.backdropURL == nil)
                    }
                }.padding(DokiTheme.pagePadding)
            }.background(DokiBackground())
        }
    }
}

struct SourcePickerSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("选择播放源")
                                .font(DokiType.pageTitle)
                            Text("当前没有产品可用源。以下线路仅供演示，不会播放你选择的真实番剧。")
                                .font(DokiType.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        DokiControlButton("完成", systemImage: "checkmark") {
                            dismiss()
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(model.sources) { source in
                            Button {
                                model.selectSource(source)
                                dismiss()
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: source.status == .disabled ? "xmark.circle" : "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 22))
                                        .foregroundStyle(source.status == .disabled ? Color.secondary : DokiTheme.accent)
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(source.name)
                                                .font(DokiType.cardTitle)
                                            DokiBadge(source.status.title, tone: source.status == .disabled ? .warning : .scheduled)
                                            if model.selectedSourceID == source.id {
                                                DokiBadge("当前", tone: .accent)
                                            }
                                        }
                                        Text("\(source.detail) · \(source.requiresRelay ? "Hub relay" : "direct")")
                                            .font(DokiType.caption)
                                            .foregroundStyle(.secondary)
                                        Text(source.compatibilityNote)
                                            .font(DokiType.micro)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    if model.selectedSourceID == source.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(DokiTheme.accent)
                                    }
                                }
                                .padding(18)
                                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(
                                            model.selectedSourceID == source.id
                                                ? DokiTheme.accent.opacity(0.6)
                                                : Color.primary.opacity(0.08),
                                            lineWidth: model.selectedSourceID == source.id ? 2 : 1
                                        )
                                }
                            }
                            .buttonStyle(DokiContentButtonStyle()).focusEffectDisabled()
                            .disabled(source.status == .disabled)
                            .opacity(source.status == .disabled ? 0.55 : 1)
                        }
                    }

                    DokiSurface {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("切换源的边界")
                                .font(DokiType.cardTitle)
                            Text("真实切源只有在时间轴已验证时才自动继承秒数；不同剪辑要求确认。本演示只保存选择，不改变样片内容。")
                                .font(DokiType.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(DokiTheme.pagePadding)
            }
            .background(DokiBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
