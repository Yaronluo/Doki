import SwiftUI
import DokiCore
import DokiUI

struct LibraryView: View {
    @Bindable var model: AppModel
    @FocusState private var focusedID: String?

    private var subjects: [Subject] {
        model.filteredSubjects()
    }

    private var counts: [LibraryFilter: Int] {
        let todayIDs = Set(model.usesFixtures ? model.library.todayEntries.map(\.subject.id) : model.todayCatalog.map(\.id))
        return [
            .all: model.allFollowedSubjects.count,
            .watching: model.allFollowedSubjects.filter { $0.followState == .watching }.count,
            .today: model.allFollowedSubjects.filter { todayIDs.contains($0.id) }.count,
            .completed: model.allFollowedSubjects.filter { $0.followState == .completed }.count
        ]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 28) {
                PageHeader(
                    title: "我的追番",
                    subtitle: "追看中 \(model.watchingCount) 部 · 已完成 \(model.completedCount) 部 · 今日更新 \(counts[.today] ?? 0) 部",
                    badge: "本地状态"
                )

                FilterBar(selection: $model.libraryFilter, counts: counts)
                    .padding(.horizontal, DokiTheme.pagePadding)

                if subjects.isEmpty {
                    DokiEmptyState(
                        title: "这个筛选下还没有条目",
                        message: "切换筛选或从发现页加入追番。收藏先保存在本机。",
                        symbol: "books.vertical"
                    )
                    .padding(.horizontal, DokiTheme.pagePadding)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 230, maximum: 240), spacing: 24)],
                        alignment: .leading,
                        spacing: 34
                    ) {
                        ForEach(subjects) { subject in
                            libraryCard(subject)
                        }
                    }
                    .padding(.horizontal, DokiTheme.pagePadding)
                }

                HStack(spacing: 10) {
                    DemoNotice(text: "追番记录保存在本机 · Bangumi 账号同步尚未连接")
                    Spacer()
                }
                .padding(.horizontal, DokiTheme.pagePadding)
            }
            .padding(.bottom, 64)
        }
        .background(DokiBackground())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { restoreFocus() }
        .onChange(of: focusedID) { _, newValue in
            if let newValue { model.libraryFocusID = newValue }
        }
        .onChange(of: model.libraryFilter) { _, _ in
            focusFirstCard()
        }
        .onChange(of: model.libraryPath.count) { _, newValue in
            if newValue == 0 { restoreFocus() }
        }
    }

    private func libraryCard(_ subject: Subject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FocusableCard(
                focusID: "library-\(subject.id)",
                focus: $focusedID,
                action: {
                    focusedID = "library-\(subject.id)"
                    model.libraryFocusID = "library-\(subject.id)"
                    model.transitionSourceID = "library-\(subject.id)"
                    model.libraryPath.append(.subject(subject.id))
                }
            ) {
                DokiPosterTile(
                    subject: subject,
                    fraction: model.latestPosition(for: subject.id)?.fraction,
                    watched: subject.followState == .completed,
                    badge: badge(for: subject),
                    width: 230
                )
            }
            .dokiTransitionSource("library-\(subject.id)")
            .contextMenu {
                Button("查看详情") {
                    model.transitionSourceID = "library-\(subject.id)"
                    model.libraryPath.append(.subject(subject.id))
                }
                Button("继续播放") {
                    model.playPrimary(for: subject)
                }
            }

            if let next = model.nextEpisode(for: subject) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(DokiTheme.accent)
                    Text("第 \(next.number) 话 · \(next.title)")
                        .lineLimit(1)
                }
                .font(DokiType.micro)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 230, alignment: .leading)
            } else {
                Text("暂无下一集")
                    .font(DokiType.micro)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: 230, alignment: .leading)
            }
        }
        .frame(width: 230, alignment: .leading)
    }

    private func badge(for subject: Subject) -> DokiBadge? {
        switch subject.followState {
        case .planned:
            DokiBadge("想看", tone: .neutral, symbol: "bookmark")
        case .paused, .dropped:
            DokiBadge("搁置", tone: .warning, symbol: "pause")
        case .completed:
            DokiBadge("已看完", tone: .available, symbol: "checkmark")
        case .watching:
            if subject.updateState == .available {
                DokiBadge("可播", tone: .available)
            } else if subject.updateState == .scheduled {
                DokiBadge("待更新", tone: .scheduled)
            } else {
                nil
            }
        }
    }

    private func focusFirstCard() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            focusedID = subjects.first.map { "library-\($0.id)" }
        }
    }

    private func restoreFocus() {
        if let stored = model.libraryFocusID,
           subjects.contains(where: { "library-\($0.id)" == stored }) {
            focusedID = stored
        } else {
            focusFirstCard()
        }
    }
}
