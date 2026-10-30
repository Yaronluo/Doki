import SwiftUI
import DokiCore
import DokiDanmaku
import DokiUI

enum DanmakuSettingsPresentation: Equatable {
    case settingsTab
    case playerSheet
}

struct DanmakuSettingsView: View {
    @Bindable var model: AppModel
    let presentation: DanmakuSettingsPresentation
    var episode: Episode?
    var onRequestMapping: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch presentation {
            case .settingsTab:
                ScrollView(.vertical, showsIndicators: false) {
                    content
                        .padding(.bottom, 64)
                }
                .background(DokiBackground())
            case .playerSheet:
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("弹幕设置")
                                    .font(DokiType.pageTitle)
                                Text(episode.map { "第 \($0.number) 话 · \($0.title)" } ?? "播放器旁路设置")
                                    .font(DokiType.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            DokiControlButton("完成", systemImage: "checkmark") {
                                dismiss()
                            }
                        }
                        .padding(.horizontal, DokiTheme.pagePadding)
                        .padding(.top, 28)

                        content
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var content: some View {
        if presentation == .settingsTab {
            PageHeader(
                title: "弹幕",
                subtitle: "媒体时钟驱动、读取与设置已准备；真实弹弹play凭据未配置。",
                badge: "fixture",
                onBack: { dismiss() }
            )
            .padding(.bottom, 26)
        }

        VStack(alignment: .leading, spacing: 26) {
            SettingsSection("显示") {
                toggleRow(
                    "启用弹幕",
                    detail: "首次使用默认关闭。开启后电视会记住这台设备的偏好。",
                    isOn: $model.danmakuPreferences.enabled
                )

                fontScaleControl

                opacityControl

                HStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("密度")
                            .font(DokiType.cardTitle)
                        Picker("密度", selection: $model.danmakuPreferences.density) {
                            ForEach(DanmakuPreferences.Density.allCases, id: \.self) { density in
                                Text(density.title).tag(density)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("显示区域")
                            .font(DokiType.cardTitle)
                        Picker("显示区域", selection: $model.danmakuPreferences.area) {
                            ForEach(DanmakuPreferences.Area.allCases, id: \.self) { area in
                                Text(area.title).tag(area)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 430)
                    }
                    Spacer()
                }
                .padding(20)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 10) {
                    ChoiceChip(
                        label: "滚动",
                        selected: model.danmakuPreferences.showsScroll
                    ) {
                        model.danmakuPreferences.showsScroll.toggle()
                    }
                    ChoiceChip(
                        label: "顶部",
                        selected: model.danmakuPreferences.showsTop
                    ) {
                        model.danmakuPreferences.showsTop.toggle()
                    }
                    ChoiceChip(
                        label: "底部",
                        selected: model.danmakuPreferences.showsBottom
                    ) {
                        model.danmakuPreferences.showsBottom.toggle()
                    }
                    Spacer()
                }
                .padding(20)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            SettingsSection("时间轴") {
                offsetControl

                Text("暂停时冻结，seek 后重新定位；不会按暂停经过的墙钟补跑。倍速依赖 AVPlayer 媒体时间。")
                    .font(DokiType.micro)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }

            SettingsSection("匹配") {
                if let episode {
                    mappingCard(for: episode)
                } else {
                    DokiSurface {
                        HStack(spacing: 16) {
                            Image(systemName: "link")
                                .font(.system(size: 22))
                                .foregroundStyle(DokiTheme.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("已确认 \(model.danmakuMappings.values.filter(\.confirmed).count) 集")
                                    .font(DokiType.cardTitle)
                                Text("在详情页或播放器里对当前集重新匹配。弹幕库 ID 与 Bangumi 章节 ID 分开保存。")
                                    .font(DokiType.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }

            SettingsSection("服务与证据边界") {
                DokiSurface {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("弹弹play开放弹幕网络")
                                .font(DokiType.cardTitle)
                            DokiBadge("未配置", tone: .scheduled)
                        }
                        Text("没有 Doki 自己的 AppId/AppSecret，因此当前所有内容均为明确标注的自造 fixture。未借用参考项目凭据，未发起真实鉴权请求。")
                            .font(DokiType.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("PiP / AirPlay 保留原生视频与字幕，不承诺携带自绘弹幕；不引入烧录。")
                            .font(DokiType.micro)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.horizontal, DokiTheme.pagePadding)
    }

    private func mappingCard(for episode: Episode) -> some View {
        let mapping = model.mapping(for: episode.id)
        return DokiSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mapping?.title ?? "未匹配")
                            .font(DokiType.sectionTitle)
                        Text(mapping.map { "danmakuEpisodeId \($0.danmakuEpisodeID) · revision \($0.revision)" } ?? "当前集没有确认的弹幕库；不会自动把第一条候选画在视频上。")
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    DokiBadge(
                        mapping?.confirmed == true ? "已确认" : "未绑定",
                        tone: mapping?.confirmed == true ? .available : .scheduled
                    )
                }
                HStack(spacing: 14) {
                    DokiControlButton("重新匹配", systemImage: "arrow.triangle.2.circlepath") {
                        onRequestMapping?()
                    }
                    if mapping != nil {
                        DokiControlButton("取消匹配", systemImage: "xmark") {
                            model.clearDanmakuMapping(for: episode)
                        }
                    }
                    DemoNotice(text: "候选为自造 fixture")
                }
            }
        }
    }

    private var fontScaleControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("字号")
                    .font(DokiType.cardTitle)
                Spacer()
                Text(String(format: "%.2fx", model.danmakuPreferences.fontScale))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DokiTheme.accent)
            }
            HStack(spacing: 8) {
                ForEach([0.8, 0.9, 1.0, 1.15, 1.3, 1.5], id: \.self) { value in
                    ChoiceChip(
                        label: String(format: "%.2fx", value),
                        selected: abs(model.danmakuPreferences.fontScale - value) < 0.001
                    ) {
                        model.danmakuPreferences.fontScale = value
                    }
                }
                Spacer()
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var opacityControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("不透明度")
                    .font(DokiType.cardTitle)
                Spacer()
                Text("\(Int(model.danmakuPreferences.opacity * 100))%")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DokiTheme.accent)
            }
            HStack(spacing: 8) {
                ForEach([0.4, 0.55, 0.7, 0.85, 1.0], id: \.self) { value in
                    ChoiceChip(
                        label: "\(Int(value * 100))%",
                        selected: abs(model.danmakuPreferences.opacity - value) < 0.001
                    ) {
                        model.danmakuPreferences.opacity = value
                    }
                }
                Spacer()
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var offsetControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("时间偏移")
                        .font(DokiType.cardTitle)
                    Text("正值表示弹幕更晚出现；按资源剪辑保存，不自动继承到其他源。")
                        .font(DokiType.micro)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%+.1f s", model.danmakuPreferences.offsetSeconds))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DokiTheme.accent)
            }
            HStack(spacing: 8) {
                ForEach([-5.0, -2.0, -1.0, -0.5, 0.0, 0.5, 1.0, 2.0, 5.0], id: \.self) { value in
                    ChoiceChip(
                        label: String(format: "%+.1f", value),
                        selected: abs(model.danmakuPreferences.offsetSeconds - value) < 0.001
                    ) {
                        model.danmakuPreferences.offsetSeconds = value
                    }
                }
                Spacer()
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func toggleRow(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DokiType.cardTitle)
                Text(detail)
                    .font(DokiType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 20)
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(20)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func modeToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(DokiType.caption)
        }
        .toggleStyle(.switch)
    }
}

struct DanmakuMappingSheet: View {
    @Bindable var model: AppModel
    let episode: Episode
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var candidates: [DanmakuCandidate] {
        let all = model.danmakuCandidates(for: episode)
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.title.localizedStandardContains(trimmed) || $0.detail.localizedStandardContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("匹配弹幕库")
                                .font(DokiType.pageTitle)
                            Text("第 \(episode.number) 话 · \(episode.title)")
                                .font(DokiType.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        DokiControlButton("完成", systemImage: "checkmark") {
                            dismiss()
                        }
                    }

                    currentMapping

                    DokiSurface {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("按作品、版本或集号过滤候选", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(DokiType.body)
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(candidates) { candidate in
                            candidateRow(candidate)
                        }
                        if candidates.isEmpty {
                            DokiEmptyState(
                                title: "候选已被过滤",
                                message: "清空搜索；当前只会显示自造 fixture 候选。",
                                symbol: "line.3.horizontal.decrease.circle"
                            )
                        }
                    }

                    Text("这些候选完全是自造数据。真实 DAN-001 接入后会显示弹弹play返回的作品与章节依据、int64 ID、302 和额度错误，并要求人工确认。")
                        .font(DokiType.micro)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DokiTheme.pagePadding)
                .padding(.bottom, 40)
            }
            .background(DokiBackground())
            .navigationTitle("弹幕匹配")
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var currentMapping: some View {
        DokiSurface {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 26))
                    .foregroundStyle(DokiTheme.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.mapping(for: episode.id)?.title ?? "未匹配")
                        .font(DokiType.cardTitle)
                    if let mapping = model.mapping(for: episode.id) {
                        Text("\(mapping.danmakuEpisodeID) · revision \(mapping.revision) · \(mapping.provenance)")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("弹幕匹配和章节身份分开保存；取消匹配不会改变 Bangumi 已看记录。")
                            .font(DokiType.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if model.isDanmakuMapped(episode) {
                    DokiBadge("已确认", tone: .available)
                }
            }
        }
    }

    private func candidateRow(_ candidate: DanmakuCandidate) -> some View {
        Button {
            model.confirmDanmaku(candidate, for: episode)
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: candidate.isRecommended ? "checkmark.seal" : "text.magnifyingglass")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(candidate.isRecommended ? DokiTheme.accent : .secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 5) {
                    Text(candidate.title)
                        .font(DokiType.cardTitle)
                    Text(candidate.detail)
                        .font(DokiType.caption)
                        .foregroundStyle(.secondary)
                    Text(candidate.danmakuEpisodeID)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if candidate.isRecommended {
                    DokiBadge("推荐", tone: .accent)
                }
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(DokiContentButtonStyle()).focusEffectDisabled()
    }
}


private struct ChoiceChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.isFocused) private var focused
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(
                    selected
                        ? (colorScheme == .light ? Color.white : Color.black)
                        : Color.primary
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    selected ? DokiTheme.accent : Color.primary.opacity(0.075),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(focused ? Color.white.opacity(0.9) : Color.clear, lineWidth: 2)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(DokiContentButtonStyle()).focusEffectDisabled()
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}
