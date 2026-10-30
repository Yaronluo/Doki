import SwiftUI
import DokiCore
import DokiUI

struct SearchView: View {
    @Bindable var model: AppModel
    @FocusState private var focusedID: String?
    private var hasQuery: Bool { !model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var subjects: [Subject] { hasQuery ? model.searchResults : model.suggestedSubjects }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                PageHeader(title: hasQuery ? "搜索结果" : "搜索")
                if model.isSearching { ProgressView("搜索中…").padding(.horizontal, DokiTheme.pagePadding) }
                if let error = model.searchError { CatalogFailure(message: error) { Task { await model.searchCatalog() } } }
                if hasQuery, model.completedSearchQuery != model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines), !subjects.isEmpty {
                    Text("正在显示上一次搜索结果").font(DokiType.caption).foregroundStyle(.secondary).padding(.horizontal, DokiTheme.pagePadding)
                }
                if hasQuery, subjects.isEmpty, !model.isSearching, model.searchError == nil {
                    DokiEmptyState(title: "没有找到匹配番剧", message: "试试原名或更短的关键词。", symbol: "magnifyingglass").padding(.horizontal, DokiTheme.pagePadding)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210, maximum: 230), spacing: 30)], alignment: .leading, spacing: 32) {
                    ForEach(subjects) { subject in
                        FocusableCard(focusID: "search-\(subject.id)", focus: $focusedID, action: {
                            model.searchFocusID = "search-\(subject.id)"; model.transitionSourceID = "search-\(subject.id)"
                            model.searchPath.append(.subject(subject.id))
                        }) { DokiPosterTile(subject: subject, width: 210) }
                        .dokiTransitionSource("search-\(subject.id)")
                    }
                }.padding(.horizontal, DokiTheme.pagePadding).padding(.vertical, 18)
                if hasQuery, model.searchOffset < model.searchTotal, !model.isSearching {
                    DokiControlButton("载入更多", systemImage: "plus") { Task { await model.searchCatalog(loadMore: true) } }.padding(.horizontal, DokiTheme.pagePadding)
                }
            }.padding(.bottom, 64)
        }
        .background(DokiBackground())
        .navigationTitle("搜索")
        .searchable(text: $model.searchQuery, prompt: "搜索番剧")
        .task(id: [model.hubURLString, model.searchQuery]) { await model.searchCatalog() }
        .onChange(of: model.contentFocusRevision) { _, _ in
            if model.selectedTab == .search { focusedID = model.searchFocusID ?? subjects.first.map { "search-\($0.id)" } }
        }
        .onChange(of: model.searchPath.count) { _, count in if count == 0 { focusedID = model.searchFocusID } }
    }
}
