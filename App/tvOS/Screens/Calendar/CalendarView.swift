import SwiftUI
import DokiCore
import DokiUI

struct CalendarView: View {
    @Bindable var model: AppModel
    @FocusState private var focusedID: String?
    @FocusState private var focusedDay: Date?
    private var days: [Date] { model.library.calendarDays(before: 2, after: 4) }
    private var subjects: [Subject] {
        model.usesFixtures ? model.dayEntries(for: model.selectedCalendarDate).map(\.subject) : model.calendarSubjects(on: model.selectedCalendarDate)
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                PageHeader(title: "放送日历", subtitle: "一周的新故事，按计划相遇。")
                HStack(spacing: 14) {
                    ForEach(days, id: \.self) { day in
                        CalendarDayPill(date: day, isSelected: Calendar.current.isDate(day, inSameDayAs: model.selectedCalendarDate), entryCount: model.usesFixtures ? model.dayEntries(for: day).count : model.calendarSubjects(on: day).count, focus: $focusedDay) { model.selectCalendarDay(day) }
                    }
                }.padding(.horizontal, DokiTheme.pagePadding)
                HStack {
                    Text("\(DokiDate.dayLabel(model.selectedCalendarDate)) · \(subjects.count) 部").font(DokiType.sectionTitle)
                    Spacer()
                    Text("Bangumi 周放送表 · 时间未公布").font(DokiType.caption).foregroundStyle(.secondary)
                }.padding(.horizontal, DokiTheme.pagePadding)
                if let error = model.catalogError { CatalogFailure(message: error) { Task { await model.refreshCatalog() } } }
                if subjects.isEmpty {
                    DokiEmptyState(title: model.isRefreshing ? "正在读取放送表" : "这一天暂无放送安排", message: "选择其他日期查看本周番剧。", symbol: "calendar")
                        .padding(.horizontal, DokiTheme.pagePadding)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210, maximum: 230), spacing: 30)], alignment: .leading, spacing: 30) {
                        ForEach(subjects) { subject in
                            FocusableCard(focusID: "calendar-\(subject.id)", focus: $focusedID, action: {
                                model.calendarFocusID = "calendar-\(subject.id)"; model.transitionSourceID = "calendar-\(subject.id)"
                                model.calendarPath.append(.subject(subject.id))
                            }) { DokiPosterTile(subject: subject, width: 210) }
                            .dokiTransitionSource("calendar-\(subject.id)")
                        }
                    }.padding(.horizontal, DokiTheme.pagePadding).padding(.vertical, 18)
                }
                Text("周放送安排不是逐集开播确认，也不代表播放源已更新；没有可靠时间时不显示虚构时刻。")
                    .font(DokiType.micro).foregroundStyle(.secondary).padding(.horizontal, DokiTheme.pagePadding)
            }.padding(.bottom, 64)
        }
        .background(DokiBackground()).toolbar(.hidden, for: .navigationBar)
        .onChange(of: model.contentFocusRevision) { _, _ in
            if model.selectedTab == .calendar {
                if let stored = model.calendarFocusID { focusedID = stored }
                else { focusedDay = model.selectedCalendarDate }
            }
        }
        .onChange(of: focusedDay) { _, day in if let day { model.selectCalendarDay(day) } }
        .onChange(of: model.calendarPath.count) { _, count in if count == 0 { focusedID = model.calendarFocusID } }
    }
}
